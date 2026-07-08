class MealsController < ApplicationController
  include CalendarData

  before_action :authenticate_user!
  before_action :set_meal, only: %i[edit update destroy]

  FOOD_REQUIRED_MESSAGE = '食べ物を1つ以上選択してください'.freeze

  def new
    @meal = current_user.family.meals.build(default_meal_attributes)
    render_form
  end

  def edit
    render_form
  end

  def create
    @meal = current_user.family.meals.build(meal_params)
    @meal.user_id = nil if @meal.user_id.blank?
    save_with_foods('食事を記録しました')
  end

  def update
    @meal.assign_attributes(meal_params)
    @meal.user_id = nil if @meal.user_id.blank?
    save_with_foods('食事を更新しました', reassign: true)
  end

  def destroy
    date = @meal.date
    @meal.destroy
    set_calendar_data(date)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('daily_details',
                                                 partial: 'calendar/daily_view', locals: { date: @date })
      end
      format.html { redirect_to calendar_path(date: date), notice: '食事を削除しました' }
    end
  end

  private

  def set_meal
    @meal = current_user.family.meals.find(params[:id])
  end

  def meal_params
    params.expect(meal: %i[date meal_type user_id])
  end

  def food_names
    Array(params.dig(:meal, :food_names)).map { |name| name.to_s.strip }.compact_blank.uniq
  end

  def save_with_foods(notice, reassign: false)
    if food_names.empty?
      @meal.errors.add(:base, FOOD_REQUIRED_MESSAGE)
      return render_form_with_errors
    end

    saved = false
    Meal.transaction do
      @meal.meal_foods.destroy_all if reassign
      assign_foods(@meal)
      saved = @meal.save
      raise ActiveRecord::Rollback unless saved
    end

    saved ? render_saved(notice) : render_form_with_errors
  end

  def assign_foods(meal)
    food_names.each do |name|
      food = current_user.family.foods.where(name: name).first_or_initialize
      meal.meal_foods.build(food: food)
    end
  end

  def default_meal_attributes
    { date: parse_date(params[:date]), user_id: my_scope? ? current_user.id : nil }
  end

  def render_form
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'meals/form',
                                                               locals: { meal: @meal, scope: current_scope })
      end
      format.html { render(@meal.persisted? ? :edit : :new) }
    end
  end

  def render_form_with_errors
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel', partial: 'meals/form',
                                                               locals: { meal: @meal, scope: current_scope }),
               status: :unprocessable_entity
      end
      format.html { render(@meal.persisted? ? :edit : :new, status: :unprocessable_entity) }
    end
  end

  def render_saved(notice)
    set_calendar_data(@meal.date)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update('daily_details', partial: 'calendar/daily_view', locals: { date: @date }),
          turbo_stream.update('side-panel', '')
        ]
      end
      format.html { redirect_to calendar_path(date: @meal.date), notice: notice }
    end
  end
end
