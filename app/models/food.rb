# == Schema Information
#
# Table name: foods
#
#  id         :integer          not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
class Food < ApplicationRecord
  belongs_to :family
  has_many :meal_foods, dependent: :destroy
  has_many :meals, through: :meal_foods

  validates :name, presence: true, length: { maximum: 255 },
                   uniqueness: { scope: :family_id }

  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :active, -> { where(active: true) }
  scope :ordered_by_name, -> { order(:name) }

  # よく食べるもの（meal_foods の件数で導出）。active のみ対象。
  scope :frequently_used, lambda { |limit = 5|
    active
      .left_joins(:meal_foods)
      .group(:id)
      .order(Arel.sql('COUNT(meal_foods.id) DESC'))
      .order(:name)
      .limit(limit)
  }
end
