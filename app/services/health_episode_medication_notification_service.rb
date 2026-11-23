# frozen_string_literal: true

# 体調エピソードの服薬リマインド。同じ対象者・同じ枠のエピソードは1通にまとめる。
class HealthEpisodeMedicationNotificationService
  KIND = 'health_episode_medication'
  TITLE = '服薬の時間です'
  MAX_MESSAGE_LENGTH = 180

  class << self
    # @return [Hash{User => Array<HealthEpisode>}] 枠に一致する進行中エピソードを対象者ごとにまとめたもの
    def targets_for(slot)
      episodes_at(slot).group_by(&:user)
    end

    def notify(user, episodes)
      PushNotificationService.deliver(
        user_ids: [user.id],
        title: TITLE,
        message: message_for(episodes)
      )
    end

    def message_for(episodes)
      details = episodes.map { |episode| detail_for(episode) }.join(' / ')
      "#{TITLE}（#{details}）".truncate(MAX_MESSAGE_LENGTH)
    end

    private

    def episodes_at(slot)
      HealthEpisode
        .active
        .where(started_on: ..slot.to_date)
        .joins(:health_episode_reminder_times)
        .where(health_episode_reminder_times: { hour: slot.hour, minute: slot.min })
        .includes(:user, :medications)
        .order(:id)
    end

    def detail_for(episode)
      names = episode.medications.map(&:name).sort
      names.empty? ? episode.title : "#{episode.title}: #{names.join('、')}"
    end
  end
end
