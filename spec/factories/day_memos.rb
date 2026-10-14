FactoryBot.define do
  factory :day_memo do
    association :family
    date { Time.zone.today }
    body { '家族メモ' }
  end
end
