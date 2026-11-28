module Api
  module V1
    class DayPayload
      def self.call(family:, date:)
        plans = family.plans.for_date(date).ordered_by_time.includes(plan_participants: :user)
        task_scope = family.tasks.for_date(date).where(user_id: family.user_ids)
        tasks = task_scope.ordered_by_priority.includes(:user)

        {
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
