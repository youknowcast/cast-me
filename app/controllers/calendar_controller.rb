class CalendarController < ApplicationController
  before_action :authenticate_user!

  def index
    @date = date
    @weeks = generate_calendar_weeks
    @today_plans = current_user.family.plans.for_date(Date.today).ordered_by_time
    @today_tasks = current_user.tasks.for_date(Date.today).ordered_by_priority
  end

  def daily_view
    @date = Date.parse(params[:date])
    @plans = current_user.family.plans.for_date(@date).ordered_by_time
    @tasks = current_user.tasks.for_date(@date).ordered_by_priority
  end

  private

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
