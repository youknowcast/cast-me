class CalendarController < ApplicationController
  include CalendarData
  before_action :authenticate_user!

  def index
    @date = date
    @weeks = generate_calendar_weeks

    # For Detail View (Today)
    set_family_calendar_data(Date.today)
  end

  def my
    @date = date
    @weeks = generate_calendar_weeks

    # For Detail View (Today)
    set_my_calendar_data(Date.today)
  end

  def daily_view
    @date = Date.parse(params[:date])
    set_calendar_data(@date)
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
