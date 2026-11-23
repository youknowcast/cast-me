FactoryBot.define do
  factory :health_episode do
    family
    user { association :user, family: family }
    sequence(:title) { |n| "体調#{n}" }
    started_on { Time.zone.today }
    symptom_note { nil }
  end
end
