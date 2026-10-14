class WeeklyDashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @week_start = week_start
    @week_end = @week_start + 6
    @days = (@week_start..@week_end).to_a
    @members = current_user.family.users.order(:id)
    @plans_by_user = weekly_plans_index
    @memos_by_date = current_user.family.day_memos.where(date: @week_start..@week_end).index_by(&:date)
    @holidays = HolidayService.holidays
  end

  private

  def week_start
    return Date.current.beginning_of_week if params[:week].blank?

    Date.parse(params[:week].to_s).beginning_of_week
  rescue Date::Error, TypeError
    Date.current.beginning_of_week
  end

  def weekly_plans_index
    plans = current_user.family.plans
                        .where(date: @week_start..@week_end)
                        .includes(:plan_participants)
                        .ordered_by_time
    index = Hash.new { |hours, user_id| hours[user_id] = Hash.new { |days, date| days[date] = [] } }
    plans.each do |plan|
      plan.plan_participants.reject(&:declined?).each do |participant|
        index[participant.user_id][plan.date] << plan
      end
    end
    index
  end
end
