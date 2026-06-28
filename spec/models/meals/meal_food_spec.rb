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
require 'rails_helper'

RSpec.describe MealFood, type: :model do
  let(:family) { create(:family) }
  let(:meal) { create(:meal, family: family) }
  let(:food) { create(:food, family: family) }

  it 'is valid with a meal and food' do
    expect(build(:meal_food, meal: meal, food: food)).to be_valid
  end

  it 'does not allow the same food twice in one meal' do
    create(:meal_food, meal: meal, food: food)
    expect(build(:meal_food, meal: meal, food: food)).not_to be_valid
  end

  it 'is destroyed when its meal is destroyed' do
    create(:meal_food, meal: meal, food: food)
    expect { meal.destroy }.to change(described_class, :count).by(-1)
  end
end
