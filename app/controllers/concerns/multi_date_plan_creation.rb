module MultiDatePlanCreation
  extend ActiveSupport::Concern

  private

  def selected_dates_from_params
    raw_dates = Array(params.dig(:plan, :dates)).compact_blank
    raw_dates = [params.dig(:plan, :date)] if raw_dates.empty? && params.dig(:plan, :date).present?

    raw_dates.map { |date| Date.iso8601(date.to_s) }.uniq
  rescue Date::Error
    []
  end

  def build_plan(date)
    current_user.family.plans.build(plan_params.merge(date: date)).tap do |plan|
      plan.created_by = current_user
      plan.last_edited_by = current_user
    end
  end

  def create_plans_for_selected_dates
    plans = @selected_dates.map { |date| build_plan(date) }
    @plan = plans.first

    Plan.transaction { plans.each(&:save!) }
    plans
  end

  def render_create_success(created_plans)
    primary_date = created_plans.first.date
    notice = created_plans.one? ? '予定を作成しました' : "予定を#{created_plans.size}件作成しました"

    respond_to do |format|
      format.turbo_stream { render turbo_stream: create_turbo_streams(created_plans, primary_date) }
      format.html { redirect_to calendar_path, notice: notice }
    end
  end

  def create_turbo_streams(created_plans, primary_date)
    set_calendar_data(primary_date)
    streams = [turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date })]

    created_plans.each do |plan|
      set_calendar_data(plan.date)
      streams << turbo_stream.replace(
        "calendar-cell-#{plan.date}",
        partial: 'calendar/calendar_grid_cell',
        locals: { day: plan.date, date: @date, plans: @family_plans, tasks: @family_tasks,
                  scope: current_scope, holidays: @holidays }
      )
    end

    streams << turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
  end
end
