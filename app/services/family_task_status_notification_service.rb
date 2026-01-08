# frozen_string_literal: true

class FamilyTaskStatusNotificationService
  class << self
    def notify(user)
      family = user.family
      today = Date.current
      tasks = Task.where(family_id: family.id, date: today)
      completed = tasks.where(completed: true).count
      pending = tasks.where(completed: false).count

      PushNotificationService.send_to_user(
        user_id: user.id,
        title: '今日のタスク状況',
        message: "家族のタスク状況 済/未: #{completed} / #{pending} 件"
      )
    end
  end
end
