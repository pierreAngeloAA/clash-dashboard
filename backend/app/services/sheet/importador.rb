module Sheet
  # Carga el Google Sheet en la base: una vez, para arrancar con los datos que
  # ya existian. A partir de ahi la fuente de verdad es la base, y el Sheet no
  # se vuelve a mirar.
  #
  # Es idempotente: correrlo de nuevo actualiza lo que cambio y no duplica nada,
  # asi que se puede repetir si la primera pasada quedo incompleta.
  #
  # Lo que carga:
  #
  #   - el catalogo (`GameItem` y sus niveles), deducido de lo que aparece en las
  #     pestañas: el Sheet es tambien la unica descripcion que hay del juego;
  #   - una `Account` por pestaña;
  #   - el progreso de cada cuenta (`AccountItem`), con `fuente: "sheet"` para
  #     poder distinguir despues lo importado de lo cargado a mano.
  class Importador
    Resultado = Struct.new(:cuentas, :elementos_del_catalogo, :progreso, keyword_init: true)

    def initialize(cliente: Cliente.new, logger: nil)
      @cliente = cliente
      @logger = logger
    end

    def call
      pestanias = leer_pestanias

      ActiveRecord::Base.transaction do
        catalogo = importar_catalogo(pestanias)
        progreso = importar_cuentas(pestanias, catalogo)

        Resultado.new(
          cuentas: pestanias.size,
          elementos_del_catalogo: catalogo.size,
          progreso: progreso
        )
      end
    end

    private

    attr_reader :cliente, :logger

    def informar(mensaje)
      logger&.call(mensaje)
    end

    # Descarga todas las pestañas antes de tocar la base: el catalogo necesita el
    # nivel maximo de cada elemento entre todas las cuentas, y eso no se sabe
    # hasta haberlas visto a todas.
    def leer_pestanias
      Parser.pestanias(cliente.indice).map do |pestania|
        informar("Leyendo #{pestania[:nombre]}…")

        pestania.merge(secciones: Parser.new(cliente.pestania(pestania[:gid])).call)
      end
    end

    # ---------- catalogo ----------

    def importar_catalogo(pestanias)
      catalogo = {}

      pestanias.each do |pestania|
        pestania[:secciones].each do |categoria, elementos|
          elementos.each { |elemento| acumular(catalogo, categoria, elemento) }
        end
      end

      catalogo.each_value { |datos| guardar_elemento_del_catalogo(datos) }
      catalogo
    end

    # Un mismo elemento aparece en varias cuentas y varias veces por cuenta. Del
    # conjunto se queda con el nivel maximo visto, que es el tope real del juego:
    # una cuenta de TH11 solo muestra hasta donde llega su ayuntamiento.
    def acumular(catalogo, categoria, elemento)
      clave = [ categoria, elemento[:nombre] ]
      datos = catalogo[clave] ||= {
        categoria: categoria,
        nombre: elemento[:nombre],
        max_level: 0,
        etiquetas: [],
        orden: catalogo.count { |(cat, _), _| cat == categoria } + 1
      }

      return if elemento[:max_level] <= datos[:max_level]

      datos[:max_level] = elemento[:max_level]
      datos[:etiquetas] = elemento[:etiquetas]
    end

    def guardar_elemento_del_catalogo(datos)
      game_item = GameItem.find_or_initialize_by(
        categoria: datos[:categoria],
        nombre: datos[:nombre]
      )
      game_item.max_level = datos[:max_level]
      game_item.orden = datos[:orden]
      game_item.desbloquea_en_th = ayuntamiento_inicial(datos[:etiquetas])
      game_item.save!

      guardar_niveles(game_item, datos[:etiquetas])
      datos[:registro] = game_item
    end

    # La etiqueta del primer nivel dice en que ayuntamiento aparece el elemento.
    # En guardianes las celdas traen el numero de nivel en vez del ayuntamiento,
    # y ahi no hay dato que deducir.
    def ayuntamiento_inicial(etiquetas)
      etiquetas.filter_map { |etiqueta| etiqueta.to_s[/\ATH\s*(\d+)/i, 1]&.to_i }.min || 1
    end

    def guardar_niveles(game_item, etiquetas)
      (1..game_item.max_level).each do |posicion|
        nivel = game_item.game_item_levels.find_or_initialize_by(posicion: posicion)
        nivel.etiqueta = etiquetas[posicion - 1]
        nivel.save!
      end
    end

    # ---------- cuentas y progreso ----------

    def importar_cuentas(pestanias, catalogo)
      pestanias.sum do |pestania|
        cuenta = guardar_cuenta(pestania)
        informar("Importando #{cuenta.nombre}…")

        pestania[:secciones].sum do |categoria, elementos|
          elementos.count { |elemento| guardar_progreso(cuenta, catalogo, categoria, elemento) }
        end
      end
    end

    # La pestaña se llama "PIERRE TH18": el nombre y el ayuntamiento van
    # separados en la base. El gid identifica la cuenta entre corridas, porque
    # renombrar la pestaña es justo lo que se hace al subir de ayuntamiento.
    def guardar_cuenta(pestania)
      nombre, town_hall = Account.separar_town_hall(pestania[:nombre])

      cuenta = Account.find_or_initialize_by(gid_origen: pestania[:gid])
      cuenta.nombre = nombre
      cuenta.town_hall = town_hall
      cuenta.orden = pestania[:orden] if pestania[:orden]
      cuenta.save!
      cuenta
    end

    def guardar_progreso(cuenta, catalogo, categoria, elemento)
      game_item = catalogo.dig([ categoria, elemento[:nombre] ], :registro)
      return false if game_item.nil?

      progreso = cuenta.account_items.find_or_initialize_by(
        game_item: game_item,
        indice: elemento[:indice]
      )
      # El Sheet es la semilla, no la autoridad permanente: lo que ya se
      # sincronizo con la API de Clash o se corrigio a mano esta mas al dia que
      # una planilla que se dejo de actualizar.
      return false if progreso.persisted? && !progreso.pisable_por_el_sheet?

      progreso.max_level = elemento[:max_level]
      progreso.current_level = elemento[:current_level]
      progreso.fuente = "sheet"
      progreso.save!
      true
    end
  end
end
