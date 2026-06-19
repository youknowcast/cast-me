require 'rails_helper'

RSpec.describe 'Settings', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before do
    sign_in user
  end

  describe 'GET /settings' do
    it 'renders the settings page' do
      get settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(user.login_id)
    end
  end

  describe 'PATCH /settings' do
    context 'with valid parameters' do
      let(:birth_date) { Date.new(1990, 1, 1) }

      it 'updates the user birthday' do
        patch settings_path, params: { user: { birth: birth_date } }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to eq('設定を更新しました')
        expect(user.reload.birth).to eq(birth_date)
      end
    end

    context 'with invalid parameters' do
      it 'does not update the user and returns unprocessable entity' do
        patch settings_path, params: { user: { birth: 1.day.from_now } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(user.reload.birth).to be_nil
      end
    end
  end

  describe 'PATCH /settings/update_avatar' do
    it 'does not update the avatar when no file is selected' do
      patch update_avatar_settings_path

      expect(response).to redirect_to(settings_path)
      expect(flash[:alert]).to eq('ファイルを選択してください')
      expect(user.reload.avatar).to be_nil
    end
  end

  describe 'PATCH /settings/update_notifications' do
    let(:valid_params) do
      {
        user_notification_setting: {
          family_calendar_reminder_enabled: true,
          family_calendar_reminder_hour: 8,
          family_task_progress_reminder_enabled: true,
          family_task_progress_reminder_hour: 18
        }
      }
    end

    it 'creates notification settings for the current user' do
      expect do
        patch update_notifications_settings_path, params: valid_params
      end.to change(UserNotificationSetting, :count).by(1)

      expect(response).to redirect_to(settings_path)
      setting = user.reload.notification_setting
      expect(setting).to have_attributes(
        family_calendar_reminder_enabled: true,
        family_calendar_reminder_hour: 8,
        family_task_progress_reminder_enabled: true,
        family_task_progress_reminder_hour: 18
      )
    end

    it 'returns validation errors for an enabled reminder without an hour' do
      invalid_params = {
        user_notification_setting: {
          family_calendar_reminder_enabled: true,
          family_calendar_reminder_hour: nil,
          family_task_progress_reminder_enabled: false,
          family_task_progress_reminder_hour: nil
        }
      }

      expect do
        patch update_notifications_settings_path, params: invalid_params
      end.not_to change(UserNotificationSetting, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
