require "rails_helper"

RSpec.describe AccountItem do
  describe "la clase se deduce de la seccion del catalogo" do
    it "crear desde el catalogo instancia la subclase correcta" do
      catalogo = create(:game_item, :animal)
      cuenta = create(:account, town_hall: nil)

      item = AccountItem.create!(account: cuenta, game_item: catalogo, max_level: 10)

      expect(item.type).to eq("Animal")
      expect(AccountItem.find(item.id)).to be_a(Animal)
    end

    it "rechaza un Heroe que apunte a una defensa" do
      canon = create(:game_item, nombre: "Canon")
      item = Heroe.new(account: create(:account, town_hall: nil), game_item: canon, max_level: 10)

      expect(item).not_to be_valid
      expect(item.errors[:type].join).to include("NIVELES DEFENSAS")
    end
  end

  describe "validaciones" do
    it "rechaza un nivel actual mayor al maximo" do
      expect(build(:account_item, max_level: 5, current_level: 6)).not_to be_valid
    end

    it "acepta que el nivel actual iguale al maximo" do
      expect(build(:account_item, max_level: 5, current_level: 5)).to be_valid
    end

    it "rechaza un maximo que supere al del juego" do
      catalogo = create(:game_item, nombre: "Canon", max_level: 21)
      item = build(:account_item, game_item: catalogo, max_level: 30)

      expect(item).not_to be_valid
      expect(item.errors[:max_level].join).to include("21")
    end

    it "rechaza dos unidades con el mismo indice" do
      primera = create(:account_item, indice: 1)
      segunda = build(:account_item,
        account: primera.account, game_item: primera.game_item, indice: 1)

      expect(segunda).not_to be_valid
    end

    it "permite varias unidades con indices distintos" do
      primera = create(:account_item, indice: 1)
      segunda = build(:account_item,
        account: primera.account, game_item: primera.game_item, indice: 2)

      expect(segunda).to be_valid
    end

    it "rechaza una fuente desconocida" do
      expect(build(:account_item, fuente: "adivinada")).not_to be_valid
    end
  end

  describe "la base rechaza lo que el modelo deja pasar" do
    it "no admite un nivel fuera de rango aunque se saltee la validacion" do
      item = create(:account_item, max_level: 5, current_level: 1)

      expect { item.update_column(:current_level, 99) }
        .to raise_error(ActiveRecord::StatementInvalid, /account_items_current_level_dentro_de_rango/)
    end
  end

  describe "#estado_de" do
    let(:item) { build(:account_item, max_level: 10, current_level: 4) }

    it "marca como hecho lo alcanzado" do
      expect(item.estado_de(4)).to eq(:hecho)
    end

    it "marca como en curso el nivel siguiente" do
      expect(item.estado_de(5)).to eq(:en_curso)
    end

    it "marca como pendiente lo posterior" do
      expect(item.estado_de(6)).to eq(:pendiente)
    end

    it "un item en cero tiene su primer nivel en curso" do
      expect(build(:account_item, current_level: 0).estado_de(1)).to eq(:en_curso)
    end
  end

  describe "sincronizacion con la API" do
    it "actualiza el nivel y deja constancia de la fuente" do
      item = create(:account_item, game_item: create(:game_item, :tropa_clara), max_level: 12)

      item.aplicar_desde_api!(7)

      expect(item.reload).to have_attributes(current_level: 7, fuente: "api")
      expect(item.sincronizado_en).to be_present
    end

    it "no pisa lo que el superadmin bloqueo" do
      item = create(:account_item, :bloqueado,
        game_item: create(:game_item, :tropa_clara), max_level: 12, current_level: 3)

      expect(item.aplicar_desde_api!(9)).to be(false)
      expect(item.reload.current_level).to eq(3)
    end

    it "no toca las defensas: la API no las conoce" do
      defensa = create(:defensa, current_level: 5)

      expect(defensa.sincronizable_desde_api?).to be(false)
      expect(defensa.aplicar_desde_api!(9)).to be(false)
    end

    it "no toca lo que no tiene nombre del lado de la API" do
      sin_nombre = create(:account_item,
        game_item: create(:game_item, :tropa_clara, nombre_api: nil))

      expect(sin_nombre.sincronizable_desde_api?).to be(false)
    end
  end

  describe "#niveles" do
    it "combina las etiquetas del catalogo con el estado de la cuenta" do
      catalogo = create(:game_item, :con_niveles, nombre: "Canon",
        max_level: 21, cantidad_de_niveles: 3)
      item = create(:account_item, game_item: catalogo, max_level: 3, current_level: 1)

      expect(item.niveles.map { |n| n[:estado] }).to eq([ :hecho, :en_curso, :pendiente ])
    end
  end
end
