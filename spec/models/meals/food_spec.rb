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
require 'rails_helper'

RSpec.describe Food, type: :model do
  let(:family) { create(:family) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:food, family: family)).to be_valid
    end

    it 'is invalid without a name' do
      food = build(:food, family: family, name: nil)
      expect(food).not_to be_valid
      expect(food.errors[:name]).to be_present
    end

    it 'is invalid with a duplicate name in the same family' do
      create(:food, family: family, name: 'カレー')
      expect(build(:food, family: family, name: 'カレー')).not_to be_valid
    end

    it 'allows the same name in different families' do
      create(:food, family: family, name: 'カレー')
      expect(build(:food, family: create(:family), name: 'カレー')).to be_valid
    end
  end

  describe '.active' do
    it 'returns only active foods' do
      active = create(:food, family: family, active: true)
      create(:food, family: family, active: false)
      expect(family.foods.active).to eq([active])
    end
  end

  describe '.ordered_by_name' do
    it 'orders foods by name' do
      b = create(:food, family: family, name: 'B')
      a = create(:food, family: family, name: 'A')
      expect(family.foods.ordered_by_name).to eq([a, b])
    end
  end

  describe '.frequently_used' do
    it 'excludes inactive foods and orders by name when usage is equal, respecting limit' do
      a = create(:food, family: family, name: 'A', active: true)
      b = create(:food, family: family, name: 'B', active: true)
      create(:food, family: family, name: 'C', active: false)

      expect(family.foods.frequently_used(2)).to eq([a, b])
    end

    it 'orders by usage count desc (derived from meal_foods)' do
      a = create(:food, family: family, name: 'A')
      b = create(:food, family: family, name: 'B')
      create(:meal_food, meal: create(:meal, family: family), food: b)
      create(:meal_food, meal: create(:meal, family: family), food: b)
      create(:meal_food, meal: create(:meal, family: family), food: a)

      expect(family.foods.frequently_used(2).map(&:name)).to eq(%w[B A])
    end
  end
end
