# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeeklyTaskSummaryNotificationService, type: :service do
  describe '.notify_all_families' do
    let!(:family1) { create(:family) }
    let!(:family2) { create(:family) }
    let!(:user1) { create(:user, family: family1) }
    let!(:user2) { create(:user, family: family2) }

    before do
      allow(PushNotificationService).to receive(:send_to_users)
    end

    it 'notifies all families and returns the count' do
      result = described_class.notify_all_families
      expect(result[:count]).to eq(2)
    end

    it 'sends notification to each family' do
      described_class.notify_all_families

      expect(PushNotificationService).to have_received(:send_to_users).twice
    end
  end

  describe '.notify_family' do
    let(:family) { create(:family) }
    let!(:user1) { create(:user, family: family) }
    let!(:user2) { create(:user, family: family) }

    let(:week_start) { Date.current.beginning_of_week }
    let(:week_end) { Date.current.end_of_week }

    before do
      allow(PushNotificationService).to receive(:send_to_users)
    end

    context 'with no tasks for the week' do
      it 'sends notification with zero counts' do
        described_class.notify_family(family)

        expect(PushNotificationService).to have_received(:send_to_users).with(
          user_ids: contain_exactly(user1.id, user2.id),
          title: '📋 今週のタスクサマリ',
          message: '完了: 0件 / 未完了: 0件',
          url: kind_of(String)
        )
      end
    end

    context 'with tasks for the week' do
      before do
        # Create completed tasks
        create(:task, user: user1, family: family, date: week_start, completed: true)
        create(:task, user: user1, family: family, date: week_start + 1.day, completed: true)
        # Create pending tasks
        create(:task, user: user2, family: family, date: week_start + 2.days, completed: false)
        create(:task, user: user2, family: family, date: week_end, completed: false)
      end

      it 'sends notification with correct counts' do
        described_class.notify_family(family)

        expect(PushNotificationService).to have_received(:send_to_users).with(
          user_ids: contain_exactly(user1.id, user2.id),
          title: '📋 今週のタスクサマリ',
          message: '完了: 2件 / 未完了: 2件',
          url: kind_of(String)
        )
      end
    end

    context 'with tasks from other weeks' do
      before do
        # Task outside of the current week (should not be counted)
        create(:task, user: user1, family: family, date: week_start - 1.week, completed: true)
        # Task for this week
        create(:task, user: user1, family: family, date: week_start, completed: false)
      end

      it 'only counts tasks for current week' do
        described_class.notify_family(family)

        expect(PushNotificationService).to have_received(:send_to_users).with(
          user_ids: contain_exactly(user1.id, user2.id),
          title: '📋 今週のタスクサマリ',
          message: '完了: 0件 / 未完了: 1件',
          url: kind_of(String)
        )
      end
    end

    context 'with empty family (no users)' do
      let(:empty_family) { create(:family) }

      it 'does not send notification' do
        described_class.notify_family(empty_family)

        expect(PushNotificationService).not_to have_received(:send_to_users)
      end
    end

    it 'includes URL to weekly summary page' do
      described_class.notify_family(family)

      expect(PushNotificationService).to have_received(:send_to_users) do |args|
        expect(args[:url]).to include('/weekly_summary')
      end
    end
  end
end
