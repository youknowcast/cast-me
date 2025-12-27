module ApplicationHelper
  def plan_icon
    "fas fa-calendar-alt"
  end

  def task_icon
    "fas fa-tasks"
  end

  def day_has_unfinished_tasks?(date, user)
    return false if date >= Date.today
    user.tasks.for_date(date).pending.exists?
  end
end
