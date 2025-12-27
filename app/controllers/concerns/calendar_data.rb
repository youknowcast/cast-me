module CalendarData
  extend ActiveSupport::Concern

  private

  def set_calendar_data(date)
    @date = date
    set_target_users
    @family_plans = current_user.family.plans.for_date(@date).includes(:user, :participants, :plan_participants).ordered_by_time
    @family_tasks = current_user.family.tasks.for_date(@date).includes(:user).ordered_by_priority
  end

  def set_target_users
    if params[:filter_user_id].present? && params[:filter_user_id] != 'all'
      @target_users = [User.find(params[:filter_user_id])]
    elsif params[:scope] == 'my'
      @target_users = [current_user]
    else
      @target_users = current_user.family.users
    end
  end
end
