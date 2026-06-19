# frozen_string_literal: true

# == Schema Information
#
# Table name: plans
#
#  id                :integer          not null, primary key
#  date              :date             not null
#  description       :text
#  end_time          :time
#  start_time        :time
#  title             :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :bigint
#  family_id         :bigint           not null
#  last_edited_by_id :bigint
#
# Indexes
#
#  index_plans_on_date_and_start_time  (date,start_time)
#  index_plans_on_family_id_and_date   (family_id,date)
#
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

  describe 'associations' do
    let(:family) { create(:family) }
    let(:user1) { create(:user, family: family) }
    let(:user2) { create(:user, family: family) }
    let(:plan) { create(:plan, family: family, created_by: user1) }

    before do
      create(:plan_participant, plan: plan, user: user1, status: :joined)
      create(:plan_participant, plan: plan, user: user2, status: :declined)
    end

    describe '#participants' do
      it 'includes all participants including declined ones' do
        expect(plan.participants).to include(user1, user2)
      end
    end

    describe '#active_participants' do
      it 'includes only joined and pending participants' do
        expect(plan.active_participants).to include(user1)
        expect(plan.active_participants).not_to include(user2)
      end
    end

    describe '#joined_participants' do
      it 'includes only joined participants' do
        expect(plan.joined_participants).to include(user1)
        expect(plan.joined_participants).not_to include(user2)
      end
    end
  end
end
