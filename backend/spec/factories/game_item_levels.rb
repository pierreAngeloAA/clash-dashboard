FactoryBot.define do
  factory :game_item_level do
    game_item
    posicion { 1 }
    etiqueta { nil }
  end
end
