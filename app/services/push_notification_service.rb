# frozen_string_literal: true

class PushNotificationService
  class DeliveryError < StandardError; end

  class << self
    def configured?
      ENV['ONESIGNAL_APP_ID'].present? && ENV['ONESIGNAL_API_KEY'].present?
    end

    # 成否を呼び出し元に返す版。失敗は例外で伝える（リマインダのディスパッチャ用）
    def deliver(user_ids:, title:, message:, url: nil)
      return :skipped unless configured?

      api_instance = OneSignal::DefaultApi.new
      notification = OneSignal::Notification.new(
        app_id: ENV.fetch('ONESIGNAL_APP_ID', nil),
        include_aliases: { 'external_id' => user_ids.map { |id| User.onesignal_external_id(id) } },
        target_channel: 'push',
        headings: { 'en' => title, 'ja' => title },
        contents: { 'en' => message, 'ja' => message }
      )
      notification.url = url if url.present?

      api_instance.create_notification(notification)
      Rails.logger.info("PushNotificationService: sent to #{user_ids.join(',')}")
      :sent
    rescue OneSignal::ApiError => e
      Rails.logger.error("PushNotificationService error: #{e.message}")
      raise DeliveryError, e.message
    end

    def send_to_user(user_id:, title:, message:, url: nil)
      send_to_users(user_ids: [user_id], title: title, message: message, url: url)
    end

    def send_to_users(user_ids:, title:, message:, url: nil)
      deliver(user_ids: user_ids, title: title, message: message, url: url)
      nil
    rescue DeliveryError
      nil
    end
  end
end
