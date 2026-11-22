class HealthEpisodesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_episode, only: %i[show edit update recover reopen]

  def show
    prepare_show
  end

  def new
    @episode = current_user.family.health_episodes.build(
      user: current_user,
      started_on: parse_date(params[:date])
    )
    render_form
  end

  def edit; end

  def create
    @episode = current_user.family.health_episodes.build(episode_attributes)
    @episode.user = current_user.family.users.find(episode_params[:user_id].presence || current_user.id)

    if @episode.save
      redirect_to @episode, notice: '体調記録を追加しました'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @episode.user = current_user.family.users.find(episode_params[:user_id]) if episode_params.key?(:user_id)
    @episode.assign_attributes(episode_attributes)
    @episode.medications = family_medications if episode_params.key?(:medication_ids)

    if @episode.save
      redirect_to @episode, notice: '体調記録を更新しました'
    elsif episode_params.key?(:title)
      render :edit, status: :unprocessable_content
    else
      prepare_show
      render :show, status: :unprocessable_content
    end
  end

  def recover
    change_ended_on(Time.zone.today, '「直った」にしました')
  end

  def reopen
    change_ended_on(nil, '経過観察中に戻しました')
  end

  private

  def set_episode
    @episode = current_user.family.health_episodes.find(params.expect(:id))
  end

  def prepare_show
    @temperatures_by_date = @episode.health_episode_temperatures.order(measured_at: :desc)
                                    .group_by { |temperature| temperature.measured_at.to_date }
    @temperature = @episode.health_episode_temperatures.build
    @reminder_times = @episode.health_episode_reminder_times.ordered
    @medications = current_user.family.medications.ordered_by_name
  end

  def render_form
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'health_episodes/form',
                                                               locals: { episode: @episode })
      end
      format.html { render :new }
    end
  end

  def change_ended_on(date, notice)
    if @episode.update(ended_on: date)
      redirect_to @episode, notice: notice
    else
      redirect_to @episode, alert: @episode.errors.full_messages.to_sentence
    end
  end

  def episode_params
    params.expect(health_episode: [:user_id, :title, :started_on, :ended_on, :symptom_note,
                                   { medication_ids: [] }])
  end

  def episode_attributes
    episode_params.except(:user_id, :medication_ids)
  end

  def family_medications
    current_user.family.medications.where(id: Array(episode_params[:medication_ids]).compact_blank)
  end
end
