# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Plan do
  describe 'validations' do
    let(:family) { create(:family) }
    let(:user) { create(:user, family: family) }

    describe 'time validation' do
      context 'when start_time > end_time' do
        it 'is invalid' do
          plan = build(:plan, family: family, created_by: user,
                              start_time: '14:00', end_time: '10:00')
          expect(plan).not_to be_valid
          expect(plan.errors[:end_time]).to include('は開始時刻より後に設定してください')
        end
      end

      context 'when start_time == end_time' do
        it 'is valid' do
          plan = build(:plan, family: family, created_by: user,
                              start_time: '10:00', end_time: '10:00')
          expect(plan).to be_valid
        end
      end

      context 'when start_time < end_time' do
        it 'is valid' do
          plan = build(:plan, family: family, created_by: user,
                              start_time: '10:00', end_time: '14:00')
          expect(plan).to be_valid
        end
      end

      context 'when start_time is nil' do
        it 'is valid' do
          plan = build(:plan, family: family, created_by: user,
                              start_time: nil, end_time: '14:00')
          expect(plan).to be_valid
        end
      end

      context 'when end_time is nil' do
        it 'is valid' do
          plan = build(:plan, family: family, created_by: user,
                              start_time: '10:00', end_time: nil)
          expect(plan).to be_valid
        end
      end
    end
  end
end
