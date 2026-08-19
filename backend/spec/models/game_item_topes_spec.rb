require "rails_helper"

RSpec.describe GameItem, "topes por ayuntamiento" do
  # El Sheet cargo en cada nivel la etiqueta del TH en que se desbloquea. De ahi
  # sale hasta donde puede subir un elemento en cada ayuntamiento.
  def con_etiquetas(*etiquetas)
    catalogo = create(:game_item, categoria: "NIVELES DEFENSAS", nombre: "Cañon",
      max_level: etiquetas.size)
    etiquetas.each_with_index do |etiqueta, i|
      create(:game_item_level, game_item: catalogo, posicion: i + 1, etiqueta: etiqueta)
    end

    catalogo.reload
  end

  it "da el ultimo nivel que ese ayuntamiento habilita" do
    canon = con_etiquetas("TH1", "TH2", "TH3", "TH4", "TH5")

    expect(canon.max_level_para(3)).to eq(3)
  end

  it "cuenta todos los niveles del mismo ayuntamiento" do
    canon = con_etiquetas("TH1", "TH1", "TH2", "TH2", "TH3")

    expect(canon.max_level_para(2)).to eq(4)
  end

  it "no habilita nada por debajo del primer ayuntamiento del elemento" do
    canon = con_etiquetas("TH5", "TH6")

    expect(canon.max_level_para(3)).to be_nil
  end

  # A 32 elementos del catalogo les faltan las etiquetas de sus niveles altos.
  # En el ayuntamiento mas alto la respuesta se conoce igual: es el maximo.
  it "da el maximo del juego en el ayuntamiento mas alto, aunque falten etiquetas" do
    canon = con_etiquetas("TH1", "TH2", nil, nil)

    expect(canon.max_level_para(2)).to eq(4)
  end

  it "tambien lo da por encima del ayuntamiento mas alto conocido" do
    canon = con_etiquetas("TH1", "TH2")

    expect(canon.max_level_para(99)).to eq(2)
  end

  # Devolver el maximo del juego disfrazaria de respuesta lo que es no saber, y
  # cada llamador tiene un respaldo mejor que ese.
  it "devuelve nil cuando el catalogo no tiene ninguna etiqueta" do
    sin_etiquetas = create(:game_item, categoria: "NIVELES DEFENSAS", max_level: 10)

    expect(sin_etiquetas.max_level_para(13)).to be_nil
  end

  describe ".town_hall_maximo" do
    it "es el ayuntamiento mas alto que menciona alguna etiqueta" do
      con_etiquetas("TH1", "TH7", "TH3")

      expect(described_class.town_hall_maximo).to eq(7)
    end

    it "es cero cuando no hay etiquetas" do
      create(:game_item, categoria: "NIVELES DEFENSAS", max_level: 5)

      expect(described_class.town_hall_maximo).to eq(0)
    end
  end
end
