# frozen_string_literal: true

# 設定時刻ちょうどの「枠」に送るべきリマインダを拾って送る。
#
# 時計は呼び出し側（`ReminderDispatcher::Runner` の常駐スレッド、または
# `reminders:dispatch` タスク）が持つ。ここは「今この瞬間に送るべきもの」を
# DB から引き、NotificationDispatch の UNIQUE 制約で二重送信を防ぐだけ。
class ReminderDispatcher
  # 枠を過ぎてから送ることを許す猶予
  GRACE = ENV.fetch('REMINDER_GRACE_MINUTES', 5).to_i.minutes
  # 時刻設定の刻み（分）
  SLOT_MINUTES = 30
  # 送信履歴の保持期間
  RETENTION = 30.days

  REMINDERS = [
    {
      kind: 'daily_review',
      enabled: :daily_review_reminder_enabled,
      hour: :daily_review_reminder_hour,
      minute: :daily_review_reminder_minute,
      notify: ->(user) { DailyReviewNotificationService.notify(user) }
    },
    {
      kind: 'family_calendar',
      enabled: :family_calendar_reminder_enabled,
      hour: :family_calendar_reminder_hour,
      minute: :family_calendar_reminder_minute,
      notify: ->(user) { FamilyCalendarNotificationService.notify(user) }
    },
    {
      kind: 'family_task_progress',
      enabled: :family_task_progress_reminder_enabled,
      hour: :family_task_progress_reminder_hour,
      minute: :family_task_progress_reminder_minute,
      notify: ->(user) { FamilyTaskStatusNotificationService.notify(user) }
    }
  ].freeze

  class << self
    def tick(now: Time.current)
      new(now: now).tick
    end

    def candidate_slots(reference = Time.current)
      new(now: reference).candidate_slots
    end
  end

  def initialize(now: Time.current)
    @now = now
  end

  # @return [Hash] { sent:, failed:, skipped: }
  def tick
    stats = { sent: 0, failed: 0, skipped: 0 }

    unless PushNotificationService.configured?
      Rails.logger.warn('ReminderDispatcher: OneSignal is not configured, skipping tick')
      return stats
    end

    ensure_settings_exist
    candidate_slots.each do |slot|
      REMINDERS.each do |reminder|
        settings_for(reminder, slot).find_each do |setting|
          dispatch(reminder, setting, slot, stats)
        end
      end
    end
    prune
    stats
  end

  # [now - GRACE, now] に含まれる 30分境界（通常0〜1件）
  def candidate_slots
    from = now - GRACE
    slot = now.change(min: now.min < SLOT_MINUTES ? 0 : SLOT_MINUTES, sec: 0)
    slot += SLOT_MINUTES.minutes while slot < from

    slots = []
    cursor = slot
    while cursor <= now
      slots << cursor
      cursor += SLOT_MINUTES.minutes
    end
    slots
  end

  private

  attr_reader :now

  def dispatch(reminder, setting, slot, stats)
    record = claim(reminder, setting, slot)
    if record.nil?
      stats[:skipped] += 1
      return
    end

    begin
      reminder[:notify].call(setting.user)
      record.mark_sent!
      stats[:sent] += 1
    rescue StandardError => e
      record.mark_failed!(e.message)
      stats[:failed] += 1
      Rails.logger.error(
        "ReminderDispatcher: #{reminder[:kind]} failed for user #{setting.user_id}: #{e.class}: #{e.message}"
      )
    end
  end

  def claim(reminder, setting, slot)
    NotificationDispatch.claim(kind: reminder[:kind], user_id: setting.user_id, slot_at: slot)
  rescue ActiveRecord::StatementInvalid => e
    # SQLite のロック競合。次の tick が猶予内なら拾い直す
    Rails.logger.warn("ReminderDispatcher: claim failed: #{e.class}: #{e.message}")
    nil
  end

  def settings_for(reminder, slot)
    UserNotificationSetting
      .where(reminder[:enabled] => true, reminder[:hour] => slot.hour, reminder[:minute] => slot.min)
      .includes(:user)
  end

  # 設定行は設定画面を開いたときに遅延生成されるため、無いユーザーは既定値で作る
  def ensure_settings_exist
    User.where.missing(:notification_setting).find_each(&:create_notification_setting!)
  end

  def prune
    NotificationDispatch.where(created_at: ...RETENTION.ago).delete_all
  end
end
