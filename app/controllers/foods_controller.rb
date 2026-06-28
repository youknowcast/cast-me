class FoodsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_food, only: %i[update]

  def index
    @food = current_user.family.foods.build
    @foods = current_user.family.foods.ordered_by_name
  end

  def create
    @food = current_user.family.foods.build(food_params)
    if @food.save
      redirect_to foods_path, notice: '食べ物を追加しました'
    else
      @foods = current_user.family.foods.ordered_by_name
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @food.update(food_params)
      redirect_to foods_path, notice: '食べ物を更新しました'
    else
      @foods = current_user.family.foods.ordered_by_name
      render :index, status: :unprocessable_entity
    end
  end

  private

  def set_food
    @food = current_user.family.foods.find(params[:id])
  end

  def food_params
    params.expect(food: %i[name active])
  end
end
