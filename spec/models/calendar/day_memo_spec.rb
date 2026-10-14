require 'rails_helper'

RSpec.describe DayMemo, type: :model do
  let(:family) { create(:family) }

  describe 'associations' do
    it { is_expected.to belong_to(:family) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_length_of(:body).is_at_most(1000) }
  end

  describe 'date uniqueness within a family' do
    it 'rejects a duplicate date in the same family' do
      create(:day_memo, family: family, date: Date.current)
      duplicate = build(:day_memo, family: family, date: Date.current)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date]).to be_present
    end

    it 'allows the same date in another family' do
      create(:day_memo, family: family, date: Date.current)
      other = build(:day_memo, family: create(:family), date: Date.current)
      expect(other).to be_valid
    end
  end
end
