class Medication < ApplicationRecord
  belongs_to :family

  has_many :health_episode_medications, dependent: :destroy
  has_many :health_episodes, through: :health_episode_medications

  validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :family_id }

  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :ordered_by_name, -> { order(:name) }
end
