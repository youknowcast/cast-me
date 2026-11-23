# frozen_string_literal: true

class FamilyCalendarNotificationService
  class << self
    def notify(user)
      PushNotificationService.deliver(
        user_ids: [user.id],
        title: '今日の予定を確認しましょう',
        message: '家族のカレンダーをチェックする時間です'
      )
    end
  end
end
