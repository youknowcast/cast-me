module CalendarHelper
  def day_has_unfinished_tasks?(day, user)
    user.tasks.for_date(day).exists?(completed: false)
  end

  def anniversaries_on(day, users)
    AnniversaryService.anniversaries_on(day, users)
  end
end
