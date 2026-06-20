class PlansController < ApplicationController
  include CalendarData
  include MultiDatePlanCreation

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
    @selected_dates = [date]
    @plan.participant_ids = [current_user.id] if my_scope?

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'form', locals: { plan: @plan })
      end
      format.html { render :new }
    end
  rescue Date::Error
    @plan = current_user.family.plans.build(
      date: Time.zone.today,
      created_by: current_user
    )
    @selected_dates = [Time.zone.today]
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
    @selected_dates = selected_dates_from_params
    @plan = build_plan(@selected_dates.first)

    if @selected_dates.empty?
      @plan.errors.add(:date, 'を1日以上選択してください')
      return render_form_with_errors
    end

    # 参加者チェック
    if participant_ids_from_params.empty?
      @plan.errors.add(:base, '参加者を1人以上選択してください')
      return render_form_with_errors
    end

    created_plans = create_plans_for_selected_dates
    created_plans.each { |plan| notify_new_participants(plan: plan, added_ids: plan.participant_ids) }
    render_create_success(created_plans)
  rescue ActiveRecord::RecordInvalid => e
    @plan = e.record
    @plan.errors.add(:base, '予定を作成できませんでした') unless @plan.errors.any?
    render_form_with_errors
  rescue ActiveRecord::RecordNotSaved
    @plan.errors.add(:base, '予定を作成できませんでした')
    render_form_with_errors
  end

  def update
    previous_participant_ids = @plan.participant_ids.dup
    @plan.last_edited_by = current_user

    if participant_ids_from_params.empty?
      @plan.errors.add(:base, '参加者を1人以上選択してください')
      render_form_with_errors
      return
    end

    if @plan.update(plan_params)
      # 新規追加された参加者にのみ通知
      added_ids = @plan.participant_ids - previous_participant_ids
      notify_new_participants(plan: @plan, added_ids: added_ids)
      set_calendar_data(@plan.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date }),
            turbo_stream.replace("calendar-cell-#{@plan.date}",
                                 partial: 'calendar/calendar_grid_cell',
                                 locals: { day: @plan.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                           scope: current_scope, holidays: @holidays }),
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
    destroyed = @plan.destroy
    set_calendar_data(date)

    respond_to do |format|
      format.turbo_stream do
        if destroyed
          render turbo_stream: [
            turbo_stream.update('daily_details', partial: 'calendar/daily_view',
                                                 locals: { date: @date }),
            turbo_stream.replace("calendar-cell-#{date}",
                                 partial: 'calendar/calendar_grid_cell',
                                 locals: { day: date, date: @date, plans: @family_plans, tasks: @family_tasks,
                                           scope: current_scope, holidays: @holidays })
          ]
        else
          head :unprocessable_entity
        end
      end
      format.html { redirect_to calendar_path, (destroyed ? { notice: '予定を削除しました' } : { alert: '予定を削除できませんでした' }) }
    end
  end

  private

  def set_plan
    @plan = current_user.family.plans.find(params[:id])
  end

  def plan_params
    params.expect(plan: [:title, :description, :date, :start_time, :end_time, { participant_ids: [] }])
  end

  # 新規追加された参加者に通知を送信
  def notify_new_participants(plan:, added_ids:)
    return if added_ids.empty?

    PlanNotificationService.notify_new_participants(
      plan: plan,
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
