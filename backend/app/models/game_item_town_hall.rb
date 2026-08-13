# Que ofrece un ayuntamiento concreto para un elemento del catalogo.
class GameItemTownHall < ApplicationRecord
  belongs_to :game_item

  validates :town_hall,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :game_item_id }
  validates :max_level, numericality: { only_integer: true, greater_than: 0 }
  validates :cantidad, numericality: { only_integer: true, greater_than: 0 }

  validate :max_level_no_supera_el_del_juego

  private

  def max_level_no_supera_el_del_juego
    return if game_item.blank? || max_level.blank?
    return if max_level <= game_item.max_level

    errors.add(:max_level,
      "no puede superar el maximo del juego para #{game_item.nombre} (#{game_item.max_level})")
  end
end
