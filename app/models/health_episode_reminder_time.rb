class HealthEpisodeReminderTime < ApplicationRecord
  MINUTES = [0, 30].freeze

  belongs_to :health_episode

  validates :hour, presence: true, inclusion: { in: 0..23 }
  validates :minute, presence: true, inclusion: { in: MINUTES }
  validates :minute, uniqueness: { scope: %i[health_episode_id hour] }

  scope :ordered, -> { order(:hour, :minute) }

  def label
    format('%<hour>02d:%<minute>02d', hour: hour, minute: minute)
  end
end
