require "rails_helper"

RSpec.describe Clash::SincronizarCuenta do
  let(:cuenta) { create(:account, :sincronizable, town_hall: nil) }

  # Un cliente de mentira: lo que se prueba aca es que el progreso se aplique
  # bien, no como se habla con la API, que ya tiene su propio spec.
  def cliente_que_responde(jugador)
    instance_double(Clash::Cliente, jugador: jugador)
  end

  def con_nivel(categoria, nombre_api, current_level, max_level, **atributos)
    catalogo = create(:game_item,
      categoria: categoria,
      nombre: nombre_api,
      nombre_api: nombre_api,
      max_level: [ max_level, 100 ].max)

    AccountItem.create!(
      account: cuenta,
      game_item: catalogo,
      current_level: current_level,
      max_level: max_level,
      fuente: "sheet",
      **atributos
    )
  end

  def jugador_con(*entradas, seccion: "troops")
    { seccion => entradas.map { |e| { "village" => "home" }.merge(e) } }
  end

  describe "#call" do
    it "sube el nivel que trae la API" do
      item = con_nivel("TROPAS CLARAS", "Barbarian", 5, 12)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Barbarian", "level" => 11, "maxLevel" => 12 })
      )

      described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.current_level).to eq(11)
    end

    it "marca de donde vino el dato y cuando" do
      item = con_nivel("TROPAS CLARAS", "Barbarian", 5, 12)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Barbarian", "level" => 11, "maxLevel" => 12 })
      )

      described_class.new(cuenta, cliente: cliente).call

      expect(item.reload).to have_attributes(fuente: "api")
      expect(item.sincronizado_en).to be_present
    end

    # El juego sube el tope de un elemento cuando saca un nivel nuevo. La API lo
    # sabe antes que el catalogo, que salio del Sheet.
    it "actualiza tambien el tope que informa la API" do
      item = con_nivel("TROPAS CLARAS", "Barbarian", 5, 11)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Barbarian", "level" => 11, "maxLevel" => 12 })
      )

      described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.max_level).to eq(12)
    end

    it "no cuenta como actualizado lo que ya estaba igual" do
      con_nivel("TROPAS CLARAS", "Barbarian", 11, 12)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Barbarian", "level" => 11, "maxLevel" => 12 })
      )

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(informe.actualizados).to be_empty
      expect(informe.sin_cambios.size).to eq(1)
    end

    it "cruza los nombres sin que importen las mayusculas" do
      item = con_nivel("TROPAS CLARAS", "barbarian", 5, 12)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Barbarian", "level" => 11, "maxLevel" => 12 })
      )

      described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.current_level).to eq(11)
    end
  end

  describe "lo que no debe tocar" do
    it "respeta el candado" do
      item = con_nivel("TROPAS CLARAS", "Barbarian", 5, 12, bloqueado: true)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Barbarian", "level" => 11, "maxLevel" => 12 })
      )

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.current_level).to eq(5)
      expect(informe.protegidos.map(&:id)).to eq([ item.id ])
    end

    # La aldea del constructor repite nombres con la principal. Sin filtrar por
    # aldea, un barbaro del constructor pisaria el de la aldea principal.
    it "ignora lo de la aldea del constructor" do
      item = con_nivel("TROPAS CLARAS", "Barbarian", 5, 12)
      cliente = cliente_que_responde(
        "troops" => [
          { "name" => "Barbarian", "level" => 18, "maxLevel" => 20,
            "village" => "builderBase" }
        ]
      )

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.current_level).to eq(5)
      expect(informe.no_encontrados.map(&:id)).to eq([ item.id ])
    end

    it "no toca las defensas, que la API no expone" do
      item = con_nivel("NIVELES DEFENSAS", "Cannon", 5, 21)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Cannon", "level" => 21, "maxLevel" => 21 })
      )

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.current_level).to eq(5)
      expect(informe.sin_mapear.map(&:id)).to eq([ item.id ])
    end

    it "deja sin tocar lo que el catalogo no tiene mapeado a la API" do
      catalogo = create(:game_item, categoria: "TROPAS CLARAS", nombre: "Lancero",
        nombre_api: nil, max_level: 10)
      item = AccountItem.create!(account: cuenta, game_item: catalogo,
        current_level: 3, max_level: 10, fuente: "sheet")
      cliente = cliente_que_responde(jugador_con)

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(item.reload.current_level).to eq(3)
      expect(informe.sin_mapear.map(&:id)).to eq([ item.id ])
    end
  end

  describe "cuando algo no cuadra" do
    it "exige que la cuenta tenga tag" do
      sin_tag = create(:account, town_hall: nil)

      expect {
        described_class.new(sin_tag, cliente: cliente_que_responde({})).call
      }.to raise_error(described_class::SinTag, /no tiene tag/)
    end

    # El catalogo salio del Sheet y puede haber quedado atras. Que un elemento
    # no entre no puede frenar la sincronizacion de los otros setenta.
    it "sigue con el resto si el catalogo no admite el tope que trae la API" do
      viejo = create(:game_item, categoria: "TROPAS CLARAS", nombre: "Yeti",
        nombre_api: "Yeti", max_level: 5)
      rechazado = AccountItem.create!(account: cuenta, game_item: viejo,
        current_level: 1, max_level: 5, fuente: "sheet")
      otro = con_nivel("TROPAS CLARAS", "Barbarian", 5, 12)

      cliente = cliente_que_responde(jugador_con(
        { "name" => "Yeti", "level" => 9, "maxLevel" => 9 },
        { "name" => "Barbarian", "level" => 11, "maxLevel" => 12 }
      ))

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(rechazado.reload.current_level).to eq(1)
      expect(otro.reload.current_level).to eq(11)
      expect(informe.rechazados.first[:motivo]).to match(/maximo del juego/i)
    end

    # Contenido nuevo del juego que el catalogo todavia no conoce. Es la señal de
    # que hay que actualizar el catalogo, y si no se informa nadie se entera.
    it "avisa de lo que la API trajo y el catalogo no reconoce" do
      con_nivel("TROPAS CLARAS", "Barbarian", 5, 12)
      cliente = cliente_que_responde(jugador_con(
        { "name" => "Barbarian", "level" => 11, "maxLevel" => 12 },
        { "name" => "Tropa Nueva", "level" => 1, "maxLevel" => 3 }
      ))

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(informe.desconocidos).to eq([ "tropa nueva" ])
    end
  end

  describe "el informe" do
    it "cuenta cada caso por separado" do
      con_nivel("TROPAS CLARAS", "Barbarian", 5, 12)
      con_nivel("TROPAS CLARAS", "Archer", 11, 12)
      con_nivel("TROPAS CLARAS", "Giant", 5, 12, bloqueado: true)
      con_nivel("NIVELES DEFENSAS", "Cannon", 5, 21)

      cliente = cliente_que_responde(jugador_con(
        { "name" => "Barbarian", "level" => 11, "maxLevel" => 12 },
        { "name" => "Archer", "level" => 11, "maxLevel" => 12 },
        { "name" => "Giant", "level" => 12, "maxLevel" => 12 }
      ))

      expect(described_class.new(cuenta, cliente: cliente).call.resumen).to include(
        actualizados: 1, sinCambios: 1, protegidos: 1, sinMapear: 1
      )
    end

    it "busca en todas las secciones que devuelve la API" do
      rey = con_nivel("REY BARBARO", "Barbarian King", 50, 100)
      rayo = con_nivel("HECHIZOS CLAROS", "Lightning Spell", 5, 11)
      poder = con_nivel("GUARDIANES", "Barbarian Puppet", 10, 27)

      cliente = cliente_que_responde(
        "heroes" => [ { "name" => "Barbarian King", "level" => 95, "maxLevel" => 100,
                        "village" => "home" } ],
        "spells" => [ { "name" => "Lightning Spell", "level" => 11, "maxLevel" => 11,
                        "village" => "home" } ],
        "heroEquipment" => [ { "name" => "Barbarian Puppet", "level" => 18,
                               "maxLevel" => 27, "village" => "home" } ]
      )

      described_class.new(cuenta, cliente: cliente).call

      expect(rey.reload.current_level).to eq(95)
      expect(rayo.reload.current_level).to eq(11)
      expect(poder.reload.current_level).to eq(18)
    end
  end

  # El Sheet dejo congelado el ayuntamiento del momento de la importacion, y ese
  # numero decide que elementos existen en el inventario.
  describe "el ayuntamiento" do
    it "lo pone al dia con lo que dice la API" do
      cuenta.update!(town_hall: 13)
      cliente = cliente_que_responde(jugador_con.merge("townHallLevel" => 15))

      described_class.new(cuenta, cliente: cliente).call

      expect(cuenta.reload.town_hall).to eq(15)
    end

    it "avisa en el informe que cambio" do
      cuenta.update!(town_hall: 13)
      cliente = cliente_que_responde(jugador_con.merge("townHallLevel" => 15))

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(informe.ayuntamiento).to eq({ antes: 13, ahora: 15 })
    end

    it "no informa nada cuando el ayuntamiento no cambio" do
      cuenta.update!(town_hall: 15)
      cliente = cliente_que_responde(jugador_con.merge("townHallLevel" => 15))

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(informe.ayuntamiento).to be_nil
      expect(informe.resumen[:elementosNuevos]).to eq(0)
    end

    it "guarda tambien el taller del constructor" do
      cuenta.update!(builder_hall: 8)
      cliente = cliente_que_responde(
        jugador_con.merge("townHallLevel" => 15, "builderHallLevel" => 10)
      )

      described_class.new(cuenta, cliente: cliente).call

      expect(cuenta.reload.builder_hall).to eq(10)
    end

    it "no toca el ayuntamiento si la API no lo dice" do
      cuenta.update!(town_hall: 13)
      cliente = cliente_que_responde(jugador_con)

      described_class.new(cuenta, cliente: cliente).call

      expect(cuenta.reload.town_hall).to eq(13)
    end

    it "repuebla el inventario con lo que el ayuntamiento nuevo habilita" do
      cuenta.update!(town_hall: 9)
      create(:game_item, categoria: "TROPAS CLARAS", nombre: "Yeti",
        nombre_api: "Yeti", max_level: 5, desbloquea_en_th: 12)
      cliente = cliente_que_responde(jugador_con.merge("townHallLevel" => 14))

      informe = described_class.new(cuenta, cliente: cliente).call

      expect(informe.resumen[:elementosNuevos]).to be_positive
      expect(cuenta.account_items.joins(:game_item).where(game_items: { nombre: "Yeti" }))
        .to be_present
    end

    # El orden importa: si primero se aplicaran los niveles y despues se
    # repoblara, los elementos recien habilitados quedarian en cero hasta la
    # sincronizacion siguiente.
    it "le da su nivel real a los elementos que acaba de habilitar" do
      cuenta.update!(town_hall: 9)
      create(:game_item, categoria: "TROPAS CLARAS", nombre: "Yeti",
        nombre_api: "Yeti", max_level: 5, desbloquea_en_th: 12)
      cliente = cliente_que_responde(
        jugador_con({ "name" => "Yeti", "level" => 4, "maxLevel" => 5 })
          .merge("townHallLevel" => 14)
      )

      described_class.new(cuenta, cliente: cliente).call

      yeti = cuenta.account_items.joins(:game_item).find_by(game_items: { nombre: "Yeti" })
      expect(yeti.current_level).to eq(4)
      expect(yeti.fuente).to eq("api")
    end
  end
end
