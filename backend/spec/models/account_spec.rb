require "rails_helper"

RSpec.describe Account do
  describe "validaciones" do
    it "acepta una cuenta valida" do
      expect(build(:account)).to be_valid
    end

    it "exige nombre" do
      expect(build(:account, nombre: nil)).not_to be_valid
    end

    it "rechaza nombres repetidos sin importar mayusculas" do
      create(:account, nombre: "Pierre")

      expect(build(:account, nombre: "pierre")).not_to be_valid
    end

    it "rechaza un ayuntamiento cero o negativo" do
      expect(build(:account, town_hall: 0)).not_to be_valid
    end

    it "rechaza un tag que no parece de Clash of Clans" do
      expect(build(:account, tag_coc: "#ZZZZ")).not_to be_valid
    end
  end

  describe "normalizacion del tag" do
    it "agrega el # y pasa a mayusculas" do
      cuenta = create(:account, tag_coc: " lj8v90g0 ")

      expect(cuenta.tag_coc).to eq("#LJ8V90G0")
    end

    it "no duplica el # cuando ya viene" do
      expect(create(:account, tag_coc: "#LJ8V90G0").tag_coc).to eq("#LJ8V90G0")
    end

    it "deja en nil las cuentas sin tag" do
      expect(create(:account, tag_coc: nil).tag_coc).to be_nil
    end
  end

  describe ".separar_town_hall" do
    it "separa el nombre del nivel de ayuntamiento" do
      expect(described_class.separar_town_hall("Pierre TH15")).to eq([ "Pierre", 15 ])
    end

    it "tolera espacios y minusculas" do
      expect(described_class.separar_town_hall("Fata  th 9")).to eq([ "Fata", 9 ])
    end

    it "deja el ayuntamiento en nil cuando el nombre no lo trae" do
      expect(described_class.separar_town_hall("Resumen")).to eq([ "Resumen", nil ])
    end

    it "no confunde un TH que forma parte del nombre" do
      expect(described_class.separar_town_hall("THOR")).to eq([ "THOR", nil ])
    end
  end

  describe "#secciones" do
    it "agrupa el inventario en el orden en que lo muestra el Sheet" do
      create(:game_item, :heroe, desbloquea_en_th: 1)
      create(:game_item, :tropa_clara, desbloquea_en_th: 1)
      create(:game_item, nombre: "Canon")

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.secciones.keys)
        .to eq([ "NIVELES DEFENSAS", "TROPAS CLARAS", "REY BARBARO" ])
    end

    it "omite las secciones sin elementos" do
      create(:game_item, nombre: "Canon")

      cuenta = create(:account, town_hall: 15)

      expect(cuenta.secciones.keys).to eq([ "NIVELES DEFENSAS" ])
    end
  end

  describe "borrado en cascada" do
    it "se lleva todo el inventario de la cuenta" do
      create(:game_item, nombre: "Canon")
      cuenta = create(:account, town_hall: 15)

      expect { cuenta.destroy }.to change(AccountItem, :count).by(-1)
    end
  end

  describe "scopes" do
    it "ordena por orden manual y desempata por nombre" do
      be = create(:account, nombre: "B", orden: 1)
      a2 = create(:account, nombre: "A2", orden: 1)
      zeta = create(:account, nombre: "Zeta", orden: 0)

      expect(described_class.ordenadas).to eq([ zeta, a2, be ])
    end

    it "sincronizables son las que tienen tag" do
      con_tag = create(:account, :sincronizable)
      create(:account, tag_coc: nil)

      expect(described_class.sincronizables).to contain_exactly(con_tag)
    end
  end
end
