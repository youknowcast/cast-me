# frozen_string_literal: true

class FamilyUsageReport
  MemberRow = Struct.new(:user, :record_days, keyword_init: true)

  def initialize(family:, days:)
    @family = family
    @days = days
  end

  attr_reader :family, :days

  def start_date = Date.current - (days - 1)

  def end_date = Date.current

  def record_days = event_dates.size

  def plan_count = plan_events.size

  def task_count = task_events.size

  def meal_count = meal_events.size

  def member_rows
    @member_rows ||= family.users.order(:id).map do |user|
      MemberRow.new(user: user, record_days: member_event_dates(user.id).size)
    end
  end

  def last_seen_label(user)
    return '—' if user.last_seen_at.blank?

    days_ago = (Date.current - user.last_seen_at.in_time_zone.to_date).to_i

    case days_ago
    when ..0 then '今日'
    when 1 then '昨日'
    when 2..29 then "#{days_ago}日前"
    else '30日以上前'
    end
  end

  private

  def event_dates
    @event_dates ||= all_events.map(&:last).uniq
  end

  def member_event_dates(user_id)
    all_events.select { |event_user_id, _date| event_user_id == user_id }.map(&:last).uniq
  end

  def all_events = plan_events + task_events + meal_events

  def plan_events = @plan_events ||= events_for(Plan, :created_by_id)

  def task_events = @task_events ||= events_for(Task, :user_id)

  def meal_events = @meal_events ||= events_for(Meal, :user_id)

  def events_for(model, user_column)
    model.where(family_id: family.id, created_at: window)
         .pluck(user_column, :created_at)
         .map { |user_id, created_at| [user_id, created_at.in_time_zone.to_date] }
  end

  def window = start_date.beginning_of_day..end_date.end_of_day
end
