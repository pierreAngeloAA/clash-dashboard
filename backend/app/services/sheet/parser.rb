require "nokogiri"

module Sheet
  # Convierte el HTML de una pestaña del Sheet en la estructura que importa
  # Sheet::Importador.
  #
  # El Sheet tiene tres layouts distintos y ninguno esta declarado en ninguna
  # parte: hay que reconocerlos.
  #
  #   1. Fila por elemento. Un encabezado de seccion ("NIVELES DEFENSAS") con los
  #      niveles 1..N a su derecha, y debajo una fila por cada copia: indice,
  #      nombre, y una celda por nivel con el ayuntamiento que lo desbloquea.
  #      Siete filas "Cañón" con indice 1..7 son los siete cañones de la cuenta.
  #
  #   2. Heroes. Cada heroe es un ancla, y debajo cuelgan filas con los niveles
  #      sueltos (1..110), agrupados por el ayuntamiento que los habilita.
  #
  #   3. Guardianes. Dos filas: el nombre del equipo en mayusculas y, debajo, la
  #      secuencia de niveles.
  #
  # En los tres casos el progreso es el color de la celda, no un numero: verde es
  # un nivel ya subido. Por eso se lee el htmlview y no la vista JSON.
  class Parser
    VERDE = "#34a853".freeze     # nivel completado
    AMARILLO = "#ffff00".freeze  # nivel en curso, se ignora: se deriva del actual

    # Las secciones con layout "fila por elemento".
    CATEGORIAS_POR_FILA = [
      "NIVELES DEFENSAS",
      "NIVELES TRAMPAS",
      "TROPAS CLARAS",
      "TROPAS OSCURAS",
      "HECHIZOS CLAROS",
      "HECHIZOS OSCUROS",
      "MAQUINAS DE ASEDIO",
      "ANIMALES"
    ].freeze

    # Etiquetas que viven en el bloque REPORT y no son elementos del catalogo.
    ETIQUETAS_DEL_REPORT = [ "REPORT", "PROGRESO", "FALTANTE", "TOTAL REPORT" ].freeze

    # Las pestañas del Sheet, que son las cuentas. El indice las publica en un
    # script, no en el HTML de la tabla.
    def self.pestanias(html)
      html.to_s.scan(/items\.push\(\{name:\s*"([^"]+)",[^}]*gid:\s*"(\d+)"/)
        .uniq { |_nombre, gid| gid }
        .map { |nombre, gid| { nombre: nombre.strip, gid: gid } }
    end

    def initialize(html)
      @html = html.to_s
    end

    def call
      secciones = secciones_por_fila
      secciones.merge!(secciones_de_heroes)
      guardianes = seccion_de_guardianes
      secciones["GUARDIANES"] = guardianes if guardianes.any?

      secciones
        .reject { |_categoria, elementos| elementos.empty? }
        .transform_values { |elementos| numerar_copias(elementos) }
    end

    private

    attr_reader :html

    # Cada celda queda como { texto:, verde: }. El colspan se expande en tantas
    # columnas como ocupa: si no, las columnas de una fila con celdas combinadas
    # dejan de alinearse con las del resto de la tabla.
    def filas
      @filas ||= begin
        fondos = {}
        html.scan(/\.(s\d+)\s*\{[^}]*background-color:\s*([^;]+);/) do |clase, color|
          fondos[clase] = color.strip.downcase
        end

        # El encoding se declara explicito: el HTML de Google no siempre trae el
        # meta charset y sin esto Nokogiri lee "Cañón" como latin-1.
        Nokogiri::HTML(html, nil, "UTF-8").css("tr").map do |tr|
          celdas = tr.css("th,td").flat_map do |td|
            celda = {
              texto: td.text.gsub(" ", " ").strip,
              verde: fondos[td["class"].to_s] == VERDE
            }
            [ celda ] * [ td["colspan"].to_i, 1 ].max
          end

          # La primera celda es el numero de fila que dibuja Google, no un dato.
          celdas.drop(1)
        end
      end
    end

    # El numero de la columna izquierda no significa lo mismo en todas las
    # secciones: en NIVELES DEFENSAS las siete filas "Cañón" van 1..7 y son las
    # siete copias, pero en TROPAS CLARAS numera la lista, y ahi "Arquera" es la
    # fila 2 aunque sea la unica arquera.
    #
    # La base necesita lo primero — el indice es "cual de las copias" — asi que
    # se renumera por nombre y el numero del Sheet se descarta.
    def numerar_copias(elementos)
      vistos = Hash.new(0)

      elementos.map do |elemento|
        vistos[elemento[:nombre]] += 1
        elemento.merge(indice: vistos[elemento[:nombre]])
      end
    end

    def categoria_en(texto, lista)
      normalizado = texto.to_s.strip.upcase
      return nil if normalizado.empty?

      lista.find do |categoria|
        categoria == normalizado ||
          categoria.start_with?(normalizado) ||
          normalizado.start_with?(categoria)
      end
    end

    # El bloque REPORT usa las mismas etiquetas que el catalogo ("REY BARBARO",
    # "ANIMALES"), pero con numeros o porcentajes pegados a la derecha. Asi se
    # distingue un encabezado de seccion de una fila del reporte, sin depender de
    # en que columna quedo cada bloque.
    def fila_del_report?(celdas, desde)
      celdas[(desde + 1)..(desde + 7)].to_a.any? do |celda|
        celda[:texto].to_s.match?(/\A-?\d+(\.\d+)?\s*%?\z/)
      end
    end

    # ---------- layout 1: una fila por elemento ----------

    def secciones_por_fila
      secciones = {}
      bloques = []

      filas.each do |celdas|
        detectar_bloques(celdas, bloques, secciones)
        cerrar_bloques_interrumpidos(celdas, bloques)

        bloques.each do |bloque|
          elemento = elemento_de(celdas, bloque)
          secciones[bloque[:categoria]] << elemento if elemento
        end
      end

      secciones
    end

    def detectar_bloques(celdas, bloques, secciones)
      (1...celdas.size).each do |columna|
        categoria = categoria_en(celdas[columna][:texto], CATEGORIAS_POR_FILA)
        next if categoria.nil?

        columnas_de_nivel = columnas_de_nivel_desde(celdas, columna)
        next if columnas_de_nivel.empty?

        # Un encabezado nuevo en la misma columna reemplaza al bloque anterior:
        # las secciones se apilan verticalmente.
        bloques.reject! { |bloque| bloque[:columna_nombre] == columna }
        bloques << {
          categoria: categoria,
          columna_nombre: columna,
          columna_indice: columna - 1,
          columnas_de_nivel: columnas_de_nivel
        }
        secciones[categoria] ||= []
      end
    end

    # Un bloque queda abierto hasta que otra seccion ocupa su columna. Un heroe
    # no es una seccion "fila por elemento", asi que no reemplaza al bloque
    # anterior por si solo, y sus filas de niveles terminarian entrando como
    # copias del ultimo elemento.
    #
    # Solo se cierra por heroes: los nombres de los equipos de guardianes se
    # reconocen por una heuristica (mayusculas, sin digitos) con la que tambien
    # cumplen elementos legitimos como "L.A.S.S.I", y usarla aca cerraria la
    # seccion de animales apenas empieza.
    def cerrar_bloques_interrumpidos(celdas, bloques)
      bloques.reject! do |bloque|
        texto = celdas[bloque[:columna_nombre]].to_h[:texto].to_s

        categoria_en(texto, GameItem::HEROES).present?
      end
    end

    # Los niveles son la tira de celdas numeradas que sigue al encabezado.
    def columnas_de_nivel_desde(celdas, columna)
      columnas = []

      ((columna + 1)...celdas.size).each do |siguiente|
        if celdas[siguiente][:texto].match?(/\A\d+\z/)
          columnas << siguiente
        elsif columnas.any?
          break
        end
      end

      columnas
    end

    def elemento_de(celdas, bloque)
      indice = celdas[bloque[:columna_indice]].to_h[:texto].to_s
      nombre = celdas[bloque[:columna_nombre]].to_h[:texto].to_s
      return nil unless indice.match?(/\A\d+\z/) && nombre.present?
      # La fila del encabezado de la siguiente seccion no es un elemento.
      return nil if categoria_en(nombre, CATEGORIAS_POR_FILA)

      niveles = niveles_de(celdas, bloque[:columnas_de_nivel])
      return nil if niveles[:max_level].zero?

      { indice: indice.to_i, nombre: nombre }.merge(niveles)
    end

    # El maximo es hasta donde llega la fila (una celda vacia es un nivel que ese
    # elemento no tiene), y el actual es el ultimo nivel pintado de verde.
    def niveles_de(celdas, columnas_de_nivel)
      current_level = 0
      max_level = 0
      etiquetas = []

      columnas_de_nivel.each_with_index do |columna, posicion|
        celda = celdas[columna].to_h
        next if celda[:texto].blank?

        max_level = posicion + 1
        etiquetas << celda[:texto]
        current_level = posicion + 1 if celda[:verde]
      end

      { current_level: current_level, max_level: max_level, etiquetas: etiquetas }
    end

    # ---------- layout 2: heroes ----------

    def secciones_de_heroes
      anclas = anclas_de_heroes
      secciones = {}

      anclas.each_with_index do |ancla, i|
        siguiente_heroe = anclas[i + 1]&.fetch(:fila) || filas.size
        heroe = heroe_entre(ancla, [ siguiente_heroe, fin_del_bloque(ancla) ].min)
        next if heroe.nil?

        # Cada heroe es una categoria propia, como en el Sheet.
        secciones[ancla[:categoria]] = [ heroe ]
      end

      secciones
    end

    def anclas_de_heroes
      anclas = []

      filas.each_with_index do |celdas, fila|
        ultima_columna = -2

        (1...celdas.size).each do |columna|
          categoria = categoria_en(celdas[columna][:texto], GameItem::HEROES)
          next if categoria.nil?

          # El colspan repite la misma celda en columnas contiguas.
          if columna == ultima_columna + 1
            ultima_columna = columna
            next
          end

          ultima_columna = columna
          next if fila_del_report?(celdas, columna)

          anclas << { categoria: categoria, fila: fila, columna: columna }
        end
      end

      anclas
    end

    # Un bloque de heroe no termina necesariamente donde empieza el heroe
    # siguiente: el ultimo heroe de la columna tiene debajo el bloque REPORT, los
    # guardianes u otra seccion, y sus numeros se sumarian al heroe.
    #
    # Solo cuentan las columnas del propio bloque. Una seccion que empieza mas a
    # la izquierda vive en otra columna del Sheet y no lo interrumpe.
    def fin_del_bloque(ancla)
      desde_columna = [ ancla[:columna] - 1, 1 ].max

      ((ancla[:fila] + 1)...filas.size).each do |fila|
        return fila if frontera?(filas[fila], desde_columna)
      end

      filas.size
    end

    def frontera?(celdas, desde_columna)
      (desde_columna...celdas.size).any? do |columna|
        texto = celdas[columna][:texto].to_s.strip
        next false if texto.blank?
        # Las filas del REPORT son las unicas con porcentajes.
        next true if texto.include?("%")
        next true if ETIQUETAS_DEL_REPORT.include?(texto.upcase)
        next true if texto.upcase.start_with?("TOTAL ")
        next true if categoria_en(texto, CATEGORIAS_POR_FILA)

        nombre_de_equipo?(texto)
      end
    end

    # Los niveles de un heroe son numeros sueltos repartidos en varias filas, y
    # el ayuntamiento que los habilita esta al principio de cada fila ("TH12:").
    def heroe_entre(ancla, fila_final)
      current_level = 0
      max_level = 0
      etiquetas = {}

      ((ancla[:fila] + 1)...fila_final).each do |fila|
        celdas = filas[fila].to_a
        ayuntamiento = nil

        (ancla[:columna]...celdas.size).each do |columna|
          texto = celdas[columna][:texto].to_s

          if (th = texto[/\ATH\s*(\d+)/i, 1])
            ayuntamiento = "TH#{th}"
            next
          end
          next unless texto.match?(/\A\d+\z/)

          nivel = texto.to_i
          max_level = nivel if nivel > max_level
          current_level = nivel if celdas[columna][:verde] && nivel > current_level
          etiquetas[nivel] = ayuntamiento if ayuntamiento
        end
      end

      return nil if max_level.zero?

      {
        indice: 1,
        nombre: ancla[:categoria],
        current_level: current_level,
        max_level: max_level,
        etiquetas: (1..max_level).map { |nivel| etiquetas[nivel] }
      }
    end

    # ---------- layout 3: guardianes ----------

    def seccion_de_guardianes
      equipos = []

      filas.each_with_index do |celdas, fila|
        siguiente = filas[fila + 1]
        break if siguiente.nil?

        equipo = equipo_de_guardianes(celdas, siguiente)
        equipos << equipo.merge(indice: 1) if equipo
      end

      equipos
    end

    def equipo_de_guardianes(celdas, siguiente)
      (1...celdas.size).each do |columna|
        nombre = celdas[columna][:texto].to_s.strip
        next unless nombre_de_equipo?(nombre)
        next if fila_del_report?(celdas, columna)

        # Debajo del nombre tiene que venir la tira de niveles del equipo.
        columnas_de_nivel = columnas_de_nivel_desde(siguiente, columna - 2)
        next if columnas_de_nivel.size < 3

        niveles = niveles_de(siguiente, columnas_de_nivel)
        next if niveles[:max_level].zero?

        # Solo un equipo por fila.
        return { nombre: nombre }.merge(niveles)
      end

      nil
    end

    # Los nombres de equipo son los unicos textos en mayusculas, sin digitos y
    # sin ser una categoria conocida: asi el importador sirve con cualquier
    # equipo, sin una lista fija que haya que mantener.
    def nombre_de_equipo?(texto)
      return false if texto.length < 5
      return false if texto != texto.upcase
      return false if texto.match?(/\d/)
      return false if ETIQUETAS_DEL_REPORT.include?(texto)
      return false if texto.start_with?("TOTAL ")

      categoria_en(texto, GameItem::CATEGORIAS).nil?
    end
  end
end
