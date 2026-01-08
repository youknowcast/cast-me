# frozen_string_literal: true

class PushNotificationService
  class << self
    def send_to_user(user_id:, title:, message:, url: nil)
      send_to_users(user_ids: [user_id], title: title, message: message, url: url)
    end

    def send_to_users(user_ids:, title:, message:, url: nil)
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
        Rails.logger.info("PushNotificationService: sent #{result.id}")
        result
      rescue OneSignal::ApiError => e
        Rails.logger.error("PushNotificationService error: #{e.message}")
        nil
      end
    end
  end
end
