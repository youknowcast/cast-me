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

  def cell
    @member = current_user.family.users.find(params.expect(:user_id))
    @date = Date.parse(params[:date].to_s)
    @plans = plans_for(@member, @date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel',
                                                 partial: 'weekly_dashboard/cell_panel',
                                                 locals: { member: @member, date: @date, plans: @plans })
      end
      format.html { redirect_to weekly_dashboard_path }
    end
  rescue Date::Error, TypeError
    head :bad_request
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

  def plans_for(member, date)
    current_user.family.plans
                .for_date(date)
                .left_joins(:plan_participants)
                .where(plan_participants: { user_id: member.id, status: %i[joined pending] })
                .includes(:participants, :plan_participants)
                .ordered_by_time
                .distinct
  end
end
