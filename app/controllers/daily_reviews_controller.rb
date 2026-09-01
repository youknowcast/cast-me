# frozen_string_literal: true

class DailyReviewsController < ApplicationController
  before_action :authenticate_user!

  def show
    @tasks = current_user.tasks.for_date(Date.current).ordered_by_priority
    @meals = current_user.family.meals.for_date(Date.current)
                         .visible_to_user(current_user.id)
                         .includes(:user, :foods)
                         .ordered_by_meal_type
  end
end
