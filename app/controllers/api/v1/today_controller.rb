# frozen_string_literal: true

module Api
  module V1
    class TodayController < ApplicationController
      def index
        date = requested_date
        return render_invalid_date! if date.nil?

        render json: DayPayload.call(family: current_family, date: date)
      end
    end
  end
end
