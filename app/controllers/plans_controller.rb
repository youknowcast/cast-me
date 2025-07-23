class PlansController < ApplicationController
  before_action :authenticate_user!
  before_action :set_plan, only: [:show, :edit, :update, :destroy]

  def index
    @plans = current_user.family.plans.for_date(params[:date]).ordered_by_time
  end

  def show
  end

  def new
    @plan = current_user.family.plans.build(
      date: params[:date] ? Date.parse(params[:date]) : Date.today,
      user: current_user
    )
  end

  def create
    @plan = current_user.family.plans.build(plan_params)
    @plan.user = current_user

    if @plan.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
              locals: { date: @plan.date, plans: current_user.family.plans.for_date(@plan.date).ordered_by_time, tasks: current_user.tasks.for_date(@plan.date).ordered_by_priority }),
            turbo_stream.update("modal", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "予定を作成しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("modal", partial: "form") }
        format.html { render :new }
      end
    end
  end

  def edit
  end

  def update
    if @plan.update(plan_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
              locals: { date: @plan.date, plans: current_user.family.plans.for_date(@plan.date).ordered_by_time, tasks: current_user.tasks.for_date(@plan.date).ordered_by_priority }),
            turbo_stream.update("modal", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "予定を更新しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("modal", partial: "form") }
        format.html { render :edit }
      end
    end
  end

  def destroy
    date = @plan.date
    @plan.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("daily-content", partial: "calendar/daily_view", 
          locals: { date: date, plans: current_user.family.plans.for_date(date).ordered_by_time, tasks: current_user.tasks.for_date(date).ordered_by_priority })
      end
      format.html { redirect_to calendar_path, notice: "予定を削除しました" }
    end
  end

  private

  def set_plan
    @plan = current_user.family.plans.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:title, :description, :date, :start_time, :end_time)
  end
end 