require "net/http"

module Clash
  # Cliente de la API oficial de Clash of Clans.
  #
  # Existe porque el token no puede viajar al navegador: esta atado a una IP fija
  # y quien lo tenga puede consultar la API en nombre de la cuenta. El frontend
  # le pega a este backend y el token no sale de aca.
  #
  # Reemplaza al proxy Express que vivia en coc-proxy/.
  class Cliente
    BASE_URL = "https://api.clashofclans.com/v1".freeze

    # La API cambia despacio: los niveles de un jugador no se mueven en minutos,
    # y la cuota de peticiones es acotada.
    TTL = 10.minutes

    class Error < StandardError
      attr_reader :status, :cuerpo

      def initialize(mensaje, status: 502, cuerpo: nil)
        super(mensaje)
        @status = status
        @cuerpo = cuerpo
      end
    end

    # El token se configura por entorno. Sin el, los endpoints de Clash
    # responden 503 en vez de tumbar la app entera: el resto del backend (las
    # cuentas, el login) no depende de la API oficial.
    class SinToken < Error
      def initialize
        super("Falta configurar COC_TOKEN en el backend.", status: :service_unavailable)
      end
    end

    def initialize(token: ENV["COC_TOKEN"], ttl: TTL)
      @token = token.presence
      @ttl = ttl
    end

    def configurado?
      token.present?
    end

    def clan(tag)
      obtener("/clans/#{codificar(tag)}")
    end

    def jugador(tag)
      obtener("/players/#{codificar(tag)}")
    end

    def guerra_actual(tag)
      obtener("/clans/#{codificar(tag)}/currentwar")
    end

    # El clan y todos sus miembros. Los jugadores se piden en paralelo porque un
    # clan tiene hasta 50 miembros y en serie serian 50 idas y vueltas.
    #
    # Un jugador que falla no tumba la respuesta entera: se devuelve marcado, que
    # es como lo hacia el proxy Express.
    def clan_con_jugadores(tag, hilos: 8)
      datos = clan(tag)
      miembros = datos["memberList"].to_a

      jugadores = en_paralelo(miembros, hilos: hilos) do |miembro|
        begin
          jugador(miembro["tag"])
        rescue Error => e
          { "__error" => true, "tag" => miembro["tag"], "status" => e.status, "message" => e.message }
        end
      end

      { clan: datos, players: jugadores }
    end

    # El tag lo escribe una persona: "lj8v90g0", " #LJ8V90G0 ". La API quiere
    # "%23LJ8V90G0".
    def self.normalizar_tag(tag)
      limpio = tag.to_s.strip.upcase.delete_prefix("#")

      limpio.presence && "##{limpio}"
    end

    private

    attr_reader :token, :ttl

    def codificar(tag)
      CGI.escape(self.class.normalizar_tag(tag).to_s)
    end

    def obtener(ruta)
      raise SinToken unless configurado?

      Rails.cache.fetch("coc:#{ruta}", expires_in: ttl) { pedir(ruta) }
    end

    def pedir(ruta)
      respuesta = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.request(peticion(ruta))
      end

      cuerpo = parsear(respuesta.body)
      return cuerpo if respuesta.is_a?(Net::HTTPSuccess)

      raise Error.new(mensaje_de(cuerpo, respuesta), status: respuesta.code.to_i, cuerpo: cuerpo)
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Error.new("La API de Clash of Clans no respondio a tiempo.", status: :gateway_timeout)
    end

    def uri
      @uri ||= URI(BASE_URL)
    end

    def peticion(ruta)
      Net::HTTP::Get.new("#{uri.path}#{ruta}").tap do |get|
        get["Authorization"] = "Bearer #{token}"
        get["Accept"] = "application/json"
      end
    end

    def parsear(cuerpo)
      return nil if cuerpo.blank?

      JSON.parse(cuerpo)
    rescue JSON::ParserError
      { "raw" => cuerpo }
    end

    # La API explica el rechazo en "reason" y "message"; el 403 casi siempre es
    # que el token esta atado a otra IP, que es el error que mas cuesta adivinar.
    def mensaje_de(cuerpo, respuesta)
      return cuerpo["message"] if cuerpo.is_a?(Hash) && cuerpo["message"].present?
      return cuerpo["reason"] if cuerpo.is_a?(Hash) && cuerpo["reason"].present?

      "La API de Clash of Clans respondio #{respuesta.code}."
    end

    # Los resultados se escriben por indice para que el orden de la respuesta sea
    # el del clan y no el de llegada de cada peticion.
    def en_paralelo(elementos, hilos:, &tarea)
      return [] if elementos.empty?

      cola = Queue.new
      elementos.each_with_index { |elemento, indice| cola << [ elemento, indice ] }
      resultados = Array.new(elementos.size)

      trabajadores = [ hilos, elementos.size ].min.times.map do
        Thread.new do
          # Fuera del executor, un hilo propio no ve la recarga de codigo de
          # desarrollo y puede quedarse con clases viejas.
          Rails.application.executor.wrap do
            loop do
              elemento, indice = begin
                cola.pop(true)
              rescue ThreadError
                break
              end

              resultados[indice] = tarea.call(elemento)
            end
          end
        end
      end

      trabajadores.each(&:join)
      resultados
    end
  end
end
