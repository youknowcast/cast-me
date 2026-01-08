# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FamilyTaskStatusNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe '.notify' do
    context 'with no tasks for today' do
      it 'sends notification with zero counts' do
        expect(PushNotificationService).to receive(:send_to_user).with(
          user_id: user.id,
          title: '今日のタスク状況',
          message: '家族のタスク状況 済/未: 0 / 0 件'
        )

        described_class.notify(user)
      end
    end

    context 'with tasks for today' do
      before do
        # Create completed tasks
        create(:task, family: family, user: user, date: Date.current, completed: true)
        create(:task, family: family, user: user, date: Date.current, completed: true)
        # Create pending tasks
        create(:task, family: family, user: user, date: Date.current, completed: false)
      end

      it 'sends notification with correct counts' do
        expect(PushNotificationService).to receive(:send_to_user).with(
          user_id: user.id,
          title: '今日のタスク状況',
          message: '家族のタスク状況 済/未: 2 / 1 件'
        )

        described_class.notify(user)
      end
    end

    context 'with tasks from other dates' do
      before do
        # Create task for yesterday (should not be counted)
        create(:task, family: family, user: user, date: Date.current - 1.day, completed: true)
        # Create task for today
        create(:task, family: family, user: user, date: Date.current, completed: false)
      end

      it 'only counts tasks for today' do
        expect(PushNotificationService).to receive(:send_to_user).with(
          user_id: user.id,
          title: '今日のタスク状況',
          message: '家族のタスク状況 済/未: 0 / 1 件'
        )

        described_class.notify(user)
      end
    end

    context 'with tasks from other family members' do
      let(:other_user) { create(:user, family: family) }

      before do
        # Task from other family member should be counted
        create(:task, family: family, user: other_user, date: Date.current, completed: true)
        # Task from current user
        create(:task, family: family, user: user, date: Date.current, completed: false)
      end

      it 'counts all family tasks' do
        expect(PushNotificationService).to receive(:send_to_user).with(
          user_id: user.id,
          title: '今日のタスク状況',
          message: '家族のタスク状況 済/未: 1 / 1 件'
        )

        described_class.notify(user)
      end
    end
  end
end
