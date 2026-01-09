class EverydayTaskTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_everyday_task_template, only: %i[show edit update destroy bulk_add]

  def index
    @everyday_task_templates = current_user.family.everyday_task_templates.order(:created_at)
  end

  def show
    @task_templates = @everyday_task_template.task_templates.order(:priority)
  end

  def new
    @everyday_task_template = current_user.family.everyday_task_templates.build
  end

  def edit; end

  def create
    @everyday_task_template = current_user.family.everyday_task_templates.build(everyday_task_template_params)

    if @everyday_task_template.save
      redirect_to everyday_task_templates_path, notice: '毎日のタスクセットを作成しました'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @everyday_task_template.update(everyday_task_template_params)
      redirect_to everyday_task_templates_path, notice: '毎日のタスクセットを更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @everyday_task_template.destroy
    redirect_to everyday_task_templates_path, notice: '毎日のタスクセットを削除しました'
  end

  def bulk_add
    date = @date

    Task.transaction do
      @everyday_task_template.task_templates.each do |template|
        Task.create!(
          family: current_user.family,
          user_id: template.user_id,
          task_template: template,
          title: template.title,
          description: template.description,
          priority: template.priority,
          date: date
        )
      end
    end

    respond_to do |format|
      format.json { render json: { message: 'タスクを一括登録しました' }, status: :ok }
      format.html { redirect_back fallback_location: calendar_path(date: date), notice: 'タスクを一括登録しました' }
    end
  rescue StandardError => e
    Rails.logger.error "Bulk Add Failed: #{e.message}"
    respond_to do |format|
      format.json { render json: { error: '一括登録に失敗しました' }, status: :unprocessable_entity }
      format.html { redirect_back fallback_location: calendar_path(date: date), alert: '一括登録に失敗しました' }
    end
  end

  private

  def set_everyday_task_template
    @everyday_task_template = current_user.family.everyday_task_templates.find(params[:id])
  end

  def everyday_task_template_params
    params.expect(everyday_task_template: [:name])
  end
end
