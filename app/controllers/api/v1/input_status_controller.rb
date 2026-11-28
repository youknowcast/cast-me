# frozen_string_literal: true

module Api
  module V1
    class InputStatusController < ApplicationController
      def index
        date = requested_date
        return render_invalid_date! if date.nil?

        task_scope = apply_user_filter(family_tasks_for_date(date))

        render json: { date: date.iso8601 }.merge(InputStatus.call(task_scope))
      end
    end
  end
end
