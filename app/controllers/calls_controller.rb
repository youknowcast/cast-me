# frozen_string_literal: true

class CallsController < ApplicationController
  def create
    @target_user = current_user.family.users.find(params[:user_id])
    message = params[:message].presence || 'これを見たら連絡して'

    FamilyCallNotificationService.notify(
      caller: current_user,
      target_user: @target_user,
      message: message
    )

    respond_to do |format|
      format.html { redirect_back fallback_location: calendar_path, notice: '呼び出しを送信しました' }
      format.turbo_stream { render turbo_stream: turbo_stream.replace('flash', partial: 'shared/flash') }
    end
  end
end
