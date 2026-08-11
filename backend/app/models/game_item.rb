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

  scope :de_la_api, -> { where(categoria: CATEGORIAS_DE_LA_API) }
  scope :solo_manuales, -> { where.not(categoria: CATEGORIAS_DE_LA_API) }
  scope :heroes, -> { where(categoria: HEROES) }
  scope :ordenados, -> { order(:categoria, :orden, :nombre) }

  def heroe?
    HEROES.include?(categoria)
  end

  # Clase de AccountItem que corresponde crear para este elemento.
  def clase_de_progreso
    CLASE_POR_CATEGORIA.fetch(categoria).constantize
  end

  def sincronizable_con_api?
    CATEGORIAS_DE_LA_API.include?(categoria) && nombre_api.present?
  end
end
