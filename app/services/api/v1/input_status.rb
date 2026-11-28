# frozen_string_literal: true

module Api
  module V1
    class InputStatus
      def self.call(task_scope)
        registered = task_scope.count
        completed = task_scope.where(completed: true).count

        {
          registered: registered,
          completed: completed,
          status: status_for(registered: registered, completed: completed)
        }
      end

      def self.status_for(registered:, completed:)
        return 'none' if registered.zero?
        return 'complete' if completed == registered

        'partial'
      end
    end
  end
end
