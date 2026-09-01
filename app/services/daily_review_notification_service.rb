# frozen_string_literal: true

class DailyReviewNotificationService
  class << self
    def notify_all
      user_ids = User.pluck(:id)
      return { count: 0 } if user_ids.empty?

      PushNotificationService.send_to_users(
        user_ids: user_ids,
        title: '🌙 一日のふりかえり',
        message: '今日のタスクと食事を記録しましょう',
        url: daily_review_url
      )
      { count: user_ids.count }
    end

    private

    def daily_review_url
      Rails.application.routes.url_helpers.daily_review_url(host: ENV.fetch('APP_HOST', 'localhost'))
    end
  end
end
