# frozen_string_literal: true

module Api
  module V1
    class TodayController < ApplicationController
      def index
        date = requested_date
        return render_invalid_date! if date.nil?

        family = current_family
        plans = family.plans.for_date(date).ordered_by_time.includes(plan_participants: :user)
        task_scope = family_tasks_for_date(date)
        tasks = task_scope.ordered_by_priority.includes(:user)

        render json: {
          date: date.iso8601,
          family: { id: family.id, name: family.name },
          plans: plans.map { |plan| PlanSerializer.call(plan) },
          tasks: tasks.map { |task| TaskSerializer.call(task) },
          input_status: InputStatus.call(task_scope)
        }
      end
    end
  end
end
