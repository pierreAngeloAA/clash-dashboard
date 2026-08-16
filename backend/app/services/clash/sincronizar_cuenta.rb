module Clash
  # Trae el progreso real de una cuenta desde la API oficial y lo aplica.
  #
  # Reemplaza a corregir los niveles a mano uno por uno, que es lo que el Sheet
  # obligaba a hacer. Solo alcanza a lo que la API sabe responder: defensas,
  # trampas y muros quedan afuera porque la API no los expone, y siguen siendo
  # carga manual.
  #
  # Nunca pisa lo que alguien protegio con el candado, ni lo que el catalogo no
  # tiene mapeado al nombre de la API. Todo lo que no se pudo aplicar queda
  # contado en el informe en vez de perderse en silencio: una sincronizacion que
  # dice "listo" habiendo actualizado tres de setenta elementos es peor que una
  # que falla.
  class SincronizarCuenta
    # Donde la API guarda el progreso del jugador. Los animales y las maquinas de
    # asedio no tienen seccion propia: vienen entre las tropas.
    SECCIONES = %w[troops heroes spells heroEquipment].freeze

    # La aldea del constructor repite nombres con la principal ("Barbarian" esta
    # en las dos). Sin este filtro, un barbaro de la aldea del constructor podria
    # pisar el nivel del de la principal.
    ALDEA = "home".freeze

    Informe = Struct.new(
      :actualizados, :sin_cambios, :protegidos, :sin_mapear,
      :no_encontrados, :desconocidos, :rechazados,
      keyword_init: true
    ) do
      def resumen
        {
          actualizados: actualizados.size,
          sinCambios: sin_cambios.size,
          protegidos: protegidos.size,
          sinMapear: sin_mapear.size,
          noEncontrados: no_encontrados.size,
          desconocidos: desconocidos.size,
          rechazados: rechazados.size
        }
      end
    end

    class SinTag < StandardError
      def initialize
        super("La cuenta no tiene tag de Clash, asi que no se puede sincronizar.")
      end
    end

    def initialize(account, cliente: Cliente.new)
      @account = account
      @cliente = cliente
    end

    def call
      raise SinTag unless account.sincronizable?

      indice = indexar(cliente.jugador(account.tag_coc))
      informe = informe_vacio

      account.account_items.includes(:game_item).find_each do |item|
        clasificar(item, indice, informe)
      end

      # Lo que la API trajo y el catalogo no reconoce. Suele ser contenido nuevo
      # del juego, y es la señal de que el catalogo quedo viejo.
      informe.desconocidos = indice.keys - nombres_mapeados
      informe
    end

    private

    attr_reader :account, :cliente

    def clasificar(item, indice, informe)
      return informe.protegidos << item if item.bloqueado?
      return informe.sin_mapear << item unless item.game_item.sincronizable_con_api?

      dato = indice[clave(item.game_item.nombre_api)]
      return informe.no_encontrados << item if dato.nil?

      aplicar(item, dato, informe)
    end

    def aplicar(item, dato, informe)
      nivel = dato["level"].to_i
      tope = dato["maxLevel"].to_i

      if item.current_level == nivel && item.max_level == tope
        return informe.sin_cambios << item
      end

      item.aplicar_desde_api!(nivel, max_del_api: tope)
      informe.actualizados << item
    rescue ActiveRecord::RecordInvalid => e
      # Pasa cuando la API conoce un tope mas alto que el que tiene el catalogo,
      # es decir cuando el juego subio el maximo y el catalogo todavia no. No
      # frena la sincronizacion del resto.
      informe.rechazados << { item: item, motivo: e.record.errors.full_messages.join(". ") }
    end

    # { "barbarian" => { "level" => 80, "maxLevel" => 95 }, ... }
    def indexar(jugador)
      SECCIONES
        .flat_map { |seccion| jugador[seccion] || [] }
        .select { |entrada| entrada["village"] == ALDEA }
        .index_by { |entrada| clave(entrada["name"]) }
    end

    def nombres_mapeados
      @nombres_mapeados ||= GameItem.de_la_api
        .where.not(nombre_api: nil)
        .pluck(:nombre_api)
        .map { |nombre| clave(nombre) }
    end

    # La API escribe "Barbarian King" y el catalogo podria tener "barbarian
    # king": comparar en minusculas evita que una mayuscula rompa el cruce.
    def clave(nombre)
      nombre.to_s.strip.downcase
    end

    def informe_vacio
      Informe.new(
        actualizados: [], sin_cambios: [], protegidos: [], sin_mapear: [],
        no_encontrados: [], desconocidos: [], rechazados: []
      )
    end
  end
end
