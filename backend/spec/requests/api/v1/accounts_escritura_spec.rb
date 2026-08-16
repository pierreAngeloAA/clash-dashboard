require "rails_helper"

# Las acciones de escritura de cuentas y de elementos. La lectura vive en
# accounts_spec.rb, que no necesita sesion.
RSpec.describe "Api::V1::Accounts escritura" do
  let(:password) { "contrasena-larga-123" }
  let!(:usuario) { create(:user, email: "pierre@clash.test", password: password) }

  def token
    post "/api/v1/login",
      params: { user: { email: "pierre@clash.test", password: password } },
      as: :json
    response.headers["Authorization"]
  end

  def con_sesion = { "Authorization" => token }

  describe "POST /api/v1/accounts" do
    let(:datos) { { account: { nombre: "Pierre", town_hall: 15 } } }

    it "crea la cuenta y responde 201" do
      post "/api/v1/accounts", params: datos, headers: con_sesion, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("account", "nombre")).to eq("Pierre")
    end

    it "rechaza la creacion sin sesion" do
      expect {
        post "/api/v1/accounts", params: datos, as: :json
      }.not_to change(Account, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it "normaliza el tag de Clash que escribe el usuario" do
      post "/api/v1/accounts",
        params: { account: { nombre: "Pierre", tag_coc: " lj8v90g0 " } },
        headers: con_sesion,
        as: :json

      expect(response.parsed_body.dig("account", "tagCoc")).to eq("#LJ8V90G0")
    end

    it "devuelve 422 y el motivo si los datos no sirven" do
      create(:account, nombre: "Pierre")

      post "/api/v1/accounts", params: datos, headers: con_sesion, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].join).to match(/nombre/i)
    end

    # El inventario no se carga a mano: sale del catalogo y del ayuntamiento.
    it "le genera el inventario que su ayuntamiento habilita" do
      create(:game_item, nombre: "Canon", desbloquea_en_th: 1)
      create(:game_item, :animal, desbloquea_en_th: 14)

      post "/api/v1/accounts",
        params: { account: { nombre: "Nueva", town_hall: 9 } },
        headers: con_sesion,
        as: :json

      cuenta = Account.find(response.parsed_body.dig("account", "id"))
      expect(cuenta.defensas.count).to eq(1)
      expect(cuenta.animales.count).to eq(0)
    end
  end

  describe "PATCH /api/v1/accounts/:id" do
    let!(:cuenta) { create(:account, nombre: "Pierre", town_hall: 9) }

    it "actualiza los datos de la cuenta" do
      patch "/api/v1/accounts/#{cuenta.id}",
        params: { account: { nombre: "Pierre 2" } },
        headers: con_sesion,
        as: :json

      expect(response).to have_http_status(:ok)
      expect(cuenta.reload.nombre).to eq("Pierre 2")
    end

    it "rechaza la edicion sin sesion" do
      patch "/api/v1/accounts/#{cuenta.id}",
        params: { account: { nombre: "Intruso" } },
        as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(cuenta.reload.nombre).to eq("Pierre")
    end

    it "devuelve 404 si la cuenta no existe" do
      patch "/api/v1/accounts/0", params: { account: { nombre: "X" } }, headers: con_sesion, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "no deja editar el gid de origen, que lo escribe el importador" do
      cuenta.update!(gid_origen: "123")

      patch "/api/v1/accounts/#{cuenta.id}",
        params: { account: { gid_origen: "999" } },
        headers: con_sesion,
        as: :json

      expect(cuenta.reload.gid_origen).to eq("123")
    end

    context "al subir de ayuntamiento" do
      before do
        create(:game_item, :con_disponibilidad,
          nombre: "Canon",
          max_level: 21,
          por_town_hall: { 9 => { cantidad: 1, max_level: 13 }, 15 => { cantidad: 2, max_level: 21 } })
        create(:game_item, :animal, desbloquea_en_th: 14)
        cuenta.poblar_inventario
      end

      it "le agrega lo que el ayuntamiento nuevo habilita" do
        expect {
          patch "/api/v1/accounts/#{cuenta.id}",
            params: { account: { town_hall: 15 } },
            headers: con_sesion,
            as: :json
        }.to change { cuenta.animales.count }.from(0).to(1)
      end

      it "sube el tope de lo que ya tenia" do
        patch "/api/v1/accounts/#{cuenta.id}",
          params: { account: { town_hall: 15 } },
          headers: con_sesion,
          as: :json

        expect(cuenta.defensas.first.reload.max_level).to eq(21)
      end

      it "no repuebla si el ayuntamiento no cambio" do
        expect {
          patch "/api/v1/accounts/#{cuenta.id}",
            params: { account: { nombre: "Otro nombre" } },
            headers: con_sesion,
            as: :json
        }.not_to change(AccountItem, :count)
      end
    end
  end

  describe "DELETE /api/v1/accounts/:id" do
    let!(:cuenta) { create(:account, town_hall: nil) }

    it "borra la cuenta y responde 204" do
      delete "/api/v1/accounts/#{cuenta.id}", headers: con_sesion

      expect(response).to have_http_status(:no_content)
      expect(Account.exists?(cuenta.id)).to be(false)
    end

    it "rechaza el borrado sin sesion" do
      delete "/api/v1/accounts/#{cuenta.id}"

      expect(response).to have_http_status(:unauthorized)
      expect(Account.exists?(cuenta.id)).to be(true)
    end

    it "se lleva el progreso de la cuenta, no solo la fila" do
      create(:defensa, account: cuenta)

      expect {
        delete "/api/v1/accounts/#{cuenta.id}", headers: con_sesion
      }.to change(AccountItem, :count).by(-1)
    end
  end

  describe "PATCH /api/v1/accounts/:account_id/items/:id" do
    let(:cuenta) { create(:account, town_hall: nil) }
    let(:item) { create(:defensa, account: cuenta, current_level: 5, max_level: 21) }

    def editar(datos, headers: con_sesion)
      patch "/api/v1/accounts/#{cuenta.id}/items/#{item.id}",
        params: { item: datos },
        headers: headers,
        as: :json
    end

    it "sube el nivel del elemento" do
      editar({ current_level: 6 })

      expect(response).to have_http_status(:ok)
      expect(item.reload.current_level).to eq(6)
    end

    it "devuelve el elemento con los niveles recalculados" do
      editar({ current_level: 6 })

      expect(response.parsed_body["item"]).to include(
        "currentLevel" => 6, "faltante" => 15, "completo" => false
      )
    end

    it "rechaza la edicion sin sesion" do
      editar({ current_level: 20 }, headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(item.reload.current_level).to eq(5)
    end

    # Si alguien lo edita a mano, el dato es manual por definicion.
    it "marca como manual el nivel editado a mano" do
      item.update!(fuente: "api")

      editar({ current_level: 6 })

      expect(item.reload.fuente).to eq("manual")
    end

    it "no acepta que el cliente diga de donde viene el dato" do
      editar({ current_level: 6, fuente: "api" })

      expect(item.reload.fuente).to eq("manual")
    end

    it "permite bloquear el elemento sin tocar su nivel ni su fuente" do
      item.update!(fuente: "api")

      editar({ bloqueado: true })

      expect(item.reload).to have_attributes(bloqueado: true, fuente: "api", current_level: 5)
    end

    it "rechaza un nivel mayor que el tope del elemento" do
      editar({ current_level: 99 })

      expect(response).to have_http_status(:unprocessable_content)
      expect(item.reload.current_level).to eq(5)
    end

    # El panel muestra estos mensajes tal cual, y el panel es en español.
    it "explica el rechazo en español, con el nombre del campo traducido" do
      editar({ current_level: 99 })

      expect(response.parsed_body["errors"]).to eq([ "nivel actual debe ser menor que o igual a 21" ])
    end

    it "rechaza un tope mayor que el maximo del juego" do
      editar({ max_level: 999 })

      expect(response).to have_http_status(:unprocessable_content)
    end

    # El id del elemento es global, asi que sin buscarlo dentro de la cuenta se
    # podria editar el progreso de otra pasando su id.
    it "no deja editar un elemento de otra cuenta" do
      ajena = create(:account, town_hall: nil)
      item_ajeno = create(:defensa, account: ajena, current_level: 1)

      patch "/api/v1/accounts/#{cuenta.id}/items/#{item_ajeno.id}",
        params: { item: { current_level: 20 } },
        headers: con_sesion,
        as: :json

      expect(response).to have_http_status(:not_found)
      expect(item_ajeno.reload.current_level).to eq(1)
    end
  end

  describe "POST /api/v1/accounts/:id/sincronizar" do
    let(:cuenta) { create(:account, :sincronizable, town_hall: nil) }

    # El cliente saca el token de COC_TOKEN y sin token falla antes de pedir
    # nada. Esta maquina puede tenerlo cargado y el CI no, asi que se fija aca:
    # de lo contrario el resultado del spec depende de donde corra.
    around do |ejemplo|
      anterior = ENV["COC_TOKEN"]
      ENV["COC_TOKEN"] = "token-de-prueba"
      ejemplo.run
    ensure
      ENV["COC_TOKEN"] = anterior
    end

    def sincronizar(headers: con_sesion)
      post "/api/v1/accounts/#{cuenta.id}/sincronizar", headers: headers, as: :json
    end

    def con_catalogo(nombre_api, current_level, max_level)
      catalogo = create(:game_item, categoria: "TROPAS CLARAS",
        nombre: nombre_api, nombre_api: nombre_api, max_level: 100)
      AccountItem.create!(account: cuenta, game_item: catalogo,
        current_level: current_level, max_level: max_level, fuente: "sheet")
    end

    def responder_api(entradas)
      stub_request(:get, %r{/players/})
        .to_return(status: 200, body: { "troops" => entradas }.to_json,
          headers: { "Content-Type" => "application/json" })
    end

    it "rechaza la sincronizacion sin sesion" do
      item = con_catalogo("Barbarian", 5, 12)
      responder_api([ { "name" => "Barbarian", "level" => 11, "maxLevel" => 12,
        "village" => "home" } ])

      sincronizar(headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(item.reload.current_level).to eq(5)
    end

    it "aplica el progreso que trae la API" do
      item = con_catalogo("Barbarian", 5, 12)
      responder_api([ { "name" => "Barbarian", "level" => 11, "maxLevel" => 12,
        "village" => "home" } ])

      sincronizar

      expect(response).to have_http_status(:ok)
      expect(item.reload.current_level).to eq(11)
    end

    # Sin el resumen, una sincronizacion que actualizo tres de setenta elementos
    # porque el catalogo esta a medio mapear se ve igual de exitosa que una
    # completa.
    it "devuelve el resumen de lo que hizo" do
      con_catalogo("Barbarian", 5, 12)
      responder_api([ { "name" => "Barbarian", "level" => 11, "maxLevel" => 12,
        "village" => "home" } ])

      sincronizar

      expect(response.parsed_body["resumen"]).to include("actualizados" => 1)
    end

    it "devuelve la cuenta con el report ya recalculado" do
      con_catalogo("Barbarian", 0, 10)
      responder_api([ { "name" => "Barbarian", "level" => 10, "maxLevel" => 10,
        "village" => "home" } ])

      sincronizar

      expect(response.parsed_body.dig("account", "report", "progresoPct")).to eq(100.0)
    end

    it "explica en español que la cuenta no tiene tag" do
      sin_tag = create(:account, town_hall: nil)

      post "/api/v1/accounts/#{sin_tag.id}/sincronizar", headers: con_sesion, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to match(/no tiene tag/)
    end

    # La API rechaza el token cuando la IP cambia. Es el fallo mas comun y no es
    # culpa de quien aprieta el boton.
    it "traduce el fallo de la API en vez de reventar" do
      con_catalogo("Barbarian", 5, 12)
      stub_request(:get, %r{/players/}).to_return(
        status: 403,
        body: { "reason" => "accessDenied.invalidIp",
                "message" => "Invalid authorization" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      sincronizar

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body["error"]).to be_present
    end
  end
end
