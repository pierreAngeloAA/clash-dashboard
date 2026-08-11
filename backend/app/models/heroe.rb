# Rey Barbaro, Reina Arquera, Principe de los Esbirros, Gran Centinela,
# Luchadora Real, Duque Dragon.
#
# La API oficial los devuelve en el arreglo "heroes" del jugador.
class Heroe < AccountItem
  def self.categorias
    GameItem::HEROES
  end
end
