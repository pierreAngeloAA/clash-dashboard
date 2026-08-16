require "rails_helper"

RSpec.describe "Api::V1::Accounts" do
  # Sin ayuntamiento la cuenta no se autopuebla del catalogo, asi que cada
  # ejemplo controla exactamente que elementos tiene.
  let(:cuenta) { create(:account, nombre: "Pierre", town_hall: nil) }

  def agregar(categoria, max_level, current_level, nombre: nil, niveles: 0)
    catalogo = create(:game_item,
      categoria: categoria,
      nombre: nombre || "#{categoria} #{SecureRandom.hex(3)}",
      max_level: max_level)
    (1..niveles).each { |posicion| create(:game_item_level, game_item: catalogo, posicion: posicion) }

    AccountItem.create!(
      account: cuenta,
      game_item: catalogo,
      max_level: max_level,
      current_level: current_level
    )
  end

  describe "GET /api/v1/accounts" do
    it "responde 200 sin necesidad de sesion" do
      get "/api/v1/accounts"

      expect(response).to have_http_status(:ok)
    end

    it "devuelve los datos de cada cuenta" do
      create(:account, :sincronizable, nombre: "Pierre", town_hall: 15, builder_hall: 10)

      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"].first).to include(
        "nombre" => "Pierre",
        "townHall" => 15,
        "builderHall" => 10,
        "sincronizable" => true
      )
    end

    it "marca como no sincronizable a la cuenta sin tag" do
      cuenta

      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"].first["sincronizable"]).to be(false)
    end

    it "respeta el orden manual y desempata por nombre" do
      create(:account, nombre: "Ultima", orden: 2)
      create(:account, nombre: "Zulema", orden: 1)
      create(:account, nombre: "Ana", orden: 1)

      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"].map { |c| c["nombre"] })
        .to eq(%w[Ana Zulema Ultima])
    end

    it "devuelve una lista vacia si todavia no hay cuentas" do
      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"]).to eq([])
    end

    # El report es una consulta agregada por cuenta: en la lista serian tantas
    # consultas como filas, y la lista no lo muestra.
    it "no incluye el report en la lista" do
      cuenta

      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"].first).not_to have_key("report")
    end

    # De todo el report, el porcentaje global si viaja en la lista: es la barra
    # de progreso de cada tarjeta del dashboard.
    it "incluye el porcentaje de progreso de cada cuenta" do
      agregar("NIVELES DEFENSAS", 10, 4)
      agregar("NIVELES DEFENSAS", 10, 6)

      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"].first["progresoPct"]).to eq(50.0)
    end

    it "devuelve 0 de progreso para la cuenta sin elementos" do
      cuenta

      get "/api/v1/accounts"

      expect(response.parsed_body["accounts"].first["progresoPct"]).to eq(0.0)
    end

    it "da el mismo porcentaje que el detalle de la cuenta" do
      agregar("NIVELES DEFENSAS", 10, 3)

      get "/api/v1/accounts"
      en_la_lista = response.parsed_body["accounts"].first["progresoPct"]
      get "/api/v1/accounts/#{cuenta.id}"

      expect(en_la_lista).to eq(response.parsed_body.dig("report", "progresoPct"))
    end

    # El progreso se agrega para todas las cuentas de una vez. Si se calculara
    # cuenta por cuenta, el numero de consultas creceria con las filas.
    it "no dispara una consulta por cuenta al calcular el progreso" do
      def consultas_de_la_lista
        consultas = 0
        contador = ->(*, payload) { consultas += 1 unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(contador, "sql.active_record") do
          get "/api/v1/accounts"
        end

        consultas
      end

      create(:account, nombre: "Una")
      con_una = consultas_de_la_lista

      create_list(:account, 5, town_hall: nil)

      expect(consultas_de_la_lista).to eq(con_una)
    end
  end

  describe "GET /api/v1/accounts/:id" do
    it "responde 200 sin necesidad de sesion" do
      get "/api/v1/accounts/#{cuenta.id}"

      expect(response).to have_http_status(:ok)
    end

    it "devuelve 404 si la cuenta no existe" do
      get "/api/v1/accounts/0"

      expect(response).to have_http_status(:not_found)
    end

    it "explica el 404 en español" do
      get "/api/v1/accounts/0"

      expect(response.parsed_body["error"]).to eq("No se encontro la cuenta.")
    end

    it "agrupa el progreso por seccion" do
      agregar("NIVELES DEFENSAS", 21, 10, nombre: "Canon")
      agregar("TROPAS CLARAS", 12, 12, nombre: "Barbaro")

      get "/api/v1/accounts/#{cuenta.id}"

      secciones = response.parsed_body["secciones"]
      expect(secciones.keys).to contain_exactly("NIVELES DEFENSAS", "TROPAS CLARAS")
      expect(secciones["NIVELES DEFENSAS"].first).to include(
        "nombre" => "Canon", "currentLevel" => 10, "maxLevel" => 21, "faltante" => 11
      )
    end

    it "ordena las secciones como las mostraba el Sheet" do
      agregar("TROPAS CLARAS", 12, 1)
      agregar("NIVELES DEFENSAS", 21, 1)

      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body["secciones"].keys).to eq([ "NIVELES DEFENSAS", "TROPAS CLARAS" ])
    end

    it "marca como completo el elemento que llego al maximo" do
      agregar("TROPAS CLARAS", 12, 12)

      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body.dig("secciones", "TROPAS CLARAS", 0, "completo")).to be(true)
    end

    # Lo que en el Sheet era un color de celda ahora se deriva del nivel actual.
    it "devuelve el estado de cada nivel del catalogo" do
      agregar("TROPAS CLARAS", 3, 1, niveles: 3)

      get "/api/v1/accounts/#{cuenta.id}"

      estados = response.parsed_body
        .dig("secciones", "TROPAS CLARAS", 0, "niveles")
        .map { |nivel| nivel["estado"] }

      expect(estados).to eq(%w[hecho en_curso pendiente])
    end

    # Los poderes son de los heroes: el detalle los devuelve colgando del heroe,
    # no sueltos en la cuenta.
    it "devuelve los poderes dentro de su heroe" do
      catalogo_heroe = create(:game_item, :heroe, categoria: "REY BARBARO")
      rey = create(:heroe, account: cuenta, game_item: catalogo_heroe)
      create(:guardian,
        account: cuenta,
        game_item: create(:game_item, :poder_del_rey, nombre: "Guantelete Gigante"),
        current_level: 3,
        max_level: 27)

      get "/api/v1/accounts/#{cuenta.id}"

      heroe = response.parsed_body.dig("secciones", "REY BARBARO", 0)
      expect(heroe["id"]).to eq(rey.id)
      expect(heroe["poderes"].map { |p| p["nombre"] }).to eq([ "Guantelete Gigante" ])
      expect(heroe["poderes"].first).to include("currentLevel" => 3, "maxLevel" => 27)
    end

    it "devuelve el heroe sin poderes como una lista vacia" do
      create(:heroe, account: cuenta, game_item: create(:game_item, :heroe))

      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body.dig("secciones", "REY BARBARO", 0, "poderes")).to eq([])
    end

    it "no le pone poderes a lo que no es un heroe" do
      agregar("NIVELES DEFENSAS", 21, 10, nombre: "Canon")

      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body.dig("secciones", "NIVELES DEFENSAS", 0)).not_to have_key("poderes")
    end

    it "incluye el report calculado" do
      agregar("NIVELES DEFENSAS", 10, 4)
      agregar("NIVELES DEFENSAS", 10, 6)

      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body["report"]).to include(
        "progresoPct" => 50.0, "faltantePct" => 50.0, "hasReport" => true
      )
    end

    # La fila HEROES agrega seis secciones. Sin esta lista el frontend tendria
    # que saberse los nombres de los heroes para abrir su desglose.
    it "dice de que secciones sale cada categoria del report" do
      agregar("NIVELES DEFENSAS", 10, 4)
      agregar("REY BARBARO", 10, 4)
      agregar("REINA ARQUERA", 10, 4)

      get "/api/v1/accounts/#{cuenta.id}"

      categorias = response.parsed_body.dig("report", "categories")
        .to_h { |c| [ c["label"], c["secciones"] ] }
      expect(categorias["NIVELES DEFENSAS"]).to eq([ "NIVELES DEFENSAS" ])
      expect(categorias["HEROES"]).to contain_exactly("REY BARBARO", "REINA ARQUERA")
    end

    it "no le atribuye a HEROES las secciones de heroe que la cuenta no tiene" do
      agregar("REY BARBARO", 10, 4)

      get "/api/v1/accounts/#{cuenta.id}"

      heroes = response.parsed_body.dig("report", "categories")
        .find { |c| c["label"] == "HEROES" }
      expect(heroes["secciones"]).to eq([ "REY BARBARO" ])
    end

    it "recalcula el report despues de editar un nivel, sin datos guardados" do
      item = agregar("NIVELES DEFENSAS", 10, 4)

      item.update!(current_level: 9)
      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body.dig("report", "progresoPct")).to eq(90.0)
    end

    it "avisa que no hay report cuando la cuenta esta vacia" do
      get "/api/v1/accounts/#{cuenta.id}"

      expect(response.parsed_body["report"]).to include("hasReport" => false)
      expect(response.parsed_body["secciones"]).to eq({})
    end

    # Un umbral fijo no probaria nada: lo que delata un N+1 es que el numero de
    # consultas crezca con la cantidad de elementos. Aca tiene que quedar igual.
    it "no dispara una consulta por elemento al serializar los niveles" do
      def consultas_del_detalle
        consultas = 0
        contador = ->(*, payload) { consultas += 1 unless payload[:name] == "SCHEMA" }

        ActiveSupport::Notifications.subscribed(contador, "sql.active_record") do
          get "/api/v1/accounts/#{cuenta.id}"
        end

        consultas
      end

      2.times { agregar("NIVELES DEFENSAS", 3, 1, niveles: 3) }
      con_dos = consultas_del_detalle

      6.times { agregar("NIVELES DEFENSAS", 3, 1, niveles: 3) }

      expect(consultas_del_detalle).to eq(con_dos)
    end
  end
end
