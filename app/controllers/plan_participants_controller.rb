class PlanParticipantsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_participant

  def update
    if @participant.update(status: params[:status])
      respond_to do |format|
        format.html { redirect_to calendar_path, notice: "参加状況を更新しました" }
        format.turbo_stream do
          @plan = @participant.plan
          render turbo_stream: turbo_stream.update("daily_details", partial: "calendar/daily_view",
            locals: { date: @plan.date, plans: current_user.family.plans.for_date(@plan.date).ordered_by_time, tasks: current_user.tasks.for_date(@plan.date).ordered_by_priority })
        end
      end
    else
      redirect_to calendar_path, alert: "更新に失敗しました"
    end
  end

  private

  def set_participant
    @participant = PlanParticipant.find(params[:id])
    # Ensure user can only update their own record or admin/family logic if needed
    unless @participant.user == current_user
      redirect_to calendar_path, alert: "権限がありません"
    end
  end
end
