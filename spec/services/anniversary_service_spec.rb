require 'rails_helper'

RSpec.describe AnniversaryService do
  describe '.anniversaries_on' do
    let(:family) { create(:family) }
    let(:user1) { create(:user, family: family, login_id: 'user1', birth: Date.new(1990, 5, 20)) }
    let(:user2) { create(:user, family: family, login_id: 'user2', birth: Date.new(1995, 10, 15)) }
    let(:users) { [user1, user2] }

    context 'when it is user1 birthday' do
      let(:date) { Date.new(2026, 5, 20) }

      it 'returns user1 birthday anniversary' do
        result = described_class.anniversaries_on(date, users)
        expect(result.size).to eq(1)
        expect(result.first.name).to eq('user1さんの誕生日')
        expect(result.first.type).to eq(:birthday)
        expect(result.first.user).to eq(user1)
      end
    end

    context 'when it is user2 birthday' do
      let(:date) { Date.new(2026, 10, 15) }

      it 'returns user2 birthday anniversary' do
        result = described_class.anniversaries_on(date, users)
        expect(result.size).to eq(1)
        expect(result.first.name).to eq('user2さんの誕生日')
        expect(result.first.user).to eq(user2)
      end
    end

    context 'when it is no one birthday' do
      let(:date) { Date.new(2026, 1, 1) }

      it 'returns empty array' do
        result = described_class.anniversaries_on(date, users)
        expect(result).to be_empty
      end
    end

    context 'when multiple users have birthday on the same day' do
      let(:user3) { create(:user, family: family, login_id: 'user3', birth: Date.new(2000, 5, 20)) }
      let(:users) { [user1, user2, user3] }
      let(:date) { Date.new(2026, 5, 20) }

      it 'returns all birthdays' do
        result = described_class.anniversaries_on(date, users)
        expect(result.size).to eq(2)
        expect(result.map(&:user)).to contain_exactly(user1, user3)
      end
    end
  end
end
