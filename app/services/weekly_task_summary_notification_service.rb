# frozen_string_literal: true

class WeeklyTaskSummaryNotificationService
  class << self
    def notify_all_families
      count = 0
      Family.find_each do |family|
        notify_family(family)
        count += 1
      end
      { count: count }
    end

    def notify_family(family)
      user_ids = family.users.pluck(:id)
      return if user_ids.empty?

      week_start = Date.current.beginning_of_week
      week_end = Date.current.end_of_week

      completed_count = family.tasks.where(date: week_start..week_end, completed: true).count
      pending_count = family.tasks.where(date: week_start..week_end, completed: false).count

      PushNotificationService.send_to_users(
        user_ids: user_ids,
        title: '📋 今週のタスクサマリ',
        message: "完了: #{completed_count}件 / 未完了: #{pending_count}件",
        url: weekly_summary_url
      )
    end

    private

    def weekly_summary_url
      Rails.application.routes.url_helpers.weekly_summary_url(host: ENV.fetch('APP_HOST', 'localhost'))
    end
  end
end
