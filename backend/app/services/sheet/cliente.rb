require "net/http"

module Sheet
  # Descarga el Google Sheet publico.
  #
  # Se leen las dos vistas de `htmlview` porque son las unicas que traen el color
  # de cada celda, y en el Sheet el color es el dato: verde es un nivel ya
  # subido. La vista `gviz`, que devuelve JSON prolijo, no expone el formato.
  class Cliente
    # El mismo Sheet que lee el frontend (frontend/src/services/sheetsService.js).
    SHEET_ID = "1gosF9F2mdWuQRH2ubcsc39WRy66x81K9UjRlFdwNbpo".freeze

    class Error < StandardError; end

    def initialize(sheet_id: SHEET_ID)
      @sheet_id = sheet_id
    end

    # El indice: trae el listado de pestañas.
    def indice
      descargar("https://docs.google.com/spreadsheets/d/#{sheet_id}/htmlview")
    end

    def pestania(gid)
      descargar(
        "https://docs.google.com/spreadsheets/d/#{sheet_id}/htmlview/sheet?headers=true&gid=#{gid}"
      )
    end

    private

    attr_reader :sheet_id

    # Google responde con redirecciones cuando el documento se movio o cuando la
    # URL canonica cambia; sin seguirlas la descarga devuelve un cuerpo vacio.
    def descargar(url, saltos_restantes: 5)
      respuesta = Net::HTTP.get_response(URI(url))

      case respuesta
      when Net::HTTPSuccess
        # Net::HTTP no aplica el charset de la respuesta: devuelve los bytes como
        # ASCII-8BIT y "Cañón" termina guardado como "CaÃ±Ã³n".
        respuesta.body.dup.force_encoding(respuesta.type_params["charset"] || "UTF-8")
      when Net::HTTPRedirection
        raise Error, "Demasiadas redirecciones al leer el Sheet." if saltos_restantes.zero?

        descargar(respuesta["location"], saltos_restantes: saltos_restantes - 1)
      else
        raise Error,
          "No se pudo leer el Sheet (HTTP #{respuesta.code}). ¿Sigue compartido como publico?"
      end
    end
  end
end
