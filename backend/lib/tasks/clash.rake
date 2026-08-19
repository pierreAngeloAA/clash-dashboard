namespace :clash do
  desc "Sincroniza el progreso de una cuenta con la API oficial. Sin tag, las hace todas"
  task :sincronizar, [ :tag ] => :environment do |_t, args|
    resultados = if args[:tag].present?
      cuenta = Account.find_by!(tag_coc: Clash::Cliente.normalizar_tag(args[:tag]))
      [ Clash::SincronizarTodas::Resultado.new(
          account: cuenta, informe: Clash::SincronizarCuenta.new(cuenta).call) ]
    else
      Clash::SincronizarTodas.new.call
    end

    if resultados.empty?
      abort "Ninguna cuenta tiene tag de Clash cargado, asi que no hay nada que sincronizar."
    end

    resultados.each do |resultado|
      cuenta = resultado.account
      puts "#{cuenta.nombre} (#{cuenta.tag_coc})"

      next puts "  no se pudo: #{resultado.error}" unless resultado.ok?

      informe = resultado.informe
      r = informe.resumen

      puts "  actualizados: #{r[:actualizados]}   sin cambios: #{r[:sinCambios]}"
      puts "  protegidos:   #{r[:protegidos]} (con candado)"
      puts "  sin mapear:   #{r[:sinMapear]} (defensas, trampas y lo que no tiene nombre_api)"
      puts "  no encontrados: #{r[:noEncontrados]} (mapeados, pero la API no los devolvio)"

      if informe.rechazados.any?
        puts "  RECHAZADOS: #{informe.rechazados.size} — el catalogo no admite el tope de la API:"
        informe.rechazados.each { |x| puts "    - #{x[:item].nombre}: #{x[:motivo]}" }
      end

      if informe.desconocidos.any?
        puts "  la API trajo #{informe.desconocidos.size} elementos que el catalogo no conoce"
      end
    end
  end

  # El catalogo salio del Google Sheet, con los nombres en español. La API
  # responde en ingles. Sin ese puente, sincronizar no encuentra nada que
  # actualizar aunque todo lo demas funcione.
  #
  # Adivinar los nombres es la peor opcion: uno mal escrito no da error, deja el
  # elemento sin sincronizar para siempre. Esta tarea los saca de la fuente:
  # pide un jugador real y muestra los nombres exactos que devuelve la API,
  # junto a lo que el catalogo todavia no tiene mapeado.
  desc "Muestra los nombres que usa la API y que le falta mapear al catalogo"
  task :nombres, [ :tag ] => :environment do |_t, args|
    tag = args[:tag].presence || Account.sincronizables.first&.tag_coc
    abort "Pasa un tag: bin/rails 'clash:nombres[#2PP0J8CG]'" if tag.blank?

    jugador = Clash::Cliente.new.jugador(tag)

    de_la_api = Clash::SincronizarCuenta::SECCIONES
      .flat_map { |seccion| jugador[seccion] || [] }
      .select { |e| e["village"] == Clash::SincronizarCuenta::ALDEA }
      .map { |e| e["name"] }
      .uniq
      .sort

    mapeados = GameItem.where.not(nombre_api: nil).pluck(:nombre_api).map(&:downcase).to_set

    puts "Jugador #{jugador['name']} (#{jugador['tag']}), TH#{jugador['townHallLevel']}"
    puts
    puts "== #{de_la_api.size} nombres que devuelve la API =="
    de_la_api.each do |nombre|
      puts "  #{mapeados.include?(nombre.downcase) ? '✓' : ' '} #{nombre}"
    end

    sin_mapear = GameItem.de_la_api.where(nombre_api: nil).ordenados
    puts
    puts "== #{sin_mapear.count} elementos del catalogo sin nombre_api =="
    sin_mapear.group_by(&:categoria).each do |categoria, items|
      puts "  #{categoria}"
      items.each { |g| puts "    #{g.nombre}" }
    end

    puts
    puts "Para mapear: completa db/nombres_api.yml y corre bin/rails clash:mapear"
  end

  desc "Aplica al catalogo el mapeo de db/nombres_api.yml"
  task mapear: :environment do
    ruta = Rails.root.join("db/nombres_api.yml")
    abort "No existe #{ruta}" unless ruta.exist?

    mapeo = YAML.load_file(ruta) || {}
    aplicados = 0
    sin_catalogo = []

    mapeo.each do |categoria, nombres|
      (nombres || {}).each do |nombre, nombre_api|
        next if nombre_api.blank?

        item = GameItem.find_by(categoria: categoria, nombre: nombre)
        next sin_catalogo << "#{categoria} / #{nombre}" if item.nil?

        item.update!(nombre_api: nombre_api)
        aplicados += 1
      end
    end

    puts "Mapeados #{aplicados} elementos."
    if sin_catalogo.any?
      puts "No estan en el catalogo (#{sin_catalogo.size}):"
      sin_catalogo.each { |x| puts "  #{x}" }
    end

    faltan = GameItem.de_la_api.where(nombre_api: nil).count
    puts faltan.zero? ? "El catalogo quedo mapeado entero." : "Faltan #{faltan} sin mapear."
  end

  # Los topes que trajo el Sheet son el maximo del juego para todos, sin importar
  # el ayuntamiento: un TH11 figuraba con el canon a 21 igual que un TH18. Asi el
  # progreso se medi­a contra algo inalcanzable y todas las cuentas bajas se veian
  # peor de lo que estan.
  desc "Ajusta el tope de cada elemento al que habilita el ayuntamiento de su cuenta"
  task :ajustar_topes, [ :aplicar ] => :environment do |_t, args|
    aplicar = args[:aplicar] == "aplicar"
    puts aplicar ? "Aplicando cambios." : "Simulacion: no se modifica nada. Corre con [aplicar] para aplicar."
    puts

    Account.ordenadas.each do |cuenta|
      next puts "#{cuenta.nombre}: sin ayuntamiento cargado, se saltea" if cuenta.town_hall.blank?

      bajan = suben = 0

      cuenta.account_items.includes(game_item: :game_item_levels).find_each do |item|
        tope = item.game_item.max_level_para(cuenta.town_hall)
        next if tope.nil? || tope == item.max_level

        # El nivel que la cuenta ya tiene manda: bajar el tope por debajo dejaria
        # el elemento en un estado que ni siquiera pasa la validacion.
        tope = [ tope, item.current_level ].max
        next if tope == item.max_level

        tope < item.max_level ? bajan += 1 : suben += 1
        item.update_columns(max_level: tope) if aplicar
      end

      next if bajan.zero? && suben.zero?

      puts "#{cuenta.nombre} (TH#{cuenta.town_hall}): #{bajan} topes bajan, #{suben} suben"
      puts "  progreso #{cuenta.reload.report[:progresoPct]}%" if aplicar
    end
  end
end
