module Mcp
  class ToolDefinitions
    TOOLS = [
      {
        name: 'get_day',
        description: 'Get everything scheduled on a given day in the family calendar. Returns `plans` (calendar ' \
                     'events on that date with title, start_time/end_time "HH:MM" or null, and participants), ' \
                     '`tasks` (todo items assigned to a family member, NOT calendar events, ' \
                     'with completed/priority), ' \
                     'and `input_status`. Excludes health, meals, and medications. `date` format `YYYY-MM-DD`; if ' \
                     'omitted, uses today in Asia/Tokyo.',
        inputSchema: {
          type: 'object',
          properties: {
            date: { type: 'string', description: 'Day to fetch, format `YYYY-MM-DD`. Omit for today.',
                    pattern: '^\d{4}-\d{2}-\d{2}$' }
          },
          additionalProperties: false
        }
      },
      {
        name: 'create_plan',
        description: 'Create a calendar PLAN (event) in the family calendar. A plan is a scheduled event on a date ' \
                     'with optional start/end time and participants; it is NOT a task (use complete_task/list_tasks ' \
                     'for todos). Returns the created plan. `date` format `YYYY-MM-DD` (required). `start_time` / ' \
                     '`end_time` format `HH:MM` 24h (optional). `participant_ids` (optional) are user ids from ' \
                     '`list_family`; members must be in the same family; omit to include only the API token user.',
        inputSchema: {
          type: 'object',
          properties: {
            date: { type: 'string', description: 'Day of the plan, format `YYYY-MM-DD`.',
                    pattern: '^\d{4}-\d{2}-\d{2}$' },
            title: { type: 'string', description: 'Title of the plan.' },
            start_time: { type: 'string', description: 'Start time `HH:MM` 24h, optional.',
                          pattern: '^([01]\d|2[0-3]):[0-5]\d$' },
            end_time: { type: 'string', description: 'End time `HH:MM` 24h, optional.',
                        pattern: '^([01]\d|2[0-3]):[0-5]\d$' },
            participant_ids: {
              type: 'array', items: { type: 'integer' },
              description: 'User ids (from `list_family`) to include; same family only. Omit to include only ' \
                           'the token user.'
            }
          },
          required: %w[date title],
          additionalProperties: false
        }
      },
      {
        name: 'list_tasks',
        description: 'List TASKS (todo items, NOT calendar events/plans) for the family on a date. Each task has ' \
                     'title, `user`, `completed`, `priority`. Returns `tasks` plus `counts` ' \
                     '(registered/completed/pending). `date` format `YYYY-MM-DD`, omit for today. `user_id` ' \
                     '(optional) restricts to one family member id from `list_family`.',
        inputSchema: {
          type: 'object',
          properties: {
            date: { type: 'string', description: 'Day, format `YYYY-MM-DD`. Omit for today.',
                    pattern: '^\d{4}-\d{2}-\d{2}$' },
            user_id: { type: 'integer', description: 'Optional family member id.' }
          },
          additionalProperties: false
        }
      },
      {
        name: 'complete_task',
        description: 'Mark a TASK as completed (`completed=true`). A task is a todo item, not a calendar plan. ' \
                     '`task_id` is the integer id from `list_tasks` or `get_day`. Returns the updated task.',
        inputSchema: {
          type: 'object',
          properties: { task_id: { type: 'integer', description: 'Id of the task to complete.' } },
          required: ['task_id'],
          additionalProperties: false
        }
      },
      {
        name: 'get_input_status',
        description: 'Get whether tasks have been entered for a day. `status` is `none` (no tasks), `partial` ' \
                     '(some unfinished), or `complete` (all done), with `registered`/`completed` counts. `date` ' \
                     'format `YYYY-MM-DD`, omit for today. `user_id` (optional) restricts to one family member.',
        inputSchema: {
          type: 'object',
          properties: {
            date: { type: 'string', description: 'Day, format `YYYY-MM-DD`. Omit for today.',
                    pattern: '^\d{4}-\d{2}-\d{2}$' },
            user_id: { type: 'integer', description: 'Optional family member id.' }
          },
          additionalProperties: false
        }
      },
      {
        name: 'list_family',
        description: 'List family members (`id`, `display_name`) in this calendar. `id`s are used as `user_id` / ' \
                     '`participant_ids` elsewhere.',
        inputSchema: { type: 'object', properties: {}, additionalProperties: false }
      }
    ].freeze
  end
end
