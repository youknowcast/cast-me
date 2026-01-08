# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe '.send_to_user' do
    context 'when OneSignal credentials are not configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return(nil)
        allow(ENV).to receive(:[]).with('ONESIGNAL_API_KEY').and_return(nil)
        allow(OneSignal::DefaultApi).to receive(:new)
      end

      it 'returns early without making API call' do
        described_class.send_to_user(user_id: user.id, title: 'Test', message: 'Test message')
        expect(OneSignal::DefaultApi).not_to have_received(:new)
      end
    end

    context 'when OneSignal credentials are configured' do
      let(:api_instance) { instance_double(OneSignal::DefaultApi) }
      let(:notification_result) { instance_double(OneSignal::CreateNotificationSuccessResponse, id: 'notif-123') }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return('test-app-id')
        allow(ENV).to receive(:[]).with('ONESIGNAL_API_KEY').and_return('test-api-key')
        allow(ENV).to receive(:fetch).with('ONESIGNAL_APP_ID', nil).and_return('test-app-id')
        allow(OneSignal::DefaultApi).to receive(:new).and_return(api_instance)
        allow(api_instance).to receive(:create_notification).and_return(notification_result)
      end

      it 'creates notification with correct parameters' do
        described_class.send_to_user(
          user_id: user.id,
          title: 'Test Title',
          message: 'Test Message'
        )

        expect(api_instance).to have_received(:create_notification) do |notification|
          expect(notification.app_id).to eq('test-app-id')
          expect(notification.headings).to eq({ 'en' => 'Test Title', 'ja' => 'Test Title' })
          expect(notification.contents).to eq({ 'en' => 'Test Message', 'ja' => 'Test Message' })
        end
      end

      it 'includes URL when provided' do
        described_class.send_to_user(
          user_id: user.id,
          title: 'Test',
          message: 'Test',
          url: 'https://example.com'
        )

        expect(api_instance).to have_received(:create_notification) do |notification|
          expect(notification.url).to eq('https://example.com')
        end
      end

      context 'when API call fails' do
        before do
          allow(api_instance).to receive(:create_notification)
            .and_raise(OneSignal::ApiError.new('API Error'))
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error and returns nil' do
          result = described_class.send_to_user(user_id: user.id, title: 'Test', message: 'Test')
          expect(Rails.logger).to have_received(:error).with(/PushNotificationService error/)
          expect(result).to be_nil
        end
      end
    end
  end

  describe '.send_to_users' do
    it 'delegates to send_to_users with array of user_ids' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return(nil)

      # Should not raise when called with multiple user IDs
      expect do
        described_class.send_to_users(user_ids: [1, 2, 3], title: 'Test', message: 'Test')
      end.not_to raise_error
    end
  end
end
