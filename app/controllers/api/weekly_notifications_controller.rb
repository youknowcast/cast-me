# frozen_string_literal: true

module Api
  class WeeklyNotificationsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_token!

    def create
      result = WeeklyTaskSummaryNotificationService.notify_all_families
      render json: { success: true, families_notified: result[:count] }
    end

    private

    def authenticate_api_token!
      token = request.headers['Authorization']&.gsub('Bearer ', '')
      expected_token = ENV.fetch('WEEKLY_NOTIFICATION_API_TOKEN', '')
      return if token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected_token)

      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
