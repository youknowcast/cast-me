class HealthEpisodeTemperaturesController < ApplicationController
  before_action :authenticate_user!

  def create
    episode = find_episode
    temperature = episode.health_episode_temperatures.build(temperature_params)

    if temperature.save
      redirect_to after_create_path(episode), notice: '体温を記録しました'
    else
      redirect_to after_create_path(episode), alert: temperature.errors.full_messages.to_sentence
    end
  end

  def update
    episode = find_episode
    temperature = episode.health_episode_temperatures.find(params.expect(:id))

    if temperature.update(temperature_params)
      redirect_to episode, notice: '体温を更新しました'
    else
      redirect_to episode, alert: temperature.errors.full_messages.to_sentence
    end
  end

  def destroy
    episode = find_episode
    episode.health_episode_temperatures.find(params.expect(:id)).destroy
    redirect_to episode, notice: '体温を削除しました'
  end

  private

  def find_episode
    current_user.family.health_episodes.find(params.expect(:health_episode_id))
  end

  def after_create_path(episode)
    case params[:return_to]
    when 'calendar' then calendar_path(date: params[:date])
    when 'my_calendar' then my_calendar_path(date: params[:date])
    else health_episode_path(episode)
    end
  end

  def temperature_params
    params.expect(health_episode_temperature: %i[measured_at value])
  end
end
