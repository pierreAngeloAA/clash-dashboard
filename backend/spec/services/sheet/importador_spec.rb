require "rails_helper"

RSpec.describe Sheet::Importador do
  # Un cliente que devuelve HTML de fixtures en vez de pegarle a Google: los
  # tests no dependen de la red ni de que el Sheet siga publicado.
  class ClienteFalso
    attr_reader :descargas

    def initialize(pestanias)
      @pestanias = pestanias
      @descargas = 0
    end

    def indice
      @pestanias
        .map { |gid, datos| %(items.push({name: "#{datos[:nombre]}", gid: "#{gid}"});) }
        .join("\n")
    end

    def pestania(gid)
      @descargas += 1
      Rails.root.join("spec/fixtures/sheet", @pestanias.fetch(gid)[:archivo]).read
    end
  end

  let(:cliente) do
    ClienteFalso.new(
      "111" => { nombre: "PIERRE TH18", archivo: "pestania.html" },
      "222" => { nombre: "ALDO TH9", archivo: "pestania_chica.html" }
    )
  end

  def importar = described_class.new(cliente: cliente).call

  describe "cuentas" do
    it "crea una cuenta por pestaña" do
      expect { importar }.to change(Account, :count).by(2)
    end

    # La pestaña se llama "PIERRE TH18": en la base el nombre y el ayuntamiento
    # son dos datos distintos.
    it "separa el nombre del ayuntamiento" do
      importar

      expect(Account.find_by(gid_origen: "111"))
        .to have_attributes(nombre: "PIERRE", town_hall: 18)
    end

    it "recuerda de que pestaña vino cada cuenta" do
      importar

      expect(Account.pluck(:gid_origen)).to contain_exactly("111", "222")
    end

    it "reconoce la cuenta por su gid aunque le hayan cambiado el nombre" do
      importar
      Account.find_by(gid_origen: "111").update!(nombre: "VIEJO", town_hall: 9)

      expect { importar }.not_to change(Account, :count)
      expect(Account.find_by(gid_origen: "111").nombre).to eq("PIERRE")
    end
  end

  describe "catalogo" do
    it "crea un elemento por nombre y categoria, no uno por copia" do
      importar

      expect(GameItem.where(categoria: "NIVELES DEFENSAS").pluck(:nombre))
        .to contain_exactly("Cañón", "Mortero", "Tesla")
    end

    # Una cuenta chica solo muestra hasta donde llega su ayuntamiento: el tope
    # del juego es el mayor visto entre todas las cuentas.
    it "se queda con el nivel maximo visto entre todas las cuentas" do
      importar

      expect(GameItem.find_by(nombre: "Cañón").max_level).to eq(3)
    end

    it "guarda un nivel por posicion con su ayuntamiento" do
      importar

      niveles = GameItem.find_by(nombre: "Cañón").game_item_levels.order(:posicion)
      expect(niveles.pluck(:posicion, :etiqueta))
        .to eq([ [ 1, "TH1" ], [ 2, "TH3" ], [ 3, "TH5" ] ])
    end

    # La etiqueta del primer nivel dice en que ayuntamiento aparece el elemento.
    it "deduce en que ayuntamiento se desbloquea cada elemento" do
      importar

      expect(GameItem.find_by(nombre: "Mortero").desbloquea_en_th).to eq(3)
    end

    it "crea una categoria propia por heroe" do
      importar

      expect(GameItem.find_by(categoria: "REY BARBARO")).to be_present
    end

    it "crea los equipos de guardianes" do
      importar

      expect(GameItem.where(categoria: "GUARDIANES").pluck(:nombre)).to eq([ "TIRADORA" ])
    end
  end

  describe "progreso" do
    it "carga una fila por copia, con su indice" do
      importar
      canon = GameItem.find_by(nombre: "Cañón")
      cuenta = Account.find_by(gid_origen: "111")

      expect(cuenta.account_items.where(game_item: canon).pluck(:indice, :current_level))
        .to contain_exactly([ 1, 2 ], [ 2, 1 ])
    end

    it "marca el progreso como venido del Sheet" do
      importar
      cuenta = Account.find_by(gid_origen: "111")

      expect(cuenta.account_items.where(fuente: "sheet")).to be_any
    end

    it "usa el tope de esa cuenta, no el del juego" do
      importar
      canon = GameItem.find_by(nombre: "Cañón")
      chica = Account.find_by(gid_origen: "222")

      expect(chica.account_items.find_by(game_item: canon).max_level).to eq(2)
    end

    it "instancia cada elemento con la clase de su seccion" do
      importar
      cuenta = Account.find_by(gid_origen: "111")

      expect(cuenta.heroes.map(&:nombre)).to include("REY BARBARO")
      expect(cuenta.defensas.map(&:nombre)).to include("Cañón")
    end
  end

  describe "volver a correrlo" do
    it "no duplica cuentas, catalogo ni progreso" do
      importar

      expect { importar }
        .not_to change { [ Account.count, GameItem.count, AccountItem.count ] }
    end

    # El Sheet siembra la base una vez; despues la API de Clash y las
    # correcciones a mano estan mas al dia que la planilla.
    it "no pisa lo que ya se sincronizo con la API" do
      importar
      canon = GameItem.find_by(nombre: "Cañón")
      item = Account.find_by(gid_origen: "111").account_items.find_by(game_item: canon, indice: 1)
      item.update!(current_level: 3, fuente: "api")

      importar

      expect(item.reload).to have_attributes(current_level: 3, fuente: "api")
    end

    it "no pisa lo que se corrigio a mano y quedo bloqueado" do
      importar
      canon = GameItem.find_by(nombre: "Cañón")
      item = Account.find_by(gid_origen: "111").account_items.find_by(game_item: canon, indice: 1)
      item.update!(current_level: 3, bloqueado: true)

      importar

      expect(item.reload.current_level).to eq(3)
    end

    it "actualiza el progreso que cambio en el Sheet" do
      importar
      canon = GameItem.find_by(nombre: "Cañón")
      cuenta = Account.find_by(gid_origen: "111")
      cuenta.account_items.find_by(game_item: canon, indice: 1).update!(current_level: 0)

      importar

      expect(cuenta.account_items.find_by(game_item: canon, indice: 1).current_level).to eq(2)
    end
  end

  it "informa lo que importo" do
    resultado = importar

    expect(resultado.cuentas).to eq(2)
    expect(resultado.elementos_del_catalogo).to eq(GameItem.count)
    expect(resultado.progreso).to be_positive
  end

  it "no deja nada a medias si una pestaña falla" do
    allow(cliente).to receive(:pestania).and_raise(Sheet::Cliente::Error, "cayo la red")

    expect { importar }.to raise_error(Sheet::Cliente::Error)
    expect(Account.count).to eq(0)
  end
end
