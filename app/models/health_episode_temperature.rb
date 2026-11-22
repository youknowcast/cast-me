class HealthEpisodeTemperature < ApplicationRecord
  MIN_VALUE = 30.0
  MAX_VALUE = 45.0

  belongs_to :health_episode

  attribute :measured_at, :datetime, default: -> { Time.current }

  validates :measured_at, presence: true
  validates :value, presence: true,
                    numericality: { greater_than_or_equal_to: MIN_VALUE, less_than_or_equal_to: MAX_VALUE }
end
