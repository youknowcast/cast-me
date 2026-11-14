# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReminderDispatcher, type: :service do
  let(:family) { create(:family) }
  let!(:user) { create(:user, family: family) }
  let(:slot) { Time.zone.local(2026, 11, 14, 21, 30) }

  before do
    allow(PushNotificationService).to receive(:configured?).and_return(true)
    allow(DailyReviewNotificationService).to receive(:notify)
    allow(FamilyCalendarNotificationService).to receive(:notify)
    allow(FamilyTaskStatusNotificationService).to receive(:notify)
  end

  describe '.tick' do
    it 'sends the daily review reminder at the configured slot' do
      create(:user_notification_setting, :with_daily_review_reminder, user: user)

      described_class.tick(now: slot)

      expect(DailyReviewNotificationService).to have_received(:notify).with(user).once
      expect(NotificationDispatch.where(kind: 'daily_review').count).to eq(1)
    end

    it 'does not send at another time of day' do
      create(:user_notification_setting, :with_daily_review_reminder, user: user)

      described_class.tick(now: slot - 30.minutes)

      expect(DailyReviewNotificationService).not_to have_received(:notify)
    end

    it 'sends each reminder only once even if the tick runs twice' do
      create(:user_notification_setting, :with_daily_review_reminder, user: user)

      2.times { described_class.tick(now: slot) }

      expect(DailyReviewNotificationService).to have_received(:notify).once
    end

    it 'still sends when the tick is within the grace window' do
      create(:user_notification_setting, :with_daily_review_reminder, user: user)

      described_class.tick(now: slot + 5.minutes)

      expect(DailyReviewNotificationService).to have_received(:notify).once
    end

    it 'drops a slot that is older than the grace window' do
      create(:user_notification_setting, :with_daily_review_reminder, user: user)

      described_class.tick(now: slot + 6.minutes)

      expect(DailyReviewNotificationService).not_to have_received(:notify)
      expect(NotificationDispatch.count).to eq(0)
    end

    it 'keeps going when one delivery fails' do
      other_user = create(:user, family: family)
      create(:user_notification_setting, :with_daily_review_reminder, user: user)
      create(:user_notification_setting, :with_daily_review_reminder, user: other_user)
      allow(DailyReviewNotificationService).to receive(:notify).with(user)
                                                               .and_raise(PushNotificationService::DeliveryError, 'boom')

      result = described_class.tick(now: slot)

      expect(DailyReviewNotificationService).to have_received(:notify).with(other_user)
      expect(result[:failed]).to eq(1)
      expect(NotificationDispatch.find_by(user_id: user.id).error).to eq('boom')
      expect(NotificationDispatch.find_by(user_id: other_user.id).sent_at).to be_present
    end

    it 'creates a missing settings row and applies the default 19:00 reminder' do
      allow(DailyReviewNotificationService).to receive(:notify)

      described_class.tick(now: Time.zone.local(2026, 11, 14, 19, 0))

      expect(user.notification_setting).to be_present
      expect(DailyReviewNotificationService).to have_received(:notify).with(user)
    end

    it 'sends nothing and records nothing when OneSignal is not configured' do
      allow(PushNotificationService).to receive(:configured?).and_return(false)
      create(:user_notification_setting, :with_daily_review_reminder, user: user)

      described_class.tick(now: slot)

      expect(DailyReviewNotificationService).not_to have_received(:notify)
      expect(NotificationDispatch.count).to eq(0)
    end

    it 'sends the calendar and task progress reminders from their own columns' do
      calendar_user = create(:user, family: family)
      task_user = create(:user, family: family)
      create(:user_notification_setting, :with_calendar_reminder, user: calendar_user,
                                                                  family_calendar_reminder_hour: 8)
      create(:user_notification_setting, :with_task_progress_reminder, user: task_user,
                                                                       family_task_progress_reminder_hour: 18)

      described_class.tick(now: Time.zone.local(2026, 11, 14, 8, 0))
      described_class.tick(now: Time.zone.local(2026, 11, 14, 18, 0))

      expect(FamilyCalendarNotificationService).to have_received(:notify).with(calendar_user).once
      expect(FamilyTaskStatusNotificationService).to have_received(:notify).with(task_user).once
    end

    it 'removes dispatch records older than 30 days' do
      old = create(:user_notification_setting, :with_daily_review_reminder, user: user)
      NotificationDispatch.create!(slot_key: 'old:1:202601010000', kind: 'old', user_id: old.user_id,
                                   slot_at: 40.days.ago, claimed_at: 40.days.ago, attempts: 0,
                                   created_at: 40.days.ago, updated_at: 40.days.ago)

      described_class.tick(now: slot)

      expect(NotificationDispatch.where(kind: 'old')).to be_empty
    end
  end

  describe '.candidate_slots' do
    it 'returns the half hour boundary that just passed' do
      now = Time.zone.local(2026, 11, 14, 21, 33)

      expect(described_class.candidate_slots(now)).to eq([Time.zone.local(2026, 11, 14, 21, 30)])
    end

    it 'returns nothing once the last boundary left the grace window' do
      now = Time.zone.local(2026, 11, 14, 21, 26)

      expect(described_class.candidate_slots(now)).to eq([])
    end
  end
end
