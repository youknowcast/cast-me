# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::WeeklyNotifications', type: :request do
  let(:api_token) { 'test-api-token' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('WEEKLY_NOTIFICATION_API_TOKEN', '').and_return(api_token)
  end

  describe 'POST /api/weekly_notifications' do
    let(:headers) { { 'Authorization' => "Bearer #{api_token}" } }

    context 'with valid token' do
      before do
        # Disable actual OneSignal calls
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ONESIGNAL_APP_ID').and_return(nil)
        allow(ENV).to receive(:[]).with('ONESIGNAL_API_KEY').and_return(nil)
      end

      it 'returns success response' do
        post api_weekly_notifications_path, headers: headers
        expect(response).to have_http_status(:success)
      end

      it 'returns JSON with families_notified count' do
        create(:family)
        create(:family)

        post api_weekly_notifications_path, headers: headers

        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['families_notified']).to eq(2)
      end

      it 'calls WeeklyTaskSummaryNotificationService' do
        allow(WeeklyTaskSummaryNotificationService).to receive(:notify_all_families).and_return({ count: 0 })
        post api_weekly_notifications_path, headers: headers
        expect(WeeklyTaskSummaryNotificationService).to have_received(:notify_all_families)
      end
    end

    context 'with invalid token' do
      let(:invalid_headers) { { 'Authorization' => 'Bearer wrong-token' } }

      it 'returns unauthorized status' do
        post api_weekly_notifications_path, headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error JSON' do
        post api_weekly_notifications_path, headers: invalid_headers

        json = response.parsed_body
        expect(json['error']).to eq('Unauthorized')
      end
    end

    context 'without token' do
      it 'returns unauthorized status' do
        post api_weekly_notifications_path
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
