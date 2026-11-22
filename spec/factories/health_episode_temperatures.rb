FactoryBot.define do
  factory :health_episode_temperature do
    health_episode
    measured_at { Time.current }
    value { 38.0 }
  end
end
