FactoryBot.define do
  factory :health_episode_reminder_time do
    health_episode
    hour { 8 }
    minute { 0 }
  end
end
