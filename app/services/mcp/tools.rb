module Mcp
  class Tools
    TODAY_ZONE = Api::V1::ApplicationController::TIME_ZONE

    def self.list = Mcp::ToolDefinitions::TOOLS

    def self.call(name:, args:, family:, token_user:, request_id: nil)
      raise Mcp::ToolError, "Unknown tool: #{name}" unless Mcp::ToolDefinitions::TOOLS.any? { |t| t[:name] == name }

      args = {} unless args.is_a?(Hash)
      payload =
        case name
        when 'get_day' then get_day(args, family)
        when 'create_plan' then create_plan(args, family, token_user, request_id)
        when 'list_tasks' then list_tasks(args, family)
        when 'complete_task' then complete_task(args, family)
        when 'get_input_status' then get_input_status(args, family)
        when 'list_family' then list_family(family)
        end

      result(payload)
    end

    def self.result(payload) = { content: [{ type: 'text', text: JSON.generate(payload) }] }

    def self.get_day(args, family)
      date = optional_date(args['date'])
      Api::V1::DayPayload.call(family: family, date: date)
    end

    def self.create_plan(args, family, token_user, request_id)
      params = ActiveSupport::HashWithIndifferentAccess.new(
        date: args['date'], title: args['title'], start_time: args['start_time'],
        end_time: args['end_time'], participant_ids: args['participant_ids']
      )
      request_hash = Api::V1::Idempotency.request_hash(params.to_h)
      key = "mcp:#{Digest::SHA256.hexdigest(JSON.generate([request_id.to_s, Api::V1::Idempotency.deep_sort(params.to_h)]))}"

      _status, body = Api::V1::Idempotency.process(family: family, key: key, request_hash: request_hash) do
        [201,
         Api::V1::PlanSerializer.call(Api::V1::PlanCreator.call(family: family, token_user: token_user,
                                                                params: params))]
      end
      body
    rescue Api::V1::StrictDate::InvalidDate
      raise Mcp::ToolError, 'invalid date: expected `YYYY-MM-DD`'
    rescue Api::V1::TimeOfDay::InvalidTime
      raise Mcp::ToolError, 'invalid time: expected `HH:MM`'
    rescue Api::V1::PlanCreator::UnprocessableContent => e
      raise Mcp::ToolError, e.message
    end

    def self.list_tasks(args, family)
      date = optional_date(args['date'])
      scope = family.tasks.for_date(date).where(user_id: family.user_ids)
      scope = scope.where(user_id: strict_integer(args['user_id'], 'user_id')) unless args['user_id'].nil?
      tasks = scope.ordered_by_priority.includes(:user)
      status = Api::V1::InputStatus.call(scope)

      {
        date: date.iso8601,
        tasks: tasks.map { |task| Api::V1::TaskSerializer.call(task) },
        counts: { registered: status[:registered], completed: status[:completed],
                  pending: status[:registered] - status[:completed] }
      }
    end

    def self.complete_task(args, family)
      task_id = strict_integer(args['task_id'], 'task_id')
      task = family.tasks.find_by(id: task_id)
      raise Mcp::ToolError, "task not found: #{task_id}" if task.nil?

      task.update!(completed: true)
      Api::V1::TaskSerializer.call(task)
    end

    def self.get_input_status(args, family)
      date = optional_date(args['date'])
      scope = family.tasks.for_date(date).where(user_id: family.user_ids)
      scope = scope.where(user_id: strict_integer(args['user_id'], 'user_id')) unless args['user_id'].nil?
      { date: date.iso8601 }.merge(Api::V1::InputStatus.call(scope))
    end

    def self.list_family(family)
      family.users.order(:id).map { |member| { id: member.id, display_name: member.display_name } }
    end

    def self.optional_date(raw)
      return Time.current.in_time_zone(TODAY_ZONE).to_date if raw.nil?

      Api::V1::StrictDate.parse!(raw)
    rescue Api::V1::StrictDate::InvalidDate
      raise Mcp::ToolError, 'invalid date: expected `YYYY-MM-DD`'
    end

    def self.strict_integer(value, field)
      raise Mcp::ToolError, "#{field} must be an integer" unless value.is_a?(Integer)

      value
    end
  end
end
