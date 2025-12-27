class PlanParticipantsController < ApplicationController
  include CalendarData
  before_action :authenticate_user!

  def update
    @plan_participant = current_user.plan_participants.find(params[:id])
    if @plan_participant.update(status: params[:status])
      set_calendar_data(@plan_participant.plan.date)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("daily_details", partial: "calendar/daily_view", locals: { date: @date })
        end
        format.html { redirect_to calendar_path(date: @date) }
      end
    else
      redirect_to calendar_path, alert: "権限がありません"
    end
  end
end
