# frozen_string_literal: true

# == Schema Information
#
# Table name: notification_dispatches
#
#  id         :integer          not null, primary key
#  attempts   :integer          not null, default 0
#  claimed_at :datetime         not null
#  error      :string
#  kind       :string           not null
#  sent_at    :datetime
#  slot_at    :datetime         not null
#  slot_key   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_notification_dispatches_on_created_at  (created_at)
#  index_notification_dispatches_on_slot_key    (slot_key) UNIQUE
#  index_notification_dispatches_on_user_id     (user_id)
#
# 送信済みの「枠」を記録するテーブル。
# slot_key の UNIQUE 制約が、デプロイ中のコンテナ併存や多重起動でも
# 二重送信しないための一次的な排他機構になる。
class NotificationDispatch < ApplicationRecord
  # 送信中にプロセスが落ちた claim を奪い直すまでの猶予
  STALE_AFTER = 2.minutes

  class << self
    # 枠の所有権を取れたときだけレコードを返す。取れなければ nil。
    def claim(kind:, user_id:, slot_at:)
      key = build_key(kind, user_id, slot_at)
      now = Time.current

      # セーブポイントを切らないと、UNIQUE 違反のあと同じトランザクションで
      # 後続のクエリが失敗するアダプタがある（PostgreSQL など）
      transaction(requires_new: true) do
        create!(slot_key: key, kind: kind, user_id: user_id, slot_at: slot_at,
                claimed_at: now, attempts: 0)
      end
    rescue ActiveRecord::RecordNotUnique
      reclaim(key, now)
    end

    def build_key(kind, user_id, slot_at)
      "#{kind}:#{user_id}:#{slot_at.utc.strftime('%Y%m%d%H%M')}"
    end

    private

    def reclaim(key, now)
      record = find_by(slot_key: key)
      return nil if record.nil?
      return nil if record.sent_at.present?
      return nil if record.claimed_at > now - STALE_AFTER

      updated = where(id: record.id, claimed_at: record.claimed_at)
                .update_all(claimed_at: now, attempts: record.attempts + 1, error: nil, updated_at: now)
      return nil if updated.zero?

      record.reload
    end
  end

  def mark_sent!(time = Time.current)
    update!(sent_at: time, error: nil)
  end

  def mark_failed!(message)
    update!(error: message.to_s.truncate(250))
  end
end
