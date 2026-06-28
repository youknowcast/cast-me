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
  MEAL_TYPE_LABELS = { 0 => '朝', 1 => '昼', 2 => '夕', 3 => '間食' }.freeze

  belongs_to :family
  belongs_to :user, optional: true
  has_many :meal_foods, dependent: :destroy
  has_many :foods, through: :meal_foods

  validates :date, presence: true
  validates :meal_type, presence: true, inclusion: { in: MEAL_TYPE_LABELS.keys }

  scope :for_date, ->(date) { where(date: date) }
  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :visible_to_user, ->(user_id) { where(user_id: [user_id, nil]) }
  scope :ordered_by_meal_type, -> { order(:meal_type, :created_at) }

  def self.meal_type_options
    MEAL_TYPE_LABELS.map { |value, label| [label, value] }
  end

  def meal_type_text
    MEAL_TYPE_LABELS.fetch(meal_type, '未設定')
  end
end
