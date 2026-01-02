class CalendarController < ApplicationController
  include CalendarData

  before_action :authenticate_user!

  def index
    @weeks = generate_calendar_weeks
    # Fetch data for the selected/default date in the details view
    set_family_calendar_data(@date)
  end

  def my
    @weeks = generate_calendar_weeks
    # Fetch data for the selected/default date in the details view
    set_my_calendar_data(@date)
  end

  def daily_view
    set_calendar_data(@date)
  end

  def monthly_list
    @monthly_plans = current_user.family.plans.for_month(@date)
                                 .includes(:created_by, :participants, :plan_participants)
                                 .ordered_by_time
                                 .group_by(&:date)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'calendar/monthly_list',
                                                               locals: { plans_by_date: @monthly_plans, date: @date })
      end
      format.html { head :ok }
    end
  end

  private

  def generate_calendar_weeks
    first_day = @date.beginning_of_month
    last_day = @date.end_of_month

    # カレンダーの最初の日と最後の日を設定（日曜日始まり）
    start_date = first_day - first_day.wday
    end_date = last_day + (6 - last_day.wday)

    (start_date..end_date).to_a.in_groups_of(7) # 7日ごとの配列
  end
end
