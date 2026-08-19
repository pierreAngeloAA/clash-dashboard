# Un elemento del juego: el Rey Barbaro, un canon, un hechizo de rayo.
#
# Es catalogo compartido; el progreso de cada jugador vive en AccountItem.
# Las categorias son las secciones del Google Sheet, para que la app siga
# mostrando la informacion con la misma organizacion.
class GameItem < ApplicationRecord
  HEROES = [
    "REY BARBARO",
    "REINA ARQUERA",
    "PRINCIPE ESBIRROS",
    "GRAN CENTINELA",
    "LUCHADORA REAL",
    "DUQUE DRAGON"
  ].freeze

  CATEGORIAS = ([
    "NIVELES DEFENSAS",
    "NIVELES TRAMPAS",
    "TROPAS CLARAS",
    "TROPAS OSCURAS",
    "HECHIZOS CLAROS",
    "HECHIZOS OSCUROS",
    "MAQUINAS DE ASEDIO",
    "ANIMALES",
    "GUARDIANES"
  ] + HEROES).freeze

  # Lo que la API oficial de Clash of Clans sabe responder. Defensas y trampas
  # quedan afuera: la API no las expone, asi que solo pueden venir del Sheet o
  # cargarlas el superadmin.
  CATEGORIAS_DE_LA_API = (CATEGORIAS - [ "NIVELES DEFENSAS", "NIVELES TRAMPAS" ]).freeze

  # Que clase de progreso se crea para cada seccion del Sheet. Las seis
  # secciones de heroe comparten la clase Heroe: son el mismo tipo de cosa.
  CLASE_POR_CATEGORIA = {
    "NIVELES DEFENSAS" => "Defensa",
    "NIVELES TRAMPAS" => "Trampa",
    "TROPAS CLARAS" => "TropaClara",
    "TROPAS OSCURAS" => "TropaOscura",
    "HECHIZOS CLAROS" => "HechizoClaro",
    "HECHIZOS OSCUROS" => "HechizoOscuro",
    "MAQUINAS DE ASEDIO" => "MaquinaAsedio",
    "ANIMALES" => "Animal",
    "GUARDIANES" => "Guardian"
  }.merge(HEROES.index_with("Heroe")).freeze

  has_many :account_items, dependent: :restrict_with_error
  has_many :accounts, through: :account_items
  has_many :game_item_levels, -> { order(:posicion) }, dependent: :destroy
  has_many :game_item_town_halls, -> { order(:town_hall) }, dependent: :destroy

  validates :categoria, presence: true, inclusion: { in: CATEGORIAS }
  validates :nombre, presence: true,
    uniqueness: { scope: :categoria, case_sensitive: false }
  validates :nombre_api, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :max_level, numericality: { only_integer: true, greater_than: 0 }
  # De que heroe es este poder. Solo tiene sentido para los poderes, y solo
  # puede apuntar a un heroe.
  validates :heroe_categoria, inclusion: { in: HEROES }, allow_nil: true
  validate :solo_los_poderes_pertenecen_a_un_heroe

  scope :de_la_api, -> { where(categoria: CATEGORIAS_DE_LA_API) }
  scope :solo_manuales, -> { where.not(categoria: CATEGORIAS_DE_LA_API) }
  scope :heroes, -> { where(categoria: HEROES) }
  scope :ordenados, -> { order(:categoria, :orden, :nombre) }

  # El ayuntamiento mas alto que el catalogo conoce. Sale de las etiquetas y no
  # de una constante, para no tener que tocar el codigo cuando el juego saque
  # uno nuevo. Devuelve 0 si el catalogo no tiene ninguna etiqueta.
  #
  # Se memoiza porque `max_level_para` se llama una vez por elemento y hay miles.
  # El catalogo solo cambia al importarlo, asi que el valor no se mueve durante
  # la vida del proceso; los tests lo limpian con `olvidar_town_hall_maximo!`.
  def self.town_hall_maximo
    return @town_hall_maximo if defined?(@town_hall_maximo) && !@town_hall_maximo.nil?

    @town_hall_maximo = GameItemLevel
      .where("etiqueta ~ ?", "^TH[0-9]+$")
      .pluck(:etiqueta)
      .filter_map { |etiqueta| etiqueta[2..].to_i }
      .max
      .to_i
  end

  def self.olvidar_town_hall_maximo!
    @town_hall_maximo = nil
  end

  def heroe?
    HEROES.include?(categoria)
  end

  # Hasta que nivel puede subir este elemento en un ayuntamiento dado, o `nil` si
  # el catalogo no alcanza para saberlo.
  #
  # Sale de las etiquetas de `game_item_levels`, que el Sheet cargo con el TH en
  # que se desbloquea cada nivel: un canon llega a 19 en TH13, a 20 en TH14 y a
  # 21 en TH15.
  #
  # Devuelve `nil` y no el maximo del juego a proposito. **El dato esta
  # incompleto**: de los 109 elementos, 32 no tienen etiqueta en sus niveles mas
  # altos. Un `nil` deja que cada llamador elija de donde sacar el tope —la API
  # sabe mas que el catalogo—, mientras que devolver el maximo absoluto
  # disfrazaria de respuesta lo que en realidad es no saber.
  def max_level_para(town_hall)
    maximo_conocido = self.class.town_hall_maximo
    return nil if maximo_conocido.zero?

    # En el ayuntamiento mas alto el tope es el maximo del juego, sin importar
    # que a las etiquetas les falten los ultimos niveles.
    return max_level if town_hall.to_i >= maximo_conocido

    game_item_levels
      .filter_map { |nivel| nivel.posicion if nivel.etiqueta.to_s =~ /\ATH(\d+)\z/ && $1.to_i <= town_hall.to_i }
      .max
  end

  # Clase de AccountItem que corresponde crear para este elemento.
  def clase_de_progreso
    CLASE_POR_CATEGORIA.fetch(categoria).constantize
  end

  def sincronizable_con_api?
    CATEGORIAS_DE_LA_API.include?(categoria) && nombre_api.present?
  end

  def poder?
    categoria == "GUARDIANES"
  end

  private

  def solo_los_poderes_pertenecen_a_un_heroe
    return if heroe_categoria.blank? || poder?

    errors.add(:heroe_categoria, "solo se declara en los poderes de heroe")
  end
end
