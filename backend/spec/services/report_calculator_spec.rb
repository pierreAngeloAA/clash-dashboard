require "rails_helper"

RSpec.describe ReportCalculator do
  let(:cuenta) { create(:account, town_hall: nil) }

  def item(categoria, max_level, current_level, nombre: nil)
    catalogo = create(:game_item,
      categoria: categoria,
      nombre: nombre || "#{categoria} #{SecureRandom.hex(3)}",
      max_level: max_level)

    AccountItem.create!(
      account: cuenta,
      game_item: catalogo,
      max_level: max_level,
      current_level: current_level
    )
  end

  def report = described_class.new(cuenta).call

  def categoria(label) = report[:categories].find { |c| c[:label] == label }

  describe "categorias" do
    it "suma los niveles de todos los elementos de una seccion" do
      item("NIVELES DEFENSAS", 10, 4)
      item("NIVELES DEFENSAS", 10, 6)

      expect(categoria("NIVELES DEFENSAS")).to include(total: 20, faltante: 10, pctDone: 50.0)
    end

    it "el porcentaje faltante es el complemento del hecho" do
      item("NIVELES DEFENSAS", 8, 2)

      expect(categoria("NIVELES DEFENSAS")).to include(pctDone: 25.0, pctMissing: 75.0)
    end

    it "colapsa las seis secciones de heroe en una sola" do
      item("REY BARBARO", 10, 8)
      item("REINA ARQUERA", 10, 7)

      expect(categoria("HEROES")).to include(total: 20, faltante: 5, pctDone: 75.0)
      expect(categoria("REY BARBARO")).to be_nil
    end

    it "no inventa la seccion HEROES cuando no hay heroes" do
      item("NIVELES DEFENSAS", 10, 5)

      expect(categoria("HEROES")).to be_nil
    end
  end

  describe "totales por grupo" do
    it "agrupa heroes con sus poderes y sus animales" do
      item("REY BARBARO", 10, 10)
      item("GUARDIANES", 10, 4)
      item("ANIMALES", 10, 6)

      expect(report[:totals][:heroes]).to eq(total: 30, faltante: 10)
    end

    it "agrupa como investigacion lo del laboratorio" do
      item("TROPAS CLARAS", 10, 5)
      item("HECHIZOS OSCUROS", 10, 3)
      item("MAQUINAS DE ASEDIO", 10, 2)

      expect(report[:totals][:investigacion]).to eq(total: 30, faltante: 20)
    end

    it "cuenta las trampas junto a las defensas" do
      item("NIVELES DEFENSAS", 10, 6)
      item("NIVELES TRAMPAS", 10, 4)

      expect(report[:totals][:defensas]).to eq(total: 20, faltante: 10)
    end

    it "devuelve un grupo en cero cuando la cuenta no tiene esos elementos" do
      item("NIVELES DEFENSAS", 10, 5)

      expect(report[:totals][:heroes]).to eq(total: 0, faltante: 0)
    end
  end

  describe "porcentajes globales" do
    it "calcula el progreso sobre el total de niveles" do
      item("NIVELES DEFENSAS", 10, 3)
      item("TROPAS CLARAS", 10, 7)

      expect(report[:progresoPct]).to eq(50.0)
    end

    it "redondea a dos decimales" do
      item("NIVELES DEFENSAS", 3, 1)

      expect(report[:progresoPct]).to eq(33.33)
      expect(report[:faltantePct]).to eq(66.67)
    end

    it "llega a 100 con todo completo" do
      item("NIVELES DEFENSAS", 10, 10)

      expect(report[:progresoPct]).to eq(100.0)
    end
  end

  describe "cuenta vacia" do
    it "no divide por cero" do
      expect(report[:progresoPct]).to eq(0.0)
      expect(report[:hasReport]).to be(false)
    end
  end

  describe "el report sigue a los datos" do
    it "se recalcula al subir un nivel, sin quedar cacheado" do
      defensa = item("NIVELES DEFENSAS", 10, 5)
      expect(report[:progresoPct]).to eq(50.0)

      defensa.update!(current_level: 10)

      expect(described_class.new(cuenta.reload).call[:progresoPct]).to eq(100.0)
    end
  end
end
