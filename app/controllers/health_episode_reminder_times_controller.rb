class HealthEpisodeReminderTimesController < ApplicationController
  before_action :authenticate_user!

  def create
    episode = find_episode
    hour, minute = parse_time(params[:reminder_time])
    reminder_time = episode.health_episode_reminder_times.find_or_initialize_by(hour: hour, minute: minute)

    if reminder_time.save
      redirect_to episode, notice: '通知時刻を追加しました'
    else
      redirect_to episode, alert: reminder_time.errors.full_messages.to_sentence
    end
  end

  def destroy
    episode = find_episode
    episode.health_episode_reminder_times.find(params.expect(:id)).destroy
    redirect_to episode, notice: '通知時刻を削除しました'
  end

  private

  def find_episode
    current_user.family.health_episodes.find(params.expect(:health_episode_id))
  end

  def parse_time(value)
    hour, minute = value.to_s.split(':').map(&:to_i)
    [hour.to_i, minute.to_i]
  end
end
