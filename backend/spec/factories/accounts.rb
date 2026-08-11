FactoryBot.define do
  factory :account do
    sequence(:nombre) { |n| "Cuenta #{n}" }
    town_hall { 15 }
    orden { 0 }
    tag_coc { nil }
    gid_origen { nil }

    # Los tags de Clash solo usan estos caracteres, nunca 1, 3, 4, 5, 6 ni 7.
    trait :sincronizable do
      sequence(:tag_coc) { |n| "#LJ8V90G#{%w[0 2 8 9 P Y L Q R J].fetch(n % 10)}" }
    end
  end
end
