# == Schema Information
#
# Table name: meals
#
#  id         :integer          not null, primary key
#  date       :date             not null
#  meal_type  :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#  user_id    :bigint
#
class Meal < ApplicationRecord
  MEAL_TYPE_MORNING = 0
  MEAL_TYPE_LUNCH = 1
  MEAL_TYPE_EVENING = 2
  MEAL_TYPE_SNACK = 3

  MEAL_TYPE_LABELS = {
    MEAL_TYPE_MORNING => '朝',
    MEAL_TYPE_LUNCH => '昼',
    MEAL_TYPE_EVENING => '夕',
    MEAL_TYPE_SNACK => '間食'
  }.freeze

  DEFAULT_MEAL_TYPE_HOUR_RANGES = {
    4...11 => MEAL_TYPE_MORNING,
    11...15 => MEAL_TYPE_LUNCH
  }.freeze

  belongs_to :family
  belongs_to :user, optional: true
  has_many :meal_foods, dependent: :destroy
  has_many :foods, through: :meal_foods

  validates :date, presence: true
  validates :meal_type, presence: true, inclusion: { in: MEAL_TYPE_LABELS.keys }
  validate :user_in_same_family

  scope :for_date, ->(date) { where(date: date) }
  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :visible_to_user, ->(user_id) { where(user_id: [user_id, nil]) }
  scope :ordered_by_meal_type, -> { order(:meal_type, :created_at) }

  def self.meal_type_options
    MEAL_TYPE_LABELS.map { |value, label| [label, value] }
  end

  def self.default_meal_type_at(time)
    DEFAULT_MEAL_TYPE_HOUR_RANGES.find { |hours, _| hours.cover?(time.hour) }&.last || MEAL_TYPE_EVENING
  end

  def meal_type_text
    MEAL_TYPE_LABELS.fetch(meal_type, '未設定')
  end

  private

  def user_in_same_family
    return if user_id.blank? || family_id.blank?
    return if user && user.family_id == family_id

    errors.add(:user_id, 'は同じ家族のメンバーである必要があります')
  end
end
