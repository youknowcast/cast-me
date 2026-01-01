class RegularTasksController < ApplicationController
  before_action :authenticate_user!

  # GET /regular_tasks - Family の全定型タスクを JSON で返す
  def index
    @regular_tasks = current_user.family.regular_tasks.order(:title)

    respond_to do |format|
      format.json do
        render json: @regular_tasks.map { |rt| { id: rt.id, title: rt.title } }
      end
    end
  end

  # POST /regular_tasks - 定型タスク作成
  def create
    @regular_task = current_user.family.regular_tasks.build(regular_task_params)

    if @regular_task.save
      respond_to do |format|
        format.json { render json: { id: @regular_task.id, title: @regular_task.title }, status: :created }
        format.html { redirect_back fallback_location: calendar_path, notice: "定型タスクを登録しました" }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @regular_task.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: calendar_path, alert: @regular_task.errors.full_messages.join(", ") }
      end
    end
  end

  private

  def regular_task_params
    params.require(:regular_task).permit(:title)
  end
end
