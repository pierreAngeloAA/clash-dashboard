require "rails_helper"

# Los endpoints que reemplazan al proxy Express de coc-proxy/.
RSpec.describe "Api::V1::Clash" do
  let(:base) { Clash::Cliente::BASE_URL }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("COC_TOKEN").and_return("un-token")
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  def stub_coc(ruta, cuerpo:, status: 200)
    stub_request(:get, "#{base}#{ruta}").to_return(
      status: status,
      body: cuerpo.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  describe "GET /api/v1/player/:tag" do
    it "devuelve el jugador sin exigir sesion" do
      stub_coc("/players/%23LJ8V90G0", cuerpo: { "name" => "Pierre" })

      get "/api/v1/player/#{CGI.escape('#LJ8V90G0')}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["name"]).to eq("Pierre")
    end

    # El tag viaja escapado como %23 y no puede confundirse con un formato.
    it "acepta el tag sin el numeral" do
      peticion = stub_coc("/players/%23LJ8V90G0", cuerpo: {})

      get "/api/v1/player/lj8v90g0"

      expect(peticion).to have_been_requested
    end

    it "traduce el error de la API conservando su codigo" do
      stub_coc("/players/%23NOEXISTE", status: 404, cuerpo: { "reason" => "notFound" })

      get "/api/v1/player/#{CGI.escape('#NOEXISTE')}"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to be_present
    end
  end

  describe "GET /api/v1/clan/:tag" do
    it "devuelve el clan con sus jugadores" do
      stub_coc("/clans/%23CLAN",
        cuerpo: { "name" => "Los Koalas", "memberList" => [ { "tag" => "#UNO" } ] })
      stub_coc("/players/%23UNO", cuerpo: { "name" => "Uno" })

      get "/api/v1/clan/#{CGI.escape('#CLAN')}"

      expect(response.parsed_body["clan"]["name"]).to eq("Los Koalas")
      expect(response.parsed_body["players"].first["name"]).to eq("Uno")
    end
  end

  describe "GET /api/v1/clan/:tag/currentwar" do
    it "devuelve la guerra actual" do
      stub_coc("/clans/%23CLAN/currentwar", cuerpo: { "state" => "inWar" })

      get "/api/v1/clan/#{CGI.escape('#CLAN')}/currentwar"

      expect(response.parsed_body["state"]).to eq("inWar")
    end
  end

  describe "sin token configurado" do
    before do
      allow(ENV).to receive(:[]).with("COC_TOKEN").and_return(nil)
    end

    # El resto del backend no depende de la API oficial: que falte el token no
    # puede tumbar la app, solo esta seccion.
    it "responde 503 con una explicacion" do
      get "/api/v1/player/lj8v90g0"

      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body["error"]).to match(/COC_TOKEN/)
    end

    it "lo informa en el health" do
      get "/api/v1/coc/health"

      expect(response.parsed_body).to include("ok" => false)
    end
  end

  describe "GET /api/v1/coc/health" do
    it "avisa que hay token configurado" do
      get "/api/v1/coc/health"

      expect(response.parsed_body).to include("ok" => true)
    end
  end
end
