FactoryBot.define do
  factory :task do
    association :family
    association :user
    title { 'Test Task' }
    date { Time.zone.today }
    priority { 1 }
    completed { false }
  end
end
