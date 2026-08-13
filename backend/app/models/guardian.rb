# Poderes de los heroes (hero equipment): Rayo Furioso, Escudo Real, Guantelete
# Gigante. La API los devuelve en el arreglo "heroEquipment" del jugador.
#
# La clase se llama Guardian porque "GUARDIANES" es como el Google Sheet titula
# la seccion, y el catalogo se importa de ahi. En el resto de la app se los
# llama poderes, que es lo que son.
#
# Cada poder pertenece a un heroe de la misma cuenta. Queda en null mientras el
# catalogo no declare de que heroe es: el Sheet no lo dice.
class Guardian < AccountItem
  belongs_to :heroe, class_name: "Heroe", optional: true

  before_validation :asignar_heroe_del_catalogo, if: -> { heroe_id.nil? }

  validate :el_heroe_es_de_la_misma_cuenta

  scope :sin_heroe, -> { where(heroe_id: nil) }

  def self.categoria
    "GUARDIANES"
  end

  private

  # A que heroe pertenece cada poder lo declara el catalogo, no la cuenta. Si el
  # catalogo todavia no lo dice, o la cuenta no tiene ese heroe, el poder queda
  # sin vincular en vez de colgarse del heroe equivocado.
  def asignar_heroe_del_catalogo
    categoria = game_item&.heroe_categoria
    return if categoria.blank? || account_id.blank?

    self.heroe = Heroe.joins(:game_item)
      .find_by(account_id: account_id, game_items: { categoria: categoria })
  end

  # Sin esto un poder podria terminar colgado del heroe de otro jugador, y la
  # cuenta mostraria un poder que no es suyo.
  def el_heroe_es_de_la_misma_cuenta
    return if heroe.blank?
    return if heroe.account_id == account_id

    errors.add(:heroe, "tiene que ser un heroe de la misma cuenta")
  end
end
