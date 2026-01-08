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
      user_ids = family.users.pluck(:id).map(&:to_s)
      return if user_ids.empty?

      week_start = Date.current.beginning_of_week
      week_end = Date.current.end_of_week

      completed_count = family.tasks.where(date: week_start..week_end, completed: true).count
      pending_count = family.tasks.where(date: week_start..week_end, completed: false).count

      send_notification(
        user_ids: user_ids,
        title: '📋 今週のタスクサマリ',
        message: "完了: #{completed_count}件 / 未完了: #{pending_count}件",
        url: weekly_summary_url
      )
    end

    private

    def send_notification(user_ids:, title:, message:, url:)
      return if ENV['ONESIGNAL_APP_ID'].blank? || ENV['ONESIGNAL_API_KEY'].blank?

      api_instance = OneSignal::DefaultApi.new

      notification = OneSignal::Notification.new(
        app_id: ENV.fetch('ONESIGNAL_APP_ID', nil),
        include_aliases: { 'external_id' => user_ids.map { |id| User.onesignal_external_id(id) } },
        target_channel: 'push',
        headings: { 'en' => title, 'ja' => title },
        contents: { 'en' => message, 'ja' => message }
      )

      notification.url = url if url.present?

      begin
        result = api_instance.create_notification(notification)
        Rails.logger.info("Weekly summary notification sent: #{result.id}")
        result
      rescue OneSignal::ApiError => e
        Rails.logger.error("OneSignal API error: #{e.message}")
        nil
      end
    end

    def weekly_summary_url
      Rails.application.routes.url_helpers.weekly_summary_url(host: ENV.fetch('APP_HOST', 'localhost'))
    end
  end
end
