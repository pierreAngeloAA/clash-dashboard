class GameItemLevel < ApplicationRecord
  belongs_to :game_item

  validates :posicion,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :game_item_id }

  validate :posicion_dentro_del_maximo

  private

  def posicion_dentro_del_maximo
    return if game_item.blank? || posicion.blank?
    return if posicion <= game_item.max_level

    errors.add(:posicion,
      "no puede superar el nivel maximo de #{game_item.nombre} (#{game_item.max_level})")
  end
end
