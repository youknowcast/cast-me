require 'rails_helper'

RSpec.describe PlanParticipant, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:plan) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'statuses' do
    it 'defines the supported participation statuses' do
      expect(described_class.statuses).to eq('pending' => 0, 'joined' => 1, 'declined' => 2)
    end
  end

  describe 'validations' do
    it 'does not allow the same user to participate twice in one plan' do
      participant = create(:plan_participant)
      duplicate = build(:plan_participant, plan: participant.plan, user: participant.user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'allows the same user to participate in different plans' do
      participant = create(:plan_participant)
      another = build(:plan_participant, user: participant.user)

      expect(another).to be_valid
    end
  end
end
