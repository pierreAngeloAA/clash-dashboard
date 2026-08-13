FactoryBot.define do
  factory :game_item_town_hall do
    game_item
    town_hall { 9 }
    max_level { 10 }
    cantidad { 1 }
  end
end
