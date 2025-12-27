class PlansController < ApplicationController
  include CalendarData
  before_action :authenticate_user!
  before_action :set_plan, only: [:show, :edit, :update, :destroy]

  def index
    @plans = current_user.family.plans.for_date(params[:date]).ordered_by_time
  end

  def show
  end

  def new
    date = if params[:date].present?
             Date.parse(params[:date])
           else
             Date.today
           end

    @plan = current_user.family.plans.build(
      date: date,
      user: current_user
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { plan: @plan })
      end
      format.html { render :new }
    end
  rescue Date::Error
    # 無効な日付の場合は今日の日付を使用
    @plan = current_user.family.plans.build(
      date: Date.today,
      user: current_user
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { plan: @plan })
      end
      format.html { render :new }
    end
  end

  def create
    @plan = current_user.family.plans.build(plan_params)
    @plan.user = current_user
    @plan.last_edited_by = current_user

    if @plan.save
      handle_participants
      set_calendar_data(@plan.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date }),
            turbo_stream.update("side-panel", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "予定を作成しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("side-panel", partial: "form", locals: { plan: @plan }) }
        format.html { render :new }
      end
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("side-panel", partial: "form", locals: { plan: @plan })
      end
      format.html { render :edit }
    end
  end

  def update
    @plan.last_edited_by = current_user
    if @plan.update(plan_params)
      handle_participants
      set_calendar_data(@plan.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date }),
            turbo_stream.update("side-panel", "")
          ]
        end
        format.html { redirect_to calendar_path, notice: "予定を更新しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("side-panel", partial: "form", locals: { plan: @plan }) }
        format.html { render :edit }
      end
    end
  end

  def destroy
    date = @plan.date
    @plan.destroy
    set_calendar_data(date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date })
      end
      format.html { redirect_to calendar_path, notice: "予定を削除しました" }
    end
  end

  private

  def set_plan
    @plan = current_user.family.plans.find(params[:id])
  end

  def plan_params
    params.require(:plan).permit(:title, :description, :date, :start_time, :end_time, participant_ids: [])
  end

  def handle_participants
    # participant_ids is already handled by Rails associations if permitted correctly,
    # but verify if standard assignment works with has_many :through.
    # It should work automatically with plan_params including participant_ids: [].
  end
end