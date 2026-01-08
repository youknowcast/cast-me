# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeeklyTaskSummaryNotificationService do
  describe '.notify_all_families' do
    let!(:family1) { create(:family) }
    let!(:family2) { create(:family) }
    let!(:user1) { create(:user, family: family1) }
    let!(:user2) { create(:user, family: family2) }

    before do
      # Disable actual OneSignal calls
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return(nil)
      allow(ENV).to receive(:[]).with('ONESIGNAL_API_KEY').and_return(nil)
    end

    it 'notifies all families and returns the count' do
      result = described_class.notify_all_families
      expect(result[:count]).to eq(2)
    end
  end

  describe '.notify_family' do
    let(:family) { create(:family) }
    let!(:user1) { create(:user, family: family) }
    let!(:user2) { create(:user, family: family) }

    let(:week_start) { Date.current.beginning_of_week }
    let(:week_end) { Date.current.end_of_week }

    before do
      # Create tasks for the current week
      create(:task, user: user1, family: family, date: week_start, completed: true)
      create(:task, user: user1, family: family, date: week_start + 1.day, completed: true)
      create(:task, user: user2, family: family, date: week_start + 2.days, completed: false)
      create(:task, user: user2, family: family, date: week_end, completed: false)

      # Task outside of the current week (should not be counted)
      create(:task, user: user1, family: family, date: week_start - 1.week, completed: true)

      # Disable actual OneSignal calls
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return(nil)
      allow(ENV).to receive(:[]).with('ONESIGNAL_API_KEY').and_return(nil)
    end

    it 'does not raise error when OneSignal is not configured' do
      expect { described_class.notify_family(family) }.not_to raise_error
    end

    context 'when OneSignal is configured' do
      let(:mock_api) { instance_double(OneSignal::DefaultApi) }
      let(:mock_result) { instance_double(OneSignal::CreateNotificationSuccessResponse, id: 'test-notification-id') }

      before do
        allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return('test-app-id')
        allow(ENV).to receive(:[]).with('ONESIGNAL_API_KEY').and_return('test-api-key')
        allow(ENV).to receive(:fetch).with('ONESIGNAL_APP_ID', nil).and_return('test-app-id')
        allow(ENV).to receive(:fetch).with('APP_HOST', 'localhost').and_return('test.example.com')
        allow(OneSignal::DefaultApi).to receive(:new).and_return(mock_api)
        allow(mock_api).to receive(:create_notification).and_return(mock_result)
      end

      it 'sends notification with correct message' do
        described_class.notify_family(family)

        expect(mock_api).to have_received(:create_notification) do |notification|
          expect(notification.contents['ja']).to include('完了: 2件')
          expect(notification.contents['ja']).to include('未完了: 2件')
        end
      end

      it 'includes all family user external_ids' do
        described_class.notify_family(family)

        expect(mock_api).to have_received(:create_notification) do |notification|
          external_ids = notification.include_aliases['external_id']
          expect(external_ids).to include(user1.onesignal_external_id)
          expect(external_ids).to include(user2.onesignal_external_id)
        end
      end

      it 'includes URL to weekly summary page' do
        described_class.notify_family(family)

        expect(mock_api).to have_received(:create_notification) do |notification|
          expect(notification.url).to include('/weekly_summary')
        end
      end
    end
  end
end
