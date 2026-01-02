class TasksController < ApplicationController
  include CalendarData
  before_action :authenticate_user!
  before_action :set_task, only: %i[show edit update destroy toggle]

  def index
    @tasks = current_user.tasks.for_date(params[:date]).ordered_by_priority
  end

  def show; end

  def new
    date = if params[:date].present?
             Date.parse(params[:date])
           else
             Time.zone.today
           end

    @task = current_user.family.tasks.build(
      date: date,
      user_id: current_user.id
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form',
                                                               locals: { task: @task, scope: current_scope })
      end
      format.html { render :new }
    end
  rescue Date::Error
    @task = current_user.family.tasks.build(
      date: Time.zone.today,
      user_id: current_user.id
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form',
                                                               locals: { task: @task, scope: current_scope })
      end
      format.html { render :new }
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form',
                                                               locals: { task: @task, scope: current_scope })
      end
      format.html { render :edit }
    end
  end

  def create
    @task = current_user.family.tasks.build(task_params)

    if @task.save
      # 定型タスク登録が有効な場合
      if params[:register_regular_task] == 'true' && @task.title.present?
        register_or_increment_regular_task(@task.title)
      end

      set_calendar_data(@task.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date }),
            turbo_stream.replace("calendar-cell-#{@task.date}",
                                 partial: 'calendar/calendar_grid_cell',
                                 locals: { day: @task.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                           scope: current_scope }),
            turbo_stream.update('side-panel', '')
          ]
        end
        format.html { redirect_to calendar_path, notice: 'タスクを作成しました' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('side-panel', partial: 'form',
                                                                  locals: { task: @task, scope: current_scope })
        end
        format.html { render :new }
      end
    end
  end

  def update
    if @task.update(task_params)
      set_calendar_data(@task.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date }),
            turbo_stream.replace("calendar-cell-#{@task.date}",
                                 partial: 'calendar/calendar_grid_cell',
                                 locals: { day: @task.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                           scope: current_scope }),
            turbo_stream.update('side-panel', '')
          ]
        end
        format.html { redirect_to calendar_path, notice: 'タスクを更新しました' }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace('side-panel', partial: 'form',
                                                                  locals: { task: @task, scope: current_scope })
        end
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
        render turbo_stream: [
          turbo_stream.update('daily_details', partial: 'calendar/daily_view',
                                               locals: { date: @date }),
          turbo_stream.replace("calendar-cell-#{date}",
                               partial: 'calendar/calendar_grid_cell',
                               locals: { day: date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                         scope: current_scope })
        ]
      end
      format.html { redirect_to calendar_path, notice: 'タスクを削除しました' }
    end
  end

  def toggle
    @task.update(completed: !@task.completed)

    set_calendar_data(@task.date)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(@task), partial: 'calendar/task_item',
                                                      locals: { task: @task }),
          turbo_stream.replace("calendar-cell-#{@task.date}",
                               partial: 'calendar/calendar_grid_cell',
                               locals: { day: @task.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                         scope: current_scope })
        ]
      end
      format.html { redirect_to calendar_path }
    end
  end

  private

  def set_task
    @task = current_user.family.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :date, :priority, :user_id)
  end

  def register_or_increment_regular_task(title)
    regular_task = current_user.family.regular_tasks.find_or_create_by!(title: title)
    regular_task.increment_usage_for!(current_user)
  rescue ActiveRecord::RecordInvalid
    # タイトルが無効な場合は無視
  end
end
