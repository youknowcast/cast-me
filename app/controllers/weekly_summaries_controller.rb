# frozen_string_literal: true

class WeeklySummariesController < ApplicationController
  before_action :authenticate_user!

  def show
    @week_start = Date.current.beginning_of_week
    @week_end = Date.current.end_of_week

    @users_summary = current_user.family.users.map do |user|
      {
        user: user,
        completed_tasks: user.tasks.where(date: @week_start..@week_end, completed: true),
        pending_tasks: user.tasks.where(date: @week_start..@week_end, completed: false)
      }
    end
  end
end
