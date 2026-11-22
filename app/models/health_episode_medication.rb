class HealthEpisodeMedication < ApplicationRecord
  belongs_to :health_episode
  belongs_to :medication

  validates :medication_id, uniqueness: { scope: :health_episode_id }
  validate :medication_belongs_to_family

  private

  def medication_belongs_to_family
    return if medication.blank? || health_episode.blank?

    errors.add(:medication, 'は家族の服薬を選んでください') unless medication.family_id == health_episode.family_id
  end
end
