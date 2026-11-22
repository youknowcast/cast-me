class MedicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_medication, only: %i[update]

  def index
    @medication = current_user.family.medications.build
    @medications = current_user.family.medications.ordered_by_name
  end

  def create
    @medication = current_user.family.medications.build(medication_params)

    if @medication.save
      attach_to_episode(@medication)
      redirect_to return_path, notice: '服薬を追加しました'
    elsif episode
      redirect_to return_path, alert: @medication.errors.full_messages.to_sentence
    else
      @medications = current_user.family.medications.ordered_by_name
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @medication.update(medication_params)
      redirect_to medications_path, notice: '服薬を更新しました'
    else
      @medications = current_user.family.medications.ordered_by_name
      render :index, status: :unprocessable_content
    end
  end

  private

  def set_medication
    @medication = current_user.family.medications.find(params.expect(:id))
  end

  def medication_params
    params.expect(medication: %i[name])
  end

  def episode
    return if params[:health_episode_id].blank?

    if defined?(@episode)
      @episode
    else
      @episode = current_user.family.health_episodes.find_by(id: params[:health_episode_id])
    end
  end

  def attach_to_episode(medication)
    episode&.health_episode_medications&.find_or_create_by(medication: medication)
  end

  def return_path
    episode ? health_episode_path(episode) : medications_path
  end
end
