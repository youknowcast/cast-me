# frozen_string_literal: true

class FamilyCallNotificationService
  class << self
    def notify(caller:, target_user:, message:)
      PushNotificationService.send_to_user(
        user_id: target_user.id,
        title: "#{caller.display_name} からの呼び出し",
        message: message
      )
    end
  end
end
