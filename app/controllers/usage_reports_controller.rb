# frozen_string_literal: true

class UsageReportsController < ApplicationController
  before_action :authenticate_user!

  PERIODS = [7, 30].freeze
  DEFAULT_PERIOD = 7
  private_constant :DEFAULT_PERIOD

  def show
    @periods = PERIODS
    @days = PERIODS.include?(params[:period].to_i) ? params[:period].to_i : DEFAULT_PERIOD
    @report = FamilyUsageReport.new(family: current_user.family, days: @days)
  end
end
