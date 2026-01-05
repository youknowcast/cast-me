# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserNotificationSetting, type: :model do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe 'associations' do
    it 'belongs to user' do
      setting = build(:user_notification_setting, user: user)
      expect(setting.user).to eq(user)
    end
  end

  describe 'validations' do
    context 'user_id uniqueness' do
      it 'enforces uniqueness of user_id' do
        create(:user_notification_setting, user: user)
        duplicate = build(:user_notification_setting, user: user)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end
    end

    context 'hour range validation' do
      it 'allows calendar_reminder_hour in 0..23' do
        setting = build(:user_notification_setting, user: user, family_calendar_reminder_hour: 12)
        expect(setting).to be_valid
      end

      it 'rejects calendar_reminder_hour outside 0..23' do
        setting = build(:user_notification_setting, user: user, family_calendar_reminder_hour: 24)
        expect(setting).not_to be_valid
      end

      it 'allows task_progress_reminder_hour in 0..23' do
        setting = build(:user_notification_setting, user: user, family_task_progress_reminder_hour: 18)
        expect(setting).to be_valid
      end

      it 'rejects task_progress_reminder_hour outside 0..23' do
        setting = build(:user_notification_setting, user: user, family_task_progress_reminder_hour: -1)
        expect(setting).not_to be_valid
      end
    end

    context 'when family_calendar_reminder_enabled is true' do
      it 'requires family_calendar_reminder_hour' do
        setting = build(:user_notification_setting, user: user,
                        family_calendar_reminder_enabled: true,
                        family_calendar_reminder_hour: nil)
        expect(setting).not_to be_valid
        expect(setting.errors[:family_calendar_reminder_hour]).to be_present
      end
    end

    context 'when family_task_progress_reminder_enabled is true' do
      it 'requires family_task_progress_reminder_hour' do
        setting = build(:user_notification_setting, user: user,
                        family_task_progress_reminder_enabled: true,
                        family_task_progress_reminder_hour: nil)
        expect(setting).not_to be_valid
        expect(setting.errors[:family_task_progress_reminder_hour]).to be_present
      end
    end

    context 'when notifications are disabled' do
      it 'allows nil hour values' do
        setting = build(:user_notification_setting, user: user,
                        family_calendar_reminder_enabled: false,
                        family_calendar_reminder_hour: nil,
                        family_task_progress_reminder_enabled: false,
                        family_task_progress_reminder_hour: nil)
        expect(setting).to be_valid
      end
    end
  end
end
