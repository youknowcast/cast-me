module CalendarHelper
  def day_has_unfinished_tasks?(day, user)
    user.tasks.for_date(day).exists?(completed: false)
  end

  # カレンダーグリッド描画に必要なデータを表示範囲分まとめて取得する。
  # セルごとの N+1 を避けるため、日付でグループ化して返す。
  # @param days [Array<Date>] 表示対象の全日付
  # @param scope [String] 'my' なら自分が参加する予定のみ
  def calendar_month_data(days, scope:)
    dates = days.compact
    plans = current_user.family.plans.where(date: dates)
    if scope == 'my'
      plans = plans.left_joins(:plan_participants)
                   .where(plan_participants: { user_id: current_user.id, status: %i[joined pending] })
                   .distinct
    end

    {
      plans_by_date: plans.group_by(&:date),
      tasks_by_date: current_user.tasks.where(date: dates).group_by(&:date),
      unfinished_dates: current_user.tasks.where(date: dates, completed: false).distinct.pluck(:date).to_set,
      family_users: current_user.family.users.to_a
    }
  end

  def anniversaries_on(day, users)
    AnniversaryService.anniversaries_on(day, users)
  end
end
