# == Schema Information
#
# Table name: meal_foods
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  food_id    :bigint           not null
#  meal_id    :bigint           not null
#
class MealFood < ApplicationRecord
  belongs_to :meal
  belongs_to :food

  validates :food_id, uniqueness: { scope: :meal_id }
end
