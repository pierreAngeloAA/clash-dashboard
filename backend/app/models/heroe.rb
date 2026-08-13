# Rey Barbaro, Reina Arquera, Principe de los Esbirros, Gran Centinela,
# Luchadora Real, Duque Dragon.
#
# La API oficial los devuelve en el arreglo "heroes" del jugador.
class Heroe < AccountItem
  # Los poderes que lleva equipados este heroe. Se borran con el: un poder no
  # significa nada sin el heroe al que pertenece.
  has_many :poderes, class_name: "Guardian", foreign_key: :heroe_id, dependent: :destroy,
    inverse_of: :heroe

  def self.categorias
    GameItem::HEROES
  end
end
