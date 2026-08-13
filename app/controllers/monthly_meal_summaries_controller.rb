# frozen_string_literal: true

class MonthlyMealSummariesController < ApplicationController
  before_action :authenticate_user!

  def show
    base = parse_month(params[:month])
    @month_start = base.beginning_of_month
    @month_end = base.end_of_month
    @prev_month = (base - 1.month).strftime('%Y-%m')
    @next_month = (base + 1.month).strftime('%Y-%m')
    @meals_by_date = current_user.family.meals
                                 .where(date: @month_start..@month_end)
                                 .includes(:foods)
                                 .ordered_by_meal_type
                                 .group_by(&:date)
  end

  private

  def parse_month(value)
    Date.strptime(value.to_s, '%Y-%m')
  rescue ArgumentError, TypeError
    Date.current
  end
end
