# frozen_string_literal: true

module Api
  class WeeklyNotificationsController < ApplicationController
    include Api::TokenAuthenticatable

    def create
      result = WeeklyTaskSummaryNotificationService.notify_all_families
      render json: { success: true, families_notified: result[:count] }
    end
  end
end

