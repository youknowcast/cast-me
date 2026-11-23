class HealthEpisode < ApplicationRecord
  belongs_to :family
  belongs_to :user

  has_many :health_episode_temperatures, dependent: :destroy
  has_many :health_episode_medications, dependent: :destroy
  has_many :medications, through: :health_episode_medications
  has_many :health_episode_reminder_times, dependent: :destroy

  enum :status, { active: 0, recovered: 1 }

  validates :title, presence: true, length: { maximum: 255 }
  validates :started_on, presence: true
  validate :ended_on_not_before_started_on
  validate :user_belongs_to_family

  before_validation :sync_status_with_ended_on

  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :for_month, ->(date) { where(started_on: date.all_month) }
  scope :ordered_by_started_on, -> { order(:started_on, :id) }
  scope :overlapping, lambda { |from, to|
    where(started_on: ..to).where('ended_on IS NULL OR ended_on >= ?', from)
  }

  def covers?(date)
    started_on <= date && (ended_on.nil? || ended_on >= date)
  end

  def band_title_on?(date, week_start)
    date == [started_on, week_start].max
  end

  def period_label
    "#{started_on.strftime('%-m/%-d')}〜#{ended_on&.strftime('%-m/%-d')}"
  end

  private

  def sync_status_with_ended_on
    self.status = ended_on.present? ? :recovered : :active
  end

  def ended_on_not_before_started_on
    return if ended_on.blank? || started_on.blank? || ended_on >= started_on

    errors.add(:ended_on, 'は開始日以降にしてください')
  end

  def user_belongs_to_family
    return if user.blank? || family_id.blank? || user.family_id == family_id

    errors.add(:user, 'は家族のメンバーを選んでください')
  end
end
