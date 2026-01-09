class TaskTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_everyday_task_template
  before_action :set_task_template, only: %i[edit update destroy]

  def new
    @task_template = @everyday_task_template.task_templates.build
  end

  def edit; end

  def create
    @task_template = @everyday_task_template.task_templates.build(task_template_params)

    if @task_template.save
      redirect_to everyday_task_template_path(@everyday_task_template), notice: 'タスクTemplateを追加しました'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @task_template.update(task_template_params)
      redirect_to everyday_task_template_path(@everyday_task_template), notice: 'タスクTemplateを更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task_template.destroy
    redirect_to everyday_task_template_path(@everyday_task_template), notice: 'タスクTemplateを削除しました'
  end

  private

  def set_everyday_task_template
    @everyday_task_template = current_user.family.everyday_task_templates.find(params[:everyday_task_template_id])
  end

  def set_task_template
    @task_template = @everyday_task_template.task_templates.find(params[:id])
  end

  def task_template_params
    params.expect(task_template: %i[user_id title description priority])
  end
end
