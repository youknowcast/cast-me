# frozen_string_literal: true

class PlanNotificationService
  class << self
    # 予定に新規追加された参加者に通知を送信
    #
    # @param plan [Plan] 通知対象の予定
    # @param added_user_ids [Array<Integer>] 新規追加された参加者のユーザーID
    # @param excluded_user_id [Integer] 通知から除外するユーザーID（通常は作成者/編集者）
    def notify_new_participants(plan:, added_user_ids:, excluded_user_id:)
      target_user_ids = added_user_ids.map(&:to_s) - [excluded_user_id.to_s]
      return if target_user_ids.empty?

      send_notification(
        user_ids: target_user_ids,
        title: '新しい予定に追加されました',
        message: "「#{plan.title}」（#{I18n.l(plan.date, format: :short)}）",
        url: nil # 将来的にカレンダーページへのリンクを設定可能
      )
    rescue StandardError => e
      Rails.logger.error("PlanNotificationService error: #{e.message}")
    end

    private

    def send_notification(user_ids:, title:, message:, url: nil)
      PushNotificationService.send_to_users(
        user_ids: user_ids,
        title: title,
        message: message,
        url: url
      )
    end
  end
end
