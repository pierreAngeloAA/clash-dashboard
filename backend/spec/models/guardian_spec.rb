require "rails_helper"

# Los poderes de heroe (hero equipment). Se llaman Guardian porque asi los
# titula el Google Sheet, del que sale el catalogo.
RSpec.describe Guardian do
  let(:cuenta) { create(:account, town_hall: nil) }

  def heroe_de(cuenta, categoria: "REY BARBARO")
    create(:heroe, account: cuenta, game_item: create(:game_item, :heroe, categoria: categoria))
  end

  describe "pertenencia a un heroe" do
    it "puede existir sin heroe mientras el catalogo no diga de cual es" do
      poder = build(:guardian, account: cuenta)

      expect(poder).to be_valid
      expect(poder.heroe).to be_nil
    end

    # Es lo que pidio Pierre: los poderes son de los heroes, no de la cuenta.
    it "cuelga del heroe que el catalogo declara" do
      rey = heroe_de(cuenta)
      poder = create(:guardian, account: cuenta, game_item: create(:game_item, :poder_del_rey))

      expect(poder.heroe).to eq(rey)
      expect(rey.poderes).to include(poder)
    end

    it "queda sin heroe si la cuenta todavia no tiene ese heroe" do
      poder = create(:guardian, account: cuenta, game_item: create(:game_item, :poder_del_rey))

      expect(poder.heroe).to be_nil
    end

    it "no lo cuelga de un heroe de otro heroe distinto al declarado" do
      heroe_de(cuenta, categoria: "REINA ARQUERA")
      poder = create(:guardian, account: cuenta, game_item: create(:game_item, :poder_del_rey))

      expect(poder.heroe).to be_nil
    end

    # Sin esto la cuenta mostraria un poder colgado del heroe de otro jugador.
    it "rechaza un heroe de otra cuenta" do
      ajena = create(:account, town_hall: nil)
      poder = build(:guardian, account: cuenta, heroe: heroe_de(ajena))

      expect(poder).not_to be_valid
      expect(poder.errors[:heroe]).to include("tiene que ser un heroe de la misma cuenta")
    end

    it "se borra junto con su heroe" do
      rey = heroe_de(cuenta)
      create(:guardian, account: cuenta, game_item: create(:game_item, :poder_del_rey))

      expect { rey.destroy! }.to change(described_class, :count).by(-1)
    end
  end

  describe "Account#vincular_poderes!" do
    # El catalogo puede declarar de que heroe es un poder despues de haber
    # importado las cuentas: los poderes ya creados no se enteran solos.
    it "cuelga los poderes que quedaron sueltos" do
      poder = create(:guardian, account: cuenta, game_item: create(:game_item, :poder_del_rey))
      rey = heroe_de(cuenta)

      expect(cuenta.vincular_poderes!).to eq(1)
      expect(poder.reload.heroe).to eq(rey)
    end

    it "no toca los que ya estaban colgados" do
      heroe_de(cuenta)
      create(:guardian, account: cuenta, game_item: create(:game_item, :poder_del_rey))

      expect(cuenta.vincular_poderes!).to eq(0)
    end

    it "deja sueltos los poderes que el catalogo no atribuye a nadie" do
      heroe_de(cuenta)
      poder = create(:guardian, account: cuenta)

      cuenta.vincular_poderes!

      expect(poder.reload.heroe).to be_nil
    end
  end

  describe "el catalogo" do
    it "solo acepta como dueño a un heroe" do
      expect(build(:game_item, :guardian, heroe_categoria: "ANIMALES")).not_to be_valid
    end

    it "no deja atribuirle un heroe a algo que no es un poder" do
      elemento = build(:game_item, :tropa_clara, heroe_categoria: "REY BARBARO")

      expect(elemento).not_to be_valid
      expect(elemento.errors[:heroe_categoria]).to include("solo se declara en los poderes de heroe")
    end
  end
end
