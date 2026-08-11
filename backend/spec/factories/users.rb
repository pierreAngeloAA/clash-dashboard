FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@clash.test" }
    password { "contrasena-larga-123" }
    rol { "admin" }

    trait :superadmin do
      rol { "superadmin" }
    end
  end
end
