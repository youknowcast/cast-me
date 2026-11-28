# frozen_string_literal: true

module Api
  module V1
    class TasksController < ApplicationController
      def index
        date = requested_date
        return render_invalid_date! if date.nil?

        task_scope = apply_user_filter(family_tasks_for_date(date))
        tasks = task_scope.ordered_by_priority.includes(:user)
        status = InputStatus.call(task_scope)

        render json: {
          date: date.iso8601,
          tasks: tasks.map { |task| TaskSerializer.call(task) },
          counts: {
            registered: status[:registered],
            completed: status[:completed],
            pending: status[:registered] - status[:completed]
          }
        }
      end

      def toggle
        task = current_family.tasks.find_by(id: params[:id])
        return render json: { error: 'not_found' }, status: :not_found if task.nil?

        task.update!(completed: !task.completed)
        render json: TaskSerializer.call(task)
      end

      def complete
        task = current_family.tasks.find_by(id: params[:id])
        return render json: { error: 'not_found' }, status: :not_found if task.nil?

        task.update!(completed: true) unless task.completed
        render json: TaskSerializer.call(task)
      end
    end
  end
end
