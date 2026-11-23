# frozen_string_literal: true

# == Schema Information
#
# Table name: user_notification_settings
#
#  id                                    :integer          not null, primary key
#  family_calendar_reminder_enabled      :boolean          default(FALSE), not null
#  family_calendar_reminder_hour         :integer
#  family_task_progress_reminder_enabled :boolean          default(FALSE), not null
#  family_task_progress_reminder_hour    :integer
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  user_id                               :bigint           not null
#
# Indexes
#
#  index_user_notif_settings_on_calendar_reminder       (family_calendar_reminder_enabled,
#                                                        family_calendar_reminder_hour)
#  index_user_notif_settings_on_task_progress_reminder  (family_task_progress_reminder_enabled,
#                                                        family_task_progress_reminder_hour)
#  index_user_notification_settings_on_user_id          (user_id) UNIQUE
#
class UserNotificationSetting < ApplicationRecord
  # 通知時刻は30分刻みで選ぶ
  MINUTE_STEPS = [0, 30].freeze

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :family_calendar_reminder_hour, inclusion: { in: 0..23 }, allow_nil: true
  validates :family_task_progress_reminder_hour, inclusion: { in: 0..23 }, allow_nil: true
  validates :family_calendar_reminder_hour, presence: true, if: :family_calendar_reminder_enabled?
  validates :family_task_progress_reminder_hour, presence: true, if: :family_task_progress_reminder_enabled?
  validates :daily_review_reminder_hour, inclusion: { in: 0..23 }, allow_nil: true
  validates :daily_review_reminder_hour, presence: true, if: :daily_review_reminder_enabled?
  validates :family_calendar_reminder_minute, :family_task_progress_reminder_minute,
            :daily_review_reminder_minute, inclusion: { in: MINUTE_STEPS }
end
