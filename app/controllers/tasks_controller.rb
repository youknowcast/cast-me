class TasksController < ApplicationController
  include CalendarData

  before_action :authenticate_user!
  before_action :set_task, only: %i[show edit update destroy toggle]

  def index = @tasks = current_user.tasks.for_date(params[:date]).ordered_by_priority

  def show; end

  def new
    @task = current_user.family.tasks.build(date: parse_date(params[:date]), user_id: current_user.id)

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
      if params[:register_regular_task] == 'true' && @task.title.present?
        register_or_increment_regular_task(@task.title)
      end

      set_calendar_data(@task.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            daily_view_stream,
            grid_cell_stream(@task.date),
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
            daily_view_stream,
            grid_cell_stream(@task.date),
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
    destroyed = @task.destroy
    set_calendar_data(date)

    respond_to do |format|
      format.turbo_stream do
        if destroyed
          render turbo_stream: [daily_view_stream, grid_cell_stream(date)]
        else
          head :unprocessable_entity
        end
      end
      format.html { redirect_to calendar_path, (destroyed ? { notice: 'タスクを削除しました' } : { alert: 'タスクを削除できませんでした' }) }
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
          grid_cell_stream(@task.date)
        ]
      end
      format.html { redirect_to calendar_path }
    end
  end

  private

  # 選択中の日付の詳細ビューを更新する turbo_stream
  def daily_view_stream
    turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date })
  end

  # 指定日のカレンダーセルを差し替える turbo_stream
  def grid_cell_stream(day)
    turbo_stream.replace("calendar-cell-#{day}",
                         partial: 'calendar/calendar_grid_cell',
                         locals: { day: day, date: @date, plans: @family_plans, tasks: @family_tasks,
                                   scope: current_scope, holidays: @holidays })
  end

  def set_task = @task = current_user.family.tasks.find(params[:id])

  def task_params = params.expect(task: %i[title description date priority user_id completed])

  def register_or_increment_regular_task(title)
    regular_task = current_user.family.regular_tasks.find_or_create_by!(title: title)
    regular_task.increment_usage_for!(current_user)
  rescue ActiveRecord::RecordInvalid
    nil
  end
end
