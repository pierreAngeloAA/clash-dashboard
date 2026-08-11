class Account < ApplicationRecord
  has_many :account_items, dependent: :destroy
  has_many :game_items, through: :account_items

  # Un modelo por seccion del Sheet, todos colgando de la cuenta.
  has_many :heroes, class_name: "Heroe", dependent: :destroy
  has_many :guardianes, class_name: "Guardian", dependent: :destroy
  has_many :animales, class_name: "Animal", dependent: :destroy
  has_many :defensas, class_name: "Defensa", dependent: :destroy
  has_many :trampas, class_name: "Trampa", dependent: :destroy
  has_many :tropas_claras, class_name: "TropaClara", dependent: :destroy
  has_many :tropas_oscuras, class_name: "TropaOscura", dependent: :destroy
  has_many :hechizos_claros, class_name: "HechizoClaro", dependent: :destroy
  has_many :hechizos_oscuros, class_name: "HechizoOscuro", dependent: :destroy
  has_many :maquinas_de_asedio, class_name: "MaquinaAsedio", dependent: :destroy

  # Al crear la cuenta se le genera el inventario que su ayuntamiento habilita.
  after_create :poblar_inventario

  validates :nombre, presence: true, uniqueness: { case_sensitive: false }
  validates :town_hall,
    numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :builder_hall,
    numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :gid_origen, uniqueness: true, allow_nil: true
  validates :tag_coc, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :tag_coc, format: { with: /\A#[0289PYLQGRJCUV]+\z/,
    message: "no parece un tag valido de Clash of Clans" }, allow_nil: true

  before_validation :normalizar_tag

  scope :ordenadas, -> { order(:orden, :nombre) }
  scope :sincronizables, -> { where.not(tag_coc: nil) }

  # El Sheet nombra las pestañas como "Pierre TH15". Al importar se separan el
  # nombre y el ayuntamiento para poder ordenar y filtrar por nivel.
  def self.separar_town_hall(nombre_pestania)
    match = nombre_pestania.to_s.match(/\A(.*?)\s+TH\s*(\d+)\s*\z/i)
    return [ nombre_pestania.to_s.strip, nil ] unless match

    [ match[1].strip, match[2].to_i ]
  end

  # Reemplaza al bloque REPORT del Sheet, que ahi eran formulas. Se calcula a
  # demanda en vez de guardarse: almacenado quedaria desactualizado apenas
  # alguien edite un nivel.
  def report
    ReportCalculator.new(self).call
  end

  def sincronizable?
    tag_coc.present?
  end

  # Devuelve el progreso agrupado por seccion, en el mismo orden en que las
  # muestra el Google Sheet.
  def secciones
    por_categoria = account_items
      .includes(game_item: :game_item_levels)
      .group_by { |item| item.game_item.categoria }

    GameItem::CATEGORIAS.filter_map do |categoria|
      items = por_categoria[categoria]
      next if items.blank?

      [ categoria, items.sort_by { |i| [ i.game_item.orden, i.game_item.nombre ] } ]
    end.to_h
  end

  # Vuelve a pasar el catalogo para agregar lo que falte, por ejemplo despues de
  # subir de ayuntamiento. No toca lo que ya tiene progreso.
  def poblar_inventario
    PoblarCuenta.new(self).call
  end

  private

  # El usuario escribe "lj8v90g0" o " #LJ8V90G0 "; la API quiere "#LJ8V90G0".
  def normalizar_tag
    return if tag_coc.blank?

    limpio = tag_coc.to_s.strip.upcase.delete_prefix("#")
    self.tag_coc = limpio.presence && "##{limpio}"
  end
end
