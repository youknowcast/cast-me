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
require 'rails_helper'

RSpec.describe Meal, type: :model do
  let(:family) { create(:family) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(build(:meal, family: family)).to be_valid
    end

    it 'is valid without a user (家族みんな)' do
      expect(build(:meal, family: family, user: nil)).to be_valid
    end

    it 'is invalid without a date' do
      expect(build(:meal, family: family, date: nil)).not_to be_valid
    end

    it 'is invalid with an out-of-range meal_type' do
      expect(build(:meal, family: family, meal_type: 4)).not_to be_valid
    end

    it 'is valid when the user belongs to the same family' do
      member = create(:user, family: family)
      expect(build(:meal, family: family, user: member)).to be_valid
    end

    it 'is invalid when the user belongs to another family' do
      stranger = create(:user)
      meal = build(:meal, family: family, user: stranger)
      expect(meal).not_to be_valid
      expect(meal.errors[:user_id]).to be_present
    end
  end

  describe '.visible_to_user' do
    it 'returns meals for the user or with no user' do
      me = create(:user, family: family)
      other = create(:user, family: family)
      mine = create(:meal, family: family, user: me)
      shared = create(:meal, family: family, user: nil)
      create(:meal, family: family, user: other)

      expect(family.meals.visible_to_user(me.id)).to contain_exactly(mine, shared)
    end
  end

  describe '#meal_type_text' do
    it 'returns the Japanese label' do
      expect(build(:meal, meal_type: 0).meal_type_text).to eq('朝')
      expect(build(:meal, meal_type: 3).meal_type_text).to eq('間食')
    end
  end

  describe '.meal_type_options' do
    it 'returns label/value pairs for selects' do
      expect(described_class.meal_type_options).to eq([['朝', 0], ['昼', 1], ['夕', 2], ['間食', 3]])
    end
  end

  describe '.default_meal_type_at' do
    def meal_type_at(hour, minute)
      described_class.default_meal_type_at(Time.zone.local(2026, 11, 23, hour, minute))
    end

    it 'selects 朝 from 4:00 through 10:59' do
      expect(meal_type_at(4, 0)).to eq(0)
      expect(meal_type_at(10, 59)).to eq(0)
    end

    it 'selects 昼 from 11:00 through 14:59' do
      expect(meal_type_at(11, 0)).to eq(1)
      expect(meal_type_at(14, 59)).to eq(1)
    end

    it 'selects 夕 from 15:00 through 23:59' do
      expect(meal_type_at(15, 0)).to eq(2)
      expect(meal_type_at(23, 59)).to eq(2)
    end

    it 'selects 夕 from 0:00 through 3:59' do
      expect(meal_type_at(0, 0)).to eq(2)
      expect(meal_type_at(3, 59)).to eq(2)
    end
  end
end
