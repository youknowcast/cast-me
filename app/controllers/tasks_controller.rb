class TasksController < ApplicationController
  include CalendarData
  before_action :authenticate_user!
  before_action :set_task, only: [:show, :edit, :update, :destroy, :toggle]

  def index
    @tasks = current_user.tasks.for_date(params[:date]).ordered_by_priority
  end

  def show
  end

  def new
    date = if params[:date].present?
             Date.parse(params[:date])
           else
             Date.today
           end

    @task = current_user.tasks.build(
      date: date,
      family: current_user.family
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { task: @task })
      end
      format.html { render :new }
    end
  rescue Date::Error
    # 無効な日付の場合は今日の日付を使用
    @task = current_user.tasks.build(
      date: Date.today,
      family: current_user.family
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { task: @task })
      end
      format.html { render :new }
    end
  end

  def create
    @task = current_user.tasks.build(task_params)
    @task.family = current_user.family

    if @task.save
      set_calendar_data(@task.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date }),
            turbo_stream.update("side-panel", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "タスクを作成しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("side-panel", partial: "form") }
        format.html { render :new }
      end
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { task: @task })
      end
      format.html { render :edit }
    end
  end

  def update
    if @task.update(task_params)
      set_calendar_data(@task.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date }),
            turbo_stream.update("side-panel", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "タスクを更新しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("side-panel", partial: "form") }
        format.html { render :edit }
      end
    end
  end

  def destroy
    date = @task.date
    @task.destroy
    set_calendar_data(date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date })
      end
      format.html { redirect_to calendar_path, notice: "タスクを削除しました" }
    end
  end

  def toggle
    @task.update(completed: !@task.completed)
    set_calendar_data(@task.date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date })
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