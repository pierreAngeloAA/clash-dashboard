require "rails_helper"

RSpec.describe PoblarCuenta do
  describe "al crear una cuenta se le genera el inventario de su ayuntamiento" do
    it "no le crea lo que su ayuntamiento todavia no desbloqueo" do
      create(:game_item, :animal, desbloquea_en_th: 14)

      cuenta = create(:account, town_hall: 9)

      expect(cuenta.animales).to be_empty
    end

    it "le crea lo que su ayuntamiento ya desbloqueo" do
      create(:game_item, :animal, desbloquea_en_th: 14)

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.animales.count).to eq(1)
    end

    it "respeta la cantidad de unidades del ayuntamiento" do
      create(:game_item, :con_disponibilidad,
        categoria: "NIVELES DEFENSAS",
        nombre: "Canon",
        por_town_hall: { 9 => { cantidad: 6, max_level: 13 } })

      cuenta = create(:account, town_hall: 9)

      expect(cuenta.defensas.count).to eq(6)
      expect(cuenta.defensas.map(&:indice)).to contain_exactly(1, 2, 3, 4, 5, 6)
    end

    it "aplica el tope de nivel del ayuntamiento, no el del juego" do
      create(:game_item, :con_disponibilidad,
        nombre: "Canon",
        max_level: 21,
        por_town_hall: { 9 => { cantidad: 1, max_level: 13 } })

      cuenta = create(:account, town_hall: 9)

      expect(cuenta.defensas.first.max_level).to eq(13)
    end

    it "usa la fila del ayuntamiento mas alto que no supere al de la cuenta" do
      create(:game_item, :con_disponibilidad,
        nombre: "Canon",
        por_town_hall: {
          9 => { cantidad: 6, max_level: 13 },
          13 => { cantidad: 7, max_level: 19 }
        })

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.defensas.count).to eq(7)
      expect(cuenta.defensas.first.max_level).to eq(19)
    end

    it "sin datos por ayuntamiento asume una unidad al maximo del juego" do
      create(:game_item, nombre: "Canon", max_level: 21)

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.defensas.count).to eq(1)
      expect(cuenta.defensas.first.max_level).to eq(21)
    end

    it "arranca todo en nivel cero: disponible pero no liberado" do
      create(:game_item, :heroe, desbloquea_en_th: 7)

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.heroes.first.current_level).to eq(0)
      expect(cuenta.heroes.first).not_to be_completo
    end

    it "no genera nada si la cuenta no declara ayuntamiento" do
      create(:game_item, :heroe)

      cuenta = create(:account, town_hall: nil)

      expect(cuenta.account_items).to be_empty
    end
  end

  describe "cada elemento se crea con la clase que le corresponde" do
    it "instancia Heroe, Animal, Guardian y Defensa segun la seccion" do
      create(:game_item, :heroe, desbloquea_en_th: 1)
      create(:game_item, :animal, desbloquea_en_th: 1)
      create(:game_item, :guardian, desbloquea_en_th: 1)
      create(:game_item, nombre: "Canon")

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.heroes.first).to be_a(Heroe)
      expect(cuenta.animales.first).to be_a(Animal)
      expect(cuenta.guardianes.first).to be_a(Guardian)
      expect(cuenta.defensas.first).to be_a(Defensa)
    end

    it "las asociaciones de la cuenta no se mezclan entre si" do
      create(:game_item, :heroe, desbloquea_en_th: 1)
      create(:game_item, nombre: "Canon")

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.heroes.count).to eq(1)
      expect(cuenta.defensas.count).to eq(1)
      expect(cuenta.account_items.count).to eq(2)
    end
  end

  describe "idempotencia" do
    it "volver a correrlo no duplica nada" do
      create(:game_item, nombre: "Canon")
      cuenta = create(:account, town_hall: 15)

      expect { described_class.new(cuenta).call }.not_to change(AccountItem, :count)
    end

    it "no pisa el progreso ya cargado" do
      create(:game_item, nombre: "Canon")
      cuenta = create(:account, town_hall: 15)
      cuenta.defensas.first.update!(current_level: 8)

      described_class.new(cuenta.reload).call

      expect(cuenta.defensas.first.current_level).to eq(8)
    end

    it "sube el tope de lo que la cuenta ya tenia al subir de ayuntamiento" do
      create(:game_item, :con_disponibilidad,
        nombre: "Canon",
        max_level: 21,
        por_town_hall: { 9 => { cantidad: 1, max_level: 13 }, 15 => { cantidad: 1, max_level: 21 } })
      cuenta = create(:account, town_hall: 9)
      cuenta.defensas.first.update!(current_level: 13)

      cuenta.update!(town_hall: 15)
      cuenta.poblar_inventario

      expect(cuenta.defensas.first.reload.max_level).to eq(21)
    end

    it "no baja el tope al bajar de ayuntamiento" do
      create(:game_item, :con_disponibilidad,
        nombre: "Canon",
        max_level: 21,
        por_town_hall: { 9 => { cantidad: 1, max_level: 13 }, 15 => { cantidad: 1, max_level: 21 } })
      cuenta = create(:account, town_hall: 15)
      cuenta.defensas.first.update!(current_level: 20)

      cuenta.update!(town_hall: 9)
      cuenta.poblar_inventario

      expect(cuenta.defensas.first.reload.max_level).to eq(21)
    end

    it "agrega lo nuevo al subir de ayuntamiento" do
      create(:game_item, nombre: "Canon")
      cuenta = create(:account, town_hall: 9)
      create(:game_item, :animal, desbloquea_en_th: 14)

      cuenta.update!(town_hall: 15)

      expect { cuenta.poblar_inventario }.to change { cuenta.animales.count }.from(0).to(1)
    end
  end

  describe "aislamiento entre cuentas" do
    it "poblar una cuenta no toca el inventario de otra" do
      create(:game_item, nombre: "Canon")
      primera = create(:account, town_hall: 15)
      primera.defensas.first.update!(current_level: 5)

      segunda = create(:account, town_hall: 15)

      expect(segunda.defensas.first.current_level).to eq(0)
      expect(primera.reload.defensas.first.current_level).to eq(5)
    end
  end
end
