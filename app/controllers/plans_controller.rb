class PlansController < ApplicationController
  include CalendarData
  before_action :authenticate_user!
  before_action :set_plan, only: %i[show edit update destroy]

  def index
    @plans = current_user.family.plans.for_date(params[:date]).ordered_by_time
  end

  def show; end

  def new
    date = if params[:date].present?
             Date.parse(params[:date])
           else
             Time.zone.today
           end

    @plan = current_user.family.plans.build(
      date: date,
      created_by: current_user
    )
    # Myスコープの場合、自分自身をデフォルト参加者として設定
    @plan.participant_ids = [current_user.id] if my_scope?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form', locals: { plan: @plan })
      end
      format.html { render :new }
    end
  rescue Date::Error
    # 無効な日付の場合は今日の日付を使用
    @plan = current_user.family.plans.build(
      date: Time.zone.today,
      created_by: current_user
    )
    @plan.participant_ids = [current_user.id] if my_scope?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form', locals: { plan: @plan })
      end
      format.html { render :new }
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form', locals: { plan: @plan })
      end
      format.html { render :edit }
    end
  end

  def create
    @plan = current_user.family.plans.build(plan_params)
    @plan.created_by = current_user
    @plan.last_edited_by = current_user

    # 参加者チェック
    if participant_ids_from_params.empty?
      @plan.errors.add(:base, '参加者を1人以上選択してください')
      return render_form_with_errors
    end

    if @plan.save
      handle_participants
      # 新規作成時は全ての参加者が「追加された」とみなす
      notify_new_participants(added_ids: @plan.participant_ids)
      set_calendar_data(@plan.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date }),
            turbo_stream.replace("calendar-cell-#{@plan.date}",
                                 partial: 'calendar/calendar_grid_cell',
                                 locals: { day: @plan.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                           scope: current_scope }),
            turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
          ]
        end
        format.html { redirect_to calendar_path, notice: '予定を作成しました' }
      end
    else
      render_form_with_errors
    end
  end

  def update
    # 更新前の参加者IDを記録
    previous_participant_ids = @plan.participant_ids.dup
    @plan.last_edited_by = current_user

    # 参加者チェック
    if participant_ids_from_params.empty?
      @plan.errors.add(:base, '参加者を1人以上選択してください')
      return render_form_with_errors
    end

    if @plan.update(plan_params)
      handle_participants
      # 新規追加された参加者にのみ通知
      added_ids = @plan.participant_ids - previous_participant_ids
      notify_new_participants(added_ids: added_ids)
      set_calendar_data(@plan.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date }),
            turbo_stream.replace("calendar-cell-#{@plan.date}",
                                 partial: 'calendar/calendar_grid_cell',
                                 locals: { day: @plan.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                           scope: current_scope }),
            turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
          ]
        end
        format.html { redirect_to calendar_path, notice: '予定を更新しました' }
      end
    else
      render_form_with_errors
    end
  end

  def destroy
    date = @plan.date
    @plan.destroy
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
      format.html { redirect_to calendar_path, notice: '予定を削除しました' }
    end
  end

  private

  def set_plan
    @plan = current_user.family.plans.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:title, :description, :date, :start_time, :end_time, participant_ids: [])
  end

  def handle_participants
    # participant_ids is already handled by Rails associations if permitted correctly,
    # but verify if standard assignment works with has_many :through.
    # It should work automatically with plan_params including participant_ids: [].
  end

  # 新規追加された参加者に通知を送信
  def notify_new_participants(added_ids:)
    return if added_ids.empty?

    PlanNotificationService.notify_new_participants(
      plan: @plan,
      added_user_ids: added_ids,
      excluded_user_id: current_user.id # 自分自身には通知しない
    )
  end

  def participant_ids_from_params
    params.dig(:plan, :participant_ids)&.reject(&:blank?) || []
  end

  def render_form_with_errors
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('plan-form-container', partial: 'form_body', locals: { plan: @plan }),
               status: :unprocessable_entity
      end
      format.html { render @plan.persisted? ? :edit : :new, status: :unprocessable_entity }
    end
  end
end
