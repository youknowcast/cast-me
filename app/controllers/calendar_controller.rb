class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
    @date = date
    @weeks = generate_calendar_weeks
    @today_plans = fetch_plans_for_date(Date.today)
    @today_tasks = current_user.tasks.for_date(Date.today).ordered_by_priority
  end

  def daily_view
    @date = Date.parse(params[:date])
    @plans = fetch_plans_for_date(@date)
    @tasks = current_user.tasks.for_date(@date).ordered_by_priority
  end

  private

  def fetch_plans_for_date(date)
    scope = params[:scope] || 'family'

    plans = current_user.family.plans.for_date(date).ordered_by_time

    if scope == 'my'
      # Filter for plans where user is owner or participant
      plans = plans.left_joins(:plan_participants)
                   .where("plans.user_id = ? OR plan_participants.user_id = ?", current_user.id, current_user.id)
                   .distinct
    end

    plans
  end

  def date = @_date ||= params[:date] ? Date.parse(params[:date]) : Date.today

  def generate_calendar_weeks
    first_day = date.beginning_of_month
    last_day = date.end_of_month

    # カレンダーの最初の日と最後の日を設定（日曜日始まり）
    start_date = first_day - first_day.wday
    end_date = last_day + (6 - last_day.wday)

    (start_date..end_date).to_a.in_groups_of(7) # 7日ごとの配列
  end
end
