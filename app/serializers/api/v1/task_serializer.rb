# frozen_string_literal: true

module Api
  module V1
    class TaskSerializer
      def self.call(task)
        {
          id: task.id,
          title: task.title,
          user: { id: task.user.id, display_name: task.user.display_name },
          completed: task.completed,
          priority: task.priority
        }
      end
    end
  end
end
