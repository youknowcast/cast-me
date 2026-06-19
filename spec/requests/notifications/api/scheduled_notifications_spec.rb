# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::ScheduledNotifications', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:api_token) { 'test-api-token-12345' }

  around do |example|
    original_token = ENV.fetch('SCHEDULED_NOTIFICATION_API_TOKEN', nil)
    ENV['SCHEDULED_NOTIFICATION_API_TOKEN'] = api_token
    example.run
  ensure
    if original_token.nil?
      ENV.delete('SCHEDULED_NOTIFICATION_API_TOKEN')
    else
      ENV['SCHEDULED_NOTIFICATION_API_TOKEN'] = original_token
    end
  end

  before do
    host! 'localhost'
  end

  describe 'POST /api/scheduled_notifications/trigger' do
    context 'without API token header' do
      it 'returns unauthorized' do
        post '/api/scheduled_notifications/trigger', params: { hour: 9 }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid API token' do
      it 'returns unauthorized' do
        post '/api/scheduled_notifications/trigger',
             params: { hour: 9 },
             headers: { 'X-Api-Token' => 'wrong-token' },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with valid API token' do
      let(:headers) { { 'X-Api-Token' => api_token } }

      it 'returns success with counts' do
        post '/api/scheduled_notifications/trigger',
             params: { hour: 9 },
             headers: headers,
             as: :json
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['status']).to eq('ok')
        expect(json).to have_key('calendar_count')
        expect(json).to have_key('task_count')
      end

      context 'with users having calendar reminder at specified hour' do
        before do
          create(:user_notification_setting, :with_calendar_reminder,
                 user: user,
                 family_calendar_reminder_hour: 9)
          allow(FamilyCalendarNotificationService).to receive(:notify)
        end

        it 'triggers calendar notifications for matching users' do
          post '/api/scheduled_notifications/trigger',
               params: { hour: 9 },
               headers: headers,
               as: :json

          expect(FamilyCalendarNotificationService).to have_received(:notify).with(user)
          expect(response.parsed_body['calendar_count']).to eq(1)
        end

        it 'does not trigger for non-matching hours' do
          post '/api/scheduled_notifications/trigger',
               params: { hour: 10 },
               headers: headers,
               as: :json

          expect(FamilyCalendarNotificationService).not_to have_received(:notify)
          expect(response.parsed_body['calendar_count']).to eq(0)
        end
      end

      context 'with users having task progress reminder at specified hour' do
        before do
          create(:user_notification_setting, :with_task_progress_reminder,
                 user: user,
                 family_task_progress_reminder_hour: 18)
          allow(FamilyTaskStatusNotificationService).to receive(:notify)
        end

        it 'triggers task notifications for matching users' do
          post '/api/scheduled_notifications/trigger',
               params: { hour: 18 },
               headers: headers,
               as: :json

          expect(FamilyTaskStatusNotificationService).to have_received(:notify).with(user)
          expect(response.parsed_body['task_count']).to eq(1)
        end
      end

      context 'with users having both reminders at different hours' do
        before do
          create(:user_notification_setting,
                 user: user,
                 family_calendar_reminder_enabled: true,
                 family_calendar_reminder_hour: 8,
                 family_task_progress_reminder_enabled: true,
                 family_task_progress_reminder_hour: 18)
          allow(FamilyCalendarNotificationService).to receive(:notify)
          allow(FamilyTaskStatusNotificationService).to receive(:notify)
        end

        it 'only triggers matching reminder type for hour 8' do
          post '/api/scheduled_notifications/trigger',
               params: { hour: 8 },
               headers: headers,
               as: :json

          expect(FamilyCalendarNotificationService).to have_received(:notify).with(user)
          expect(FamilyTaskStatusNotificationService).not_to have_received(:notify)
        end

        it 'only triggers matching reminder type for hour 18' do
          post '/api/scheduled_notifications/trigger',
               params: { hour: 18 },
               headers: headers,
               as: :json

          expect(FamilyCalendarNotificationService).not_to have_received(:notify)
          expect(FamilyTaskStatusNotificationService).to have_received(:notify).with(user)
        end
      end
    end
  end
end
