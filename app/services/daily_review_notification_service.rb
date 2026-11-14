# frozen_string_literal: true

class DailyReviewNotificationService
  class << self
    def notify(user)
      PushNotificationService.send_to_user(
        user_id: user.id,
        title: '🌙 一日のふりかえり',
        message: '今日のタスクと食事を記録しましょう',
        url: daily_review_url
      )
    end

    private

    def daily_review_url
      Rails.application.routes.url_helpers.daily_review_url(host: ENV.fetch('APP_HOST', 'localhost'))
    end
  end
end
