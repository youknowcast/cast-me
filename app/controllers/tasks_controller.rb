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

    set_scope
    @task = current_user.family.tasks.build(
      date: date,
      user_id: current_user.id
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { task: @task, scope: @scope })
      end
      format.html { render :new }
    end
  rescue Date::Error
    set_scope
    @task = current_user.family.tasks.build(
      date: Date.today,
      user_id: current_user.id
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { task: @task, scope: @scope })
      end
      format.html { render :new }
    end
  end

  def create
    @task = current_user.family.tasks.build(task_params)

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
      set_scope
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("side-panel", partial: "form", locals: { task: @task, scope: @scope }) }
        format.html { render :new }
      end
    end
  end

  def edit
    set_scope
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { task: @task, scope: @scope })
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
      set_scope
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("side-panel", partial: "form", locals: { task: @task, scope: @scope }) }
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

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(helpers.dom_id(@task), partial: "calendar/task_item", locals: { task: @task })
      end
      format.html { redirect_to calendar_path }
    end
  end

  private

  def set_task
    @task = current_user.family.tasks.find(params[:id])
  end

  def set_scope
    scope_param = params[:scope].to_s.downcase.strip
    if scope_param == 'my'
      @scope = 'my'
    elsif scope_param == 'family'
      @scope = 'family'
    else
      # Fallback logic
      @scope = (action_name == 'my' || params[:controller] == 'calendar' && action_name == 'my' ? 'my' : 'family')
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :date, :priority, :user_id)
  end
end