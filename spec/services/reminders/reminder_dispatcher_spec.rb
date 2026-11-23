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
      allow(DailyReviewNotificationService).to receive(:notify).and_call_original
      allow(PushNotificationService).to receive(:deliver) do |user_ids:, **|
        raise PushNotificationService::DeliveryError, 'boom' if user_ids == [user.id]

        :sent
      end

      result = described_class.tick(now: slot)

      failed = NotificationDispatch.find_by(user_id: user.id)
      expect(result[:failed]).to eq(1)
      expect(failed.error).to eq('boom')
      expect(failed.sent_at).to be_nil
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

  describe 'health episode medication reminders' do
    before { allow(PushNotificationService).to receive(:deliver).and_return(:sent) }

    def add_reminder_time(episode, slot)
      create(:health_episode_reminder_time, health_episode: episode, hour: slot.hour, minute: slot.min)
    end

    it 'sends one reminder to the episode subject at the matching slot' do
      episode = create(:health_episode, family: family, user: user, title: 'インフルエンザ',
                                        started_on: slot.to_date)
      add_reminder_time(episode, slot)

      described_class.tick(now: slot)

      expect(PushNotificationService).to have_received(:deliver)
        .with(hash_including(user_ids: [user.id])).once
      expect(NotificationDispatch.find_by(kind: 'health_episode_medication', user_id: user.id).sent_at)
        .to be_present
    end

    it 'does not send at a slot without a matching reminder time' do
      episode = create(:health_episode, family: family, user: user, started_on: slot.to_date)
      add_reminder_time(episode, slot + 30.minutes)

      described_class.tick(now: slot)

      expect(PushNotificationService).not_to have_received(:deliver)
    end

    it 'merges several episodes of the same subject into one notification' do
      first = create(:health_episode, family: family, user: user, title: 'インフルエンザ',
                                      started_on: slot.to_date)
      second = create(:health_episode, family: family, user: user, title: '発熱',
                                       started_on: slot.to_date)
      add_reminder_time(first, slot)
      add_reminder_time(second, slot)

      described_class.tick(now: slot)

      expect(PushNotificationService).to have_received(:deliver).once
      expect(PushNotificationService).to have_received(:deliver)
        .with(hash_including(user_ids: [user.id], message: include('インフルエンザ').and(include('発熱'))))
    end

    it 'skips recovered and not yet started episodes' do
      recovered = create(:health_episode, family: family, user: user, started_on: slot.to_date - 3.days,
                                          ended_on: slot.to_date - 1.day)
      upcoming = create(:health_episode, family: family, user: user, started_on: slot.to_date + 1.day)
      add_reminder_time(recovered, slot)
      add_reminder_time(upcoming, slot)

      described_class.tick(now: slot)

      expect(PushNotificationService).not_to have_received(:deliver)
      expect(NotificationDispatch.where(kind: 'health_episode_medication')).to be_empty
    end

    it 'sends only to the episode subject, never to another family member' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      episode = create(:health_episode, family: other_family, user: other_user, started_on: slot.to_date)
      add_reminder_time(episode, slot)

      described_class.tick(now: slot)

      expect(PushNotificationService).not_to have_received(:deliver)
        .with(hash_including(user_ids: [user.id]))
      expect(PushNotificationService).to have_received(:deliver)
        .with(hash_including(user_ids: [other_user.id])).once
    end

    it 'sends only once even if the same slot is ticked twice' do
      episode = create(:health_episode, family: family, user: user, started_on: slot.to_date)
      add_reminder_time(episode, slot)

      2.times { described_class.tick(now: slot) }

      expect(PushNotificationService).to have_received(:deliver).once
      expect(NotificationDispatch.where(kind: 'health_episode_medication').count).to eq(1)
    end

    it 'records the error and keeps ticking when a delivery fails' do
      other_user = create(:user, family: family)
      failing = create(:health_episode, family: family, user: user, started_on: slot.to_date)
      ok = create(:health_episode, family: family, user: other_user, started_on: slot.to_date)
      [failing, ok].each { |episode| add_reminder_time(episode, slot) }
      allow(PushNotificationService).to receive(:deliver) do |user_ids:, **|
        raise PushNotificationService::DeliveryError, 'boom' if user_ids == [user.id]

        :sent
      end

      result = described_class.tick(now: slot)

      failed = NotificationDispatch.find_by(kind: 'health_episode_medication', user_id: user.id)
      expect(result[:failed]).to eq(1)
      expect(failed.error).to eq('boom')
      expect(failed.sent_at).to be_nil
      expect(NotificationDispatch.find_by(kind: 'health_episode_medication', user_id: other_user.id).sent_at)
        .to be_present
    end

    it 'includes the disease and medication names in the message' do
      episode = create(:health_episode, family: family, user: user, title: 'インフルエンザ',
                                        started_on: slot.to_date)
      create(:health_episode_medication, health_episode: episode,
                                         medication: create(:medication, family: family, name: 'ロキソニン'))
      create(:health_episode_medication, health_episode: episode,
                                         medication: create(:medication, family: family, name: 'カロナール'))
      add_reminder_time(episode, slot)

      described_class.tick(now: slot)

      expect(PushNotificationService).to have_received(:deliver)
        .with(hash_including(message: include('インフルエンザ').and(include('ロキソニン')).and(include('カロナール'))))
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
