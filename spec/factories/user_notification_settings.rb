# frozen_string_literal: true

FactoryBot.define do
  factory :user_notification_setting do
    association :user
    family_calendar_reminder_enabled { false }
    family_calendar_reminder_hour { nil }
    family_calendar_reminder_minute { 0 }
    family_task_progress_reminder_enabled { false }
    family_task_progress_reminder_hour { nil }
    family_task_progress_reminder_minute { 0 }
    daily_review_reminder_enabled { true }
    daily_review_reminder_hour { 19 }
    daily_review_reminder_minute { 0 }

    trait :with_calendar_reminder do
      family_calendar_reminder_enabled { true }
      family_calendar_reminder_hour { 8 }
    end

    trait :with_task_progress_reminder do
      family_task_progress_reminder_enabled { true }
      family_task_progress_reminder_hour { 18 }
    end

    trait :with_daily_review_reminder do
      daily_review_reminder_enabled { true }
      daily_review_reminder_hour { 21 }
      daily_review_reminder_minute { 30 }
    end

    trait :without_daily_review_reminder do
      daily_review_reminder_enabled { false }
      daily_review_reminder_hour { nil }
    end
  end
end
