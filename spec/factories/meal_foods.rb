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
FactoryBot.define do
  factory :meal_food do
    association :meal
    association :food
  end
end
