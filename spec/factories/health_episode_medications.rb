FactoryBot.define do
  factory :health_episode_medication do
    health_episode
    medication { association :medication, family: health_episode.family }
  end
end
