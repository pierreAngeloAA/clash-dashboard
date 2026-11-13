FactoryBot.define do
  factory :account_snapshot do
    account
    taken_on { Date.current }
    progress_pct { 50.0 }
  end
end
