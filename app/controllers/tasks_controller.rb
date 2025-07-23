class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :edit, :update, :destroy, :toggle]

  def index
    @tasks = current_user.tasks.for_date(params[:date]).ordered_by_priority
  end

  def show
  end

  def new
    @task = current_user.tasks.build(
      date: params[:date] ? Date.parse(params[:date]) : Date.today,
      family: current_user.family
    )
  end

  def create
    @task = current_user.tasks.build(task_params)
    @task.family = current_user.family

    if @task.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
              locals: { date: @task.date, plans: current_user.family.plans.for_date(@task.date).ordered_by_time, tasks: current_user.tasks.for_date(@task.date).ordered_by_priority }),
            turbo_stream.update("modal", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "タスクを作成しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("modal", partial: "form") }
        format.html { render :new }
      end
    end
  end

  def edit
  end

  def update
    if @task.update(task_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
              locals: { date: @task.date, plans: current_user.family.plans.for_date(@task.date).ordered_by_time, tasks: current_user.tasks.for_date(@task.date).ordered_by_priority }),
            turbo_stream.update("modal", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "タスクを更新しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("modal", partial: "form") }
        format.html { render :edit }
      end
    end
  end

  def destroy
    date = @task.date
    @task.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
          locals: { date: date, plans: current_user.family.plans.for_date(date).ordered_by_time, tasks: current_user.tasks.for_date(date).ordered_by_priority })
      end
      format.html { redirect_to calendar_path, notice: "タスクを削除しました" }
    end
  end

  def toggle
    @task.update(completed: !@task.completed)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
          locals: { date: @task.date, plans: current_user.family.plans.for_date(@task.date).ordered_by_time, tasks: current_user.tasks.for_date(@task.date).ordered_by_priority })
      end
      format.html { redirect_to calendar_path }
    end
  end

  private

  def set_task
    @task = current_user.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :date, :priority)
  end
end 