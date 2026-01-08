# frozen_string_literal: true

module Api
  class ScheduledNotificationsController < ApplicationController
    skip_forgery_protection
    skip_before_action :authenticate_user!, raise: false
    before_action :verify_api_token

    # POST /api/scheduled_notifications/trigger
    def trigger
      hour = params[:hour].to_i

      # カレンダ通知
      calendar_settings = UserNotificationSetting
                          .where(family_calendar_reminder_enabled: true, family_calendar_reminder_hour: hour)
                          .includes(:user)
      calendar_settings.find_each { |s| FamilyCalendarNotificationService.notify(s.user) }

      # タスク状況通知
      task_settings = UserNotificationSetting
                      .where(family_task_progress_reminder_enabled: true, family_task_progress_reminder_hour: hour)
                      .includes(:user)
      task_settings.find_each { |s| FamilyTaskStatusNotificationService.notify(s.user) }

      render json: { status: 'ok', calendar_count: calendar_settings.count, task_count: task_settings.count }
    end

    private

    def verify_api_token
      expected = ENV.fetch('SCHEDULED_NOTIFICATION_API_TOKEN', nil)
      provided = request.headers['X-Api-Token']
      head :unauthorized unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected,
                                                                                                 provided.to_s)
    end
  end
end
