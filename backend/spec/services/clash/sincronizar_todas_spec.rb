require "rails_helper"

RSpec.describe Clash::SincronizarTodas do
  def cuenta_con(nombre, nombre_api, current_level, max_level)
    cuenta = create(:account, :sincronizable, nombre: nombre, town_hall: nil)
    catalogo = create(:game_item, categoria: "TROPAS CLARAS",
      nombre: "#{nombre_api} #{nombre}", nombre_api: "#{nombre_api} #{nombre}", max_level: 100)
    AccountItem.create!(account: cuenta, game_item: catalogo,
      current_level: current_level, max_level: max_level, fuente: "sheet")

    cuenta
  end

  def cliente_que_responde(&respuesta)
    doble = instance_double(Clash::Cliente)
    allow(doble).to receive(:jugador) { |tag| respuesta.call(tag) }
    doble
  end

  it "devuelve un resultado por cada cuenta con tag" do
    cuenta_con("Una", "Barbarian", 5, 12)
    cuenta_con("Otra", "Archer", 5, 12)

    resultados = described_class.new(cliente: cliente_que_responde { { "troops" => [] } }).call

    expect(resultados.size).to eq(2)
    expect(resultados).to all(be_ok)
  end

  it "deja afuera a las cuentas sin tag" do
    cuenta_con("Con tag", "Barbarian", 5, 12)
    create(:account, nombre: "Sin tag", town_hall: nil)

    resultados = described_class.new(cliente: cliente_que_responde { { "troops" => [] } }).call

    expect(resultados.map { |r| r.account.nombre }).to eq([ "Con tag" ])
  end

  it "aplica el progreso de cada cuenta" do
    cuenta_con("Una", "Barbarian", 5, 12)

    described_class.new(cliente: cliente_que_responde {
      { "troops" => [ { "name" => "Barbarian Una", "level" => 11, "maxLevel" => 12,
                        "village" => "home" } ] }
    }).call

    expect(AccountItem.first.reload.current_level).to eq(11)
  end

  # Trece cuentas son trece llamadas a una API ajena: que una falle no puede
  # dejar sin sincronizar a las otras doce.
  it "sigue con las demas cuando una cuenta falla" do
    cuenta_con("Primera", "Barbarian", 5, 12)
    segunda = cuenta_con("Segunda", "Archer", 5, 12)

    cliente = cliente_que_responde do |tag|
      raise Clash::Cliente::Error.new("token rechazado", status: 403) if tag == segunda.tag_coc

      { "troops" => [ { "name" => "Barbarian Primera", "level" => 11, "maxLevel" => 12,
                        "village" => "home" } ] }
    end

    resultados = described_class.new(cliente: cliente).call

    expect(resultados.map(&:ok?)).to eq([ true, false ])
    expect(resultados.last.error).to eq("token rechazado")
  end

  it "anota el motivo del fallo en vez de perderlo" do
    cuenta_con("Una", "Barbarian", 5, 12)
    cliente = cliente_que_responde do
      raise Clash::Cliente::Error.new("La API no respondio a tiempo.", status: 504)
    end

    resultado = described_class.new(cliente: cliente).call.first

    expect(resultado).not_to be_ok
    expect(resultado.error).to match(/no respondio a tiempo/)
    expect(resultado.informe).to be_nil
  end

  # Un error de programacion escondido en un informe es peor que uno que
  # revienta: nadie lo mira hasta que los datos ya estan mal.
  it "no atrapa los errores que no son de la API" do
    cuenta_con("Una", "Barbarian", 5, 12)
    cliente = cliente_que_responde { raise ArgumentError, "esto es un bug" }

    expect { described_class.new(cliente: cliente).call }
      .to raise_error(ArgumentError, "esto es un bug")
  end

  it "no falla cuando ninguna cuenta tiene tag" do
    create(:account, town_hall: nil)

    expect(described_class.new(cliente: cliente_que_responde { {} }).call).to eq([])
  end
end
