FactoryBot.define do
  factory :game_item do
    categoria { "NIVELES DEFENSAS" }
    sequence(:nombre) { |n| "Canon #{n}" }
    nombre_api { nil }
    max_level { 21 }
    desbloquea_en_th { 1 }
    orden { 0 }

    trait :heroe do
      categoria { "REY BARBARO" }
      sequence(:nombre) { |n| "Rey Barbaro #{n}" }
      sequence(:nombre_api) { |n| "Barbarian King #{n}" }
      max_level { 95 }
      desbloquea_en_th { 7 }
    end

    trait :animal do
      categoria { "ANIMALES" }
      sequence(:nombre) { |n| "Lassi #{n}" }
      sequence(:nombre_api) { |n| "L.A.S.S.I #{n}" }
      max_level { 10 }
      desbloquea_en_th { 14 }
    end

    trait :guardian do
      categoria { "GUARDIANES" }
      sequence(:nombre) { |n| "Rayo Furioso #{n}" }
      sequence(:nombre_api) { |n| "Rage Vial #{n}" }
      max_level { 27 }
      desbloquea_en_th { 8 }
    end

    trait :tropa_clara do
      categoria { "TROPAS CLARAS" }
      sequence(:nombre) { |n| "Barbaro #{n}" }
      sequence(:nombre_api) { |n| "Barbarian #{n}" }
      max_level { 12 }
    end

    trait :trampa do
      categoria { "NIVELES TRAMPAS" }
      sequence(:nombre) { |n| "Bomba #{n}" }
      nombre_api { nil }
      max_level { 12 }
    end

    trait :con_niveles do
      transient { cantidad_de_niveles { 3 } }

      after(:create) do |game_item, evaluator|
        (1..evaluator.cantidad_de_niveles).each do |posicion|
          create(:game_item_level, game_item: game_item, posicion: posicion)
        end
      end
    end

    # Disponibilidad por ayuntamiento: { 9 => { cantidad: 6, max_level: 13 } }
    trait :con_disponibilidad do
      transient { por_town_hall { {} } }

      after(:create) do |game_item, evaluator|
        evaluator.por_town_hall.each do |town_hall, datos|
          create(:game_item_town_hall,
            game_item: game_item,
            town_hall: town_hall,
            cantidad: datos.fetch(:cantidad, 1),
            max_level: datos.fetch(:max_level, game_item.max_level))
        end
      end
    end
  end
end
