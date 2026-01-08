# frozen_string_literal: true

FactoryBot.define do
  factory :user_notification_setting do
    association :user
    family_calendar_reminder_enabled { false }
    family_calendar_reminder_hour { nil }
    family_task_progress_reminder_enabled { false }
    family_task_progress_reminder_hour { nil }

    trait :with_calendar_reminder do
      family_calendar_reminder_enabled { true }
      family_calendar_reminder_hour { 8 }
    end

    trait :with_task_progress_reminder do
      family_task_progress_reminder_enabled { true }
      family_task_progress_reminder_hour { 18 }
    end
  end
end
