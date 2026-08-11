# Progreso de una cuenta sobre un elemento del catalogo.
#
# Clase base de una jerarquia por herencia de tabla unica: Heroe, Animal,
# Defensa, Trampa, TropaClara, TropaOscura, HechizoClaro, HechizoOscuro,
# MaquinaAsedio y Guardian. Cada seccion del Sheet es una clase real, y todas
# cuelgan de la cuenta, asi que actualizar una cuenta nunca alcanza a otra.
#
# Comparten tabla porque comparten exactamente las mismas columnas: nueve tablas
# identicas solo agregarian joins para calcular el mismo total.
class AccountItem < ApplicationRecord
  FUENTES = %w[sheet api manual].freeze

  belongs_to :account
  belongs_to :game_item

  delegate :categoria, :nombre, :nombre_api, to: :game_item

  validates :fuente, presence: true, inclusion: { in: FUENTES }
  # Una cuenta puede tener varios canones, pero no dos con el mismo indice.
  validates :game_item_id, uniqueness: { scope: [ :account_id, :indice ] }
  validates :indice, numericality: { only_integer: true, greater_than: 0 }
  validates :max_level, numericality: { only_integer: true, greater_than: 0 }
  validates :current_level,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: ->(registro) { registro.max_level.to_i }
    }

  validate :max_level_no_supera_el_catalogo
  validate :clase_coincide_con_la_categoria

  before_validation :asignar_clase_desde_el_catalogo, on: :create

  scope :editados_a_mano, -> { where(bloqueado: true) }
  scope :desde_la_api, -> { where(fuente: "api") }
  scope :ordenados, -> { joins(:game_item).merge(GameItem.ordenados) }

  def faltante
    max_level - current_level
  end

  def completo?
    current_level == max_level
  end

  # En el Sheet el estado de cada nivel era un color de celda. Ahora sale de un
  # numero, que es la razon principal para haber movido los datos a una base.
  def estado_de(posicion)
    return :hecho if posicion <= current_level
    return :en_curso if posicion == current_level + 1

    :pendiente
  end

  def niveles
    game_item.game_item_levels.map do |nivel|
      { posicion: nivel.posicion, etiqueta: nivel.etiqueta, estado: estado_de(nivel.posicion) }
    end
  end

  # La sincronizacion con la API no debe pisar lo que el superadmin corrigio a
  # mano, ni tocar lo que la API directamente no conoce.
  def sincronizable_desde_api?
    !bloqueado? && game_item.sincronizable_con_api?
  end

  def aplicar_desde_api!(nivel, max_del_api: nil)
    return false unless sincronizable_desde_api?

    update!(
      current_level: nivel,
      max_level: max_del_api || max_level,
      fuente: "api",
      sincronizado_en: Time.current
    )
  end

  private

  def asignar_clase_desde_el_catalogo
    self.type ||= game_item&.clase_de_progreso&.name
  end

  # Una cuenta no puede tener un canon de nivel 30 si en el juego llega a 21.
  def max_level_no_supera_el_catalogo
    return if game_item.blank? || max_level.blank?
    return if max_level <= game_item.max_level

    errors.add(:max_level,
      "no puede superar el maximo del juego para #{game_item.nombre} (#{game_item.max_level})")
  end

  # Evita que un Heroe termine apuntando a un canon.
  def clase_coincide_con_la_categoria
    return if game_item.blank? || type.blank?
    return if type == game_item.clase_de_progreso.name

    errors.add(:type,
      "no corresponde a la categoria #{game_item.categoria} del elemento")
  end
end
