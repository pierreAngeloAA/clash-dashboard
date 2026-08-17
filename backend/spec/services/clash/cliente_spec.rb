require "rails_helper"

RSpec.describe Clash::Cliente do
  let(:cliente) { described_class.new(token: "un-token") }
  let(:base) { described_class::BASE_URL }

  # El caché del entorno de test es :null_store, que no guarda nada: para probar
  # que el cliente cachea hace falta uno de verdad.
  before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

  def stub_jugador(tag, cuerpo: { "name" => "Pierre" }, status: 200)
    stub_request(:get, "#{base}/players/#{CGI.escape(tag)}").to_return(
      status: status,
      body: cuerpo.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  describe ".normalizar_tag" do
    it "agrega el numeral y pasa a mayusculas" do
      expect(described_class.normalizar_tag(" lj8v90g0 ")).to eq("#LJ8V90G0")
    end

    it "no duplica el numeral" do
      expect(described_class.normalizar_tag("#LJ8V90G0")).to eq("#LJ8V90G0")
    end

    it "devuelve nil si no hay tag" do
      expect(described_class.normalizar_tag("  ")).to be_nil
    end
  end

  describe "#jugador" do
    it "consulta la API con el tag escapado" do
      peticion = stub_jugador("#LJ8V90G0")

      cliente.jugador("lj8v90g0")

      expect(peticion).to have_been_requested
    end

    it "manda el token en el header, que es la razon de que este proxy exista" do
      stub_request(:get, "#{base}/players/%23LJ8V90G0")
        .with(headers: { "Authorization" => "Bearer un-token" })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      expect { cliente.jugador("#LJ8V90G0") }.not_to raise_error
    end

    it "devuelve el cuerpo ya parseado" do
      stub_jugador("#LJ8V90G0", cuerpo: { "name" => "Pierre", "townHallLevel" => 18 })

      expect(cliente.jugador("#LJ8V90G0")).to include("townHallLevel" => 18)
    end

    it "no vuelve a preguntar lo que ya pregunto" do
      peticion = stub_jugador("#LJ8V90G0")

      3.times { cliente.jugador("#LJ8V90G0") }

      expect(peticion).to have_been_requested.once
    end
  end

  describe "errores" do
    it "avisa si falta el token en vez de intentar la consulta" do
      sin_token = described_class.new(token: nil)

      expect { sin_token.jugador("#LJ8V90G0") }
        .to raise_error(described_class::SinToken)
    end

    it "no se considera configurado sin token" do
      expect(described_class.new(token: "").configurado?).to be(false)
    end

    # El 403 es casi siempre el token atado a otra IP, y es el error que mas
    # cuesta adivinar desde el frontend.
    it "propaga el motivo que da la API" do
      stub_jugador("#LJ8V90G0",
        status: 403,
        cuerpo: { "reason" => "accessDenied", "message" => "Invalid authorization" })

      expect { cliente.jugador("#LJ8V90G0") }
        .to raise_error(described_class::Error, "Invalid authorization")
    end

    it "conserva el codigo de la API" do
      stub_jugador("#NOEXISTE", status: 404, cuerpo: { "reason" => "notFound" })

      expect { cliente.jugador("#NOEXISTE") }.to raise_error(described_class::Error) { |e|
        expect(e.status).to eq(404)
      }
    end

    it "no cachea una respuesta con error" do
      peticion = stub_jugador("#LJ8V90G0", status: 500, cuerpo: { "reason" => "roto" })

      2.times { cliente.jugador("#LJ8V90G0") rescue nil }

      expect(peticion).to have_been_requested.twice
    end

    it "avisa cuando la API no responde a tiempo" do
      stub_request(:get, "#{base}/players/%23LJ8V90G0").to_timeout

      expect { cliente.jugador("#LJ8V90G0") }
        .to raise_error(described_class::Error, /no respondio a tiempo/)
    end
  end

  describe "#clan_con_jugadores" do
    before do
      stub_request(:get, "#{base}/clans/%23CLAN").to_return(
        status: 200,
        body: {
          "name" => "Los Koalas",
          "memberList" => [ { "tag" => "#UNO" }, { "tag" => "#DOS" }, { "tag" => "#TRES" } ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      stub_jugador("#UNO", cuerpo: { "name" => "Uno" })
      stub_jugador("#DOS", cuerpo: { "name" => "Dos" })
      stub_jugador("#TRES", cuerpo: { "name" => "Tres" })
    end

    it "devuelve el clan y sus jugadores" do
      resultado = cliente.clan_con_jugadores("#CLAN")

      expect(resultado[:clan]["name"]).to eq("Los Koalas")
      expect(resultado[:players].map { |j| j["name"] }).to eq(%w[Uno Dos Tres])
    end

    # Se piden en paralelo, asi que el orden de llegada no es el del clan.
    it "respeta el orden del clan aunque las respuestas lleguen mezcladas" do
      resultado = cliente.clan_con_jugadores("#CLAN", hilos: 3)

      expect(resultado[:players].map { |j| j["name"] }).to eq(%w[Uno Dos Tres])
    end

    # Un miembro que falla no puede dejar sin datos a los otros 49.
    it "marca al jugador que falla sin tumbar la respuesta" do
      stub_jugador("#DOS", status: 404, cuerpo: { "reason" => "notFound" })

      resultado = cliente.clan_con_jugadores("#CLAN")

      expect(resultado[:players][1]).to include("__error" => true, "status" => 404)
      expect(resultado[:players][2]["name"]).to eq("Tres")
    end

    it "aguanta un clan sin miembros" do
      stub_request(:get, "#{base}/clans/%23VACIO").to_return(
        status: 200,
        body: { "name" => "Vacio" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect(cliente.clan_con_jugadores("#VACIO")[:players]).to eq([])
    end
  end

  describe "#guerra_actual" do
    it "consulta la guerra del clan" do
      peticion = stub_request(:get, "#{base}/clans/%23CLAN/currentwar")
        .to_return(status: 200, body: { "state" => "inWar" }.to_json,
          headers: { "Content-Type" => "application/json" })

      expect(cliente.guerra_actual("clan")["state"]).to eq("inWar")
      expect(peticion).to have_been_requested
    end
  end

  # Pegar un JWT largo en un formulario web suele dejarle un salto de linea. Con
  # el, Net::HTTP levanta "header field value cannot include CR/LF" al armar la
  # peticion, y eso sale como un 500 vacio sin ninguna pista.
  describe "tokens con espacios de mas" do
    it "funciona con un token que trae un salto de linea al final" do
      stub_jugador("#2PP")

      cliente = described_class.new(token: "un-token\n")

      expect { cliente.jugador("#2PP") }.not_to raise_error
    end

    it "manda el token limpio en el header" do
      peticion = stub_request(:get, "#{base}/players/%232PP")
        .with(headers: { "Authorization" => "Bearer un-token" })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      described_class.new(token: "  un-token\n").jugador("#2PP")

      expect(peticion).to have_been_requested
    end

    it "sigue considerando sin token a uno que es solo espacios" do
      expect(described_class.new(token: " \n ").configurado?).to be(false)
    end
  end
end
