# Reconstruye el bloque REPORT que en el Google Sheet eran formulas de planilla.
#
# Se calcula a demanda a partir del progreso de la cuenta en vez de guardarse:
# almacenarlo obligaria a recalcular en cada edicion y en cada sincronizacion
# con la API, y un solo olvido dejaria la base mintiendo. El costo es una
# consulta agregada por cuenta.
class ReportCalculator
  # Los tres bloques que el Sheet mostraba como filas TOTAL_*.
  GRUPOS = {
    heroes: GameItem::HEROES + [ "GUARDIANES", "ANIMALES" ],
    investigacion: [
      "TROPAS CLARAS",
      "TROPAS OSCURAS",
      "HECHIZOS CLAROS",
      "HECHIZOS OSCUROS",
      "MAQUINAS DE ASEDIO"
    ],
    defensas: [ "NIVELES DEFENSAS", "NIVELES TRAMPAS" ]
  }.freeze

  def initialize(account)
    @account = account
  end

  def call
    {
      categories: categorias,
      totals: totales,
      progresoPct: porcentaje_hecho(suma_global),
      faltantePct: porcentaje_faltante(suma_global),
      hasReport: suma_global[:total].positive?
    }
  end

  private

  attr_reader :account

  # { "NIVELES DEFENSAS" => { total:, faltante: }, ... } en una sola consulta.
  def sumas_por_categoria
    @sumas_por_categoria ||= account.account_items
      .joins(:game_item)
      .group("game_items.categoria")
      .pluck(
        Arel.sql("game_items.categoria"),
        Arel.sql("SUM(account_items.max_level)"),
        Arel.sql("SUM(account_items.max_level - account_items.current_level)")
      )
      .to_h { |cat, total, faltante| [ cat, { total: total.to_i, faltante: faltante.to_i } ] }
  end

  # Las seis secciones de heroe se colapsan en una sola, igual que hacia el
  # Sheet: seis barras de progreso casi identicas no dicen nada.
  def categorias
    sueltas = sumas_por_categoria.except(*GameItem::HEROES)
    filas = sueltas.map { |categoria, suma| fila(categoria, suma) }

    heroes = sumar(GameItem::HEROES)
    filas << fila("HEROES", heroes) if heroes[:total].positive?

    filas.sort_by { |f| f[:label] }
  end

  def totales
    GRUPOS.transform_values { |categorias| sumar(categorias) }.merge(total: suma_global)
  end

  def suma_global
    @suma_global ||= sumar(sumas_por_categoria.keys)
  end

  def sumar(categorias)
    seleccion = sumas_por_categoria.values_at(*categorias).compact

    {
      total: seleccion.sum { |s| s[:total] },
      faltante: seleccion.sum { |s| s[:faltante] }
    }
  end

  def fila(label, suma)
    {
      label: label,
      total: suma[:total],
      faltante: suma[:faltante],
      pctDone: porcentaje_hecho(suma),
      pctMissing: porcentaje_faltante(suma)
    }
  end

  def porcentaje_hecho(suma)
    return 0.0 if suma[:total].zero?

    (((suma[:total] - suma[:faltante]).to_f / suma[:total]) * 100).round(2)
  end

  def porcentaje_faltante(suma)
    return 0.0 if suma[:total].zero?

    (100 - porcentaje_hecho(suma)).round(2)
  end
end
