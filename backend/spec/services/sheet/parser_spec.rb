require "rails_helper"

RSpec.describe Sheet::Parser do
  let(:html) { Rails.root.join("spec/fixtures/sheet/pestania.html").read }
  let(:secciones) { described_class.new(html).call }

  def elemento(categoria, nombre, indice: 1)
    secciones[categoria].find { |e| e[:nombre] == nombre && e[:indice] == indice }
  end

  describe ".pestanias" do
    let(:indice) { <<~HTML }
      <script>
        items.push({name: "PIERRE TH18", gid: "47515597", index: 0});
        items.push({name: "ALDO TH17", gid: "662007433", index: 1});
        items.push({name: "PIERRE TH18", gid: "47515597", index: 0});
      </script>
    HTML

    it "devuelve el nombre y el gid de cada pestaña" do
      expect(described_class.pestanias(indice)).to eq([
        { nombre: "PIERRE TH18", gid: "47515597" },
        { nombre: "ALDO TH17", gid: "662007433" }
      ])
    end

    it "no repite una pestaña que el indice publica dos veces" do
      expect(described_class.pestanias(indice).size).to eq(2)
    end

    it "devuelve vacio si el HTML no es el del Sheet" do
      expect(described_class.pestanias("<html><body>nada</body></html>")).to eq([])
    end
  end

  describe "secciones con una fila por elemento" do
    it "reconoce cada copia por su indice" do
      expect(secciones["NIVELES DEFENSAS"].map { |e| [ e[:nombre], e[:indice] ] })
        .to include([ "Cañón", 1 ], [ "Cañón", 2 ], [ "Mortero", 1 ])
    end

    # El color es el dato: verde es un nivel ya subido.
    it "toma como nivel actual el ultimo pintado de verde" do
      expect(elemento("NIVELES DEFENSAS", "Cañón")).to include(current_level: 2, max_level: 3)
    end

    it "distingue dos copias del mismo elemento con progreso distinto" do
      expect(elemento("NIVELES DEFENSAS", "Cañón", indice: 2))
        .to include(current_level: 1, max_level: 3)
    end

    it "no cuenta como completado el nivel en curso, que va en amarillo" do
      expect(elemento("NIVELES DEFENSAS", "Cañón")[:current_level]).to eq(2)
    end

    it "guarda el ayuntamiento de cada nivel" do
      expect(elemento("NIVELES DEFENSAS", "Cañón")[:etiquetas]).to eq(%w[TH1 TH3 TH5])
    end

    it "reconoce el elemento completo" do
      expect(elemento("NIVELES DEFENSAS", "Mortero")).to include(current_level: 3, max_level: 3)
    end

    # Una celda vacia es un nivel que ese elemento no tiene, no un nivel pendiente.
    it "corta el maximo donde termina la fila del elemento" do
      expect(elemento("NIVELES DEFENSAS", "Tesla")).to include(current_level: 1, max_level: 2)
    end

    it "lee los acentos del Sheet sin romperlos" do
      expect(secciones["NIVELES DEFENSAS"].map { |e| e[:nombre] }).to include("Cañón")
    end

    # En NIVELES DEFENSAS el numero de la izquierda son las copias, pero en
    # TROPAS CLARAS numera la lista: la unica arquera figura como la fila 2.
    it "numera las copias por nombre y no por la fila del Sheet" do
      expect(secciones["TROPAS CLARAS"].map { |e| [ e[:nombre], e[:indice] ] })
        .to eq([ [ "Barbaro", 1 ], [ "Arquera", 1 ] ])
    end

    it "numera de a una las copias del mismo elemento" do
      canones = secciones["NIVELES DEFENSAS"].select { |e| e[:nombre] == "Cañón" }

      expect(canones.map { |e| e[:indice] }).to eq([ 1, 2 ])
    end
  end

  describe "secciones de heroes" do
    it "arma una categoria por heroe" do
      expect(secciones["REY BARBARO"].size).to eq(1)
    end

    it "junta los niveles repartidos en varias filas" do
      expect(secciones["REY BARBARO"].first).to include(current_level: 4, max_level: 6)
    end

    it "asigna a cada nivel el ayuntamiento que lo habilita" do
      expect(secciones["REY BARBARO"].first[:etiquetas])
        .to eq([ "TH7", "TH7", "TH7", "TH8", "TH8", "TH8" ])
    end

    # El bloque REPORT repite los nombres de los heroes con sus totales al lado.
    it "no confunde la fila del REPORT con un heroe" do
      expect(secciones["REY BARBARO"].first[:max_level]).to eq(6)
    end
  end

  describe "seccion de guardianes" do
    it "reconoce el equipo por el patron de dos filas" do
      expect(secciones["GUARDIANES"].map { |e| e[:nombre] }).to eq([ "TIRADORA" ])
    end

    it "lee su progreso de la fila de abajo" do
      expect(secciones["GUARDIANES"].first).to include(current_level: 2, max_level: 3)
    end

    it "no toma como equipo una etiqueta del REPORT" do
      expect(secciones["GUARDIANES"].map { |e| e[:nombre] }).not_to include("PROGRESO")
    end

    # Cada equipo es unico: numerarlos por orden de aparicion le daria a un mismo
    # equipo indices distintos segun la cuenta, y dejaria de ser el mismo.
    it "numera cada equipo como una unica copia" do
      expect(secciones["GUARDIANES"].map { |e| e[:indice] }).to all(eq(1))
    end
  end

  it "no devuelve secciones vacias" do
    expect(secciones.values).to all(be_present)
  end
end
