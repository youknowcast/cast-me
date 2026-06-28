module CalendarData
  extend ActiveSupport::Concern

  private

  def set_calendar_data(date)
    @date = date
    @holidays = HolidayService.holidays
    if my_scope?
      set_my_calendar_data(date)
    else
      set_family_calendar_data(date)
    end
  end

  def set_my_calendar_data(date)
    @date = date
    @target_users = [current_user]
    @family_plans = current_user.family.plans.for_date(date)
                                .left_joins(:plan_participants)
                                .where(plan_participants: { user_id: current_user.id, status: %i[joined pending] })
                                .includes(:created_by, :participants, :plan_participants)
                                .distinct
                                .ordered_by_time
    @family_tasks = current_user.tasks.for_date(date).ordered_by_priority
    @family_meals = current_user.family.meals.for_date(date)
                                .visible_to_user(current_user.id)
                                .includes(:user, :foods)
                                .ordered_by_meal_type
  end

  def set_family_calendar_data(date)
    @date = date
    set_target_users
    @family_plans = current_user.family.plans.for_date(date).includes(:created_by, :participants,
                                                                      :plan_participants).ordered_by_time
    @family_tasks = current_user.family.tasks.for_date(date).includes(:user).ordered_by_priority
    @family_meals = current_user.family.meals.for_date(date)
                                .includes(:user, :foods)
                                .ordered_by_meal_type
  end

  def set_target_users
    @target_users = if params[:filter_user_id].present? && params[:filter_user_id] != 'all'
                      [User.find(params[:filter_user_id])]
                    else
                      current_user.family.users
                    end
  end
end
