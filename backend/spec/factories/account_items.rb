FactoryBot.define do
  factory :account_item do
    # Sin ayuntamiento la cuenta no se autopuebla del catalogo, asi que el test
    # controla exactamente que elementos existen.
    account { association(:account, town_hall: nil) }
    game_item
    indice { 1 }
    current_level { 0 }
    max_level { 10 }
    fuente { "manual" }
    bloqueado { false }

    trait :completo do
      current_level { max_level }
    end

    trait :desde_sheet do
      fuente { "sheet" }
    end

    trait :desde_api do
      fuente { "api" }
      sincronizado_en { Time.current }
    end

    trait :bloqueado do
      bloqueado { true }
    end

    factory :heroe, class: "Heroe" do
      game_item factory: %i[game_item heroe]
      max_level { 95 }
    end

    factory :animal, class: "Animal" do
      game_item factory: %i[game_item animal]
      max_level { 10 }
    end

    factory :guardian, class: "Guardian" do
      game_item factory: %i[game_item guardian]
      max_level { 27 }
    end

    factory :defensa, class: "Defensa" do
      max_level { 21 }
    end

    factory :trampa_item, class: "Trampa" do
      game_item factory: %i[game_item trampa]
      max_level { 12 }
    end

    factory :tropa_clara, class: "TropaClara" do
      game_item factory: %i[game_item tropa_clara]
      max_level { 12 }
    end
  end
end
