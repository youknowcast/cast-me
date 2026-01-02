class PlanParticipantsController < ApplicationController
  include CalendarData
  before_action :authenticate_user!

  def update
    @plan_participant = PlanParticipant.joins(user: :family)
                                       .where(families: { id: current_user.family_id })
                                       .find_by(id: params[:id])

    if @plan_participant&.update(status: params[:status])
      @date = @plan_participant.plan.date
      set_calendar_data(@date)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update('daily_details', partial: 'calendar/daily_view',
                                                                    locals: { date: @date, scope: current_scope })
        end
        format.html { redirect_to calendar_path(date: @date) }
      end
    else
      # If record not found, try to redirect back or to general calendar
      @date = begin
        params[:date].present? ? Date.parse(params[:date]) : Time.zone.today
      rescue StandardError
        Time.zone.today
      end
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update('daily_details', '更新に失敗しました。') }
        format.html { redirect_to calendar_path(date: @date), alert: '更新に失敗しました。' }
      end
    end
  end
end
