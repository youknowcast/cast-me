import { createHash } from 'node:crypto';

export interface ToolDefinition {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, unknown>;
    required?: string[];
    additionalProperties: boolean;
  };
}

export type FetchImpl = typeof fetch;

export interface ToolCallOptions {
  name: string;
  args: Record<string, unknown>;
  id: string | number | null;
  token: string;
  apiBase: string;
}

export interface McpToolResult {
  content: Array<{ type: 'text'; text: string }>;
}

export class ToolError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ToolError';
  }
}

export class Unauthorized extends Error {
  readonly body: string;

  constructor(body: string) {
    super('unauthorized');
    this.name = 'Unauthorized';
    this.body = body;
  }
}

const DATE_FORMAT = /^\d{4}-\d{2}-\d{2}$/;
const TIME_FORMAT = /^([01]\d|2[0-3]):[0-5]\d$/;

export const TOOLS: ToolDefinition[] = [
  {
    name: 'get_day',
    description:
      'Get everything scheduled on a given day in the family calendar. Returns `plans` (calendar ' +
      'events on that date with title, start_time/end_time "HH:MM" or null, and participants), ' +
      '`tasks` (todo items assigned to a family member, NOT calendar events, ' +
      'with completed/priority), ' +
      'and `input_status`. Excludes health, meals, and medications. `date` format `YYYY-MM-DD`; if ' +
      'omitted, uses today in Asia/Tokyo.',
    inputSchema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Day to fetch, format `YYYY-MM-DD`. Omit for today.', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'create_plan',
    description:
      'Create a calendar PLAN (event) in the family calendar. A plan is a scheduled event on a date ' +
      'with optional start/end time and participants; it is NOT a task (use complete_task/list_tasks ' +
      'for todos). Returns the created plan. `date` format `YYYY-MM-DD` (required). `start_time` / ' +
      '`end_time` format `HH:MM` 24h (optional). `participant_ids` (optional) are user ids from ' +
      '`list_family`; members must be in the same family; omit to include only the API token user.',
    inputSchema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Day of the plan, format `YYYY-MM-DD`.', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
        title: { type: 'string', description: 'Title of the plan.' },
        start_time: { type: 'string', description: 'Start time `HH:MM` 24h, optional.', pattern: '^([01]\\d|2[0-3]):[0-5]\\d$' },
        end_time: { type: 'string', description: 'End time `HH:MM` 24h, optional.', pattern: '^([01]\\d|2[0-3]):[0-5]\\d$' },
        participant_ids: {
          type: 'array',
          items: { type: 'integer' },
          description: 'User ids (from `list_family`) to include; same family only. Omit to include only the token user.',
        },
      },
      required: ['date', 'title'],
      additionalProperties: false,
    },
  },
  {
    name: 'list_tasks',
    description:
      'List TASKS (todo items, NOT calendar events/plans) for the family on a date. Each task has ' +
      'title, `user`, `completed`, `priority`. Returns `tasks` plus `counts` ' +
      '(registered/completed/pending). `date` format `YYYY-MM-DD`, omit for today. `user_id` ' +
      '(optional) restricts to one family member id from `list_family`.',
    inputSchema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Day, format `YYYY-MM-DD`. Omit for today.', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
        user_id: { type: 'integer', description: 'Optional family member id.' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'complete_task',
    description:
      'Mark a TASK as completed (`completed=true`). A task is a todo item, not a calendar plan. ' +
      '`task_id` is the integer id from `list_tasks` or `get_day`. Returns the updated task.',
    inputSchema: {
      type: 'object',
      properties: { task_id: { type: 'integer', description: 'Id of the task to complete.' } },
      required: ['task_id'],
      additionalProperties: false,
    },
  },
  {
    name: 'get_input_status',
    description:
      'Get whether tasks have been entered for a day. `status` is `none` (no tasks), `partial` ' +
      '(some unfinished), or `complete` (all done), with `registered`/`completed` counts. `date` ' +
      'format `YYYY-MM-DD`, omit for today. `user_id` (optional) restricts to one family member.',
    inputSchema: {
      type: 'object',
      properties: {
        date: { type: 'string', description: 'Day, format `YYYY-MM-DD`. Omit for today.', pattern: '^\\d{4}-\\d{2}-\\d{2}$' },
        user_id: { type: 'integer', description: 'Optional family member id.' },
      },
      additionalProperties: false,
    },
  },
  {
    name: 'list_family',
    description:
      'List family members (`id`, `display_name`) in this calendar. `id`s are used as `user_id` / ' +
      '`participant_ids` elsewhere.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
];

const KNOWN_TOOLS = new Set(TOOLS.map((t) => t.name));

export async function callTool(opts: ToolCallOptions, fetchImpl: FetchImpl = fetch): Promise<McpToolResult> {
  if (!KNOWN_TOOLS.has(opts.name)) throw new ToolError(`Unknown tool: ${opts.name}`);

  const args = opts.args ?? {};
  const payload = await dispatch(opts.name, args, opts, fetchImpl);
  return { content: [{ type: 'text', text: payload }] };
}

async function dispatch(name: string, args: Record<string, unknown>, opts: ToolCallOptions, fetchImpl: FetchImpl): Promise<string> {
  switch (name) {
    case 'get_day':
      return castmeGet(fetchImpl, opts, `/api/v1/today${queryString({ date: optionalDate(args['date']) })}`);
    case 'list_tasks':
      return castmeGet(fetchImpl, opts, `/api/v1/tasks${queryString({ date: optionalDate(args['date']), user_id: optionalInteger(args['user_id'], 'user_id') })}`);
    case 'get_input_status':
      return castmeGet(fetchImpl, opts, `/api/v1/input_status${queryString({ date: optionalDate(args['date']), user_id: optionalInteger(args['user_id'], 'user_id') })}`);
    case 'list_family':
      return castmeGet(fetchImpl, opts, '/api/v1/family/members');
    case 'complete_task': {
      const taskId = requiredInteger(args['task_id'], 'task_id');
      return castme(fetchImpl, opts, { method: 'PATCH', path: `/api/v1/tasks/${taskId}/complete` });
    }
    case 'create_plan':
      return createPlan(fetchImpl, opts, args);
    default:
      throw new ToolError(`Unknown tool: ${name}`);
  }
}

async function createPlan(fetchImpl: FetchImpl, opts: ToolCallOptions, args: Record<string, unknown>): Promise<string> {
  const date = requireValidDate(args['date']);
  const title = args['title'];
  if (typeof title !== 'string' || title.length === 0) throw new ToolError('title is required');

  const body: Record<string, unknown> = { date, title };
  const startTime = optionalTime(args['start_time'], 'start_time');
  const endTime = optionalTime(args['end_time'], 'end_time');
  if (startTime !== undefined) body['start_time'] = startTime;
  if (endTime !== undefined) body['end_time'] = endTime;
  if (args['participant_ids'] !== undefined) body['participant_ids'] = requireIntegerArray(args['participant_ids'], 'participant_ids');

  return castme(fetchImpl, opts, {
    method: 'POST',
    path: '/api/v1/plans',
    jsonBody: body,
    headers: { 'Idempotency-Key': idempotencyKey(opts.id, body) },
  });
}

async function castmeGet(fetchImpl: FetchImpl, opts: ToolCallOptions, path: string): Promise<string> {
  return castme(fetchImpl, opts, { method: 'GET', path });
}

async function castme(
  fetchImpl: FetchImpl,
  opts: ToolCallOptions,
  req: { method: string; path: string; jsonBody?: unknown; headers?: Record<string, string> },
): Promise<string> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${opts.token}`,
    Accept: 'application/json',
    ...req.headers,
  };
  let body: string | undefined;
  if (req.jsonBody !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(req.jsonBody);
  }

  const res = await fetchImpl(joinUrl(opts.apiBase, req.path), { method: req.method, headers, body });
  const text = await res.text();
  if (res.status === 401) throw new Unauthorized(text);
  if (res.status < 200 || res.status >= 300) throw new ToolError(toolErrorMessage(res.status, text));
  return text;
}

function toolErrorMessage(status: number, body: string): string {
  const trimmed = body.trim();
  return trimmed.length > 0 ? trimmed : `cast-me request failed with status ${status}`;
}

function joinUrl(base: string, path: string): string {
  return base.replace(/\/+$/, '') + path;
}

function queryString(params: Record<string, string | number | undefined>): string {
  const entries = Object.entries(params).filter((e): e is [string, string | number] => e[1] !== undefined);
  if (entries.length === 0) return '';
  const search = new URLSearchParams();
  for (const [key, value] of entries) search.set(key, String(value));
  return `?${search.toString()}`;
}

function optionalDate(raw: unknown): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  return requireValidDate(raw);
}

function requireValidDate(raw: unknown): string {
  if (typeof raw !== 'string' || !DATE_FORMAT.test(raw)) throw new ToolError('invalid date: expected `YYYY-MM-DD`');
  const parsed = new Date(`${raw}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== raw) throw new ToolError('invalid date: expected `YYYY-MM-DD`');
  return raw;
}

function optionalTime(raw: unknown, field: string): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== 'string' || !TIME_FORMAT.test(raw)) throw new ToolError(`invalid time: \`${field}\` expected \`HH:MM\``);
  return raw;
}

function optionalInteger(raw: unknown, field: string): number | undefined {
  if (raw === undefined || raw === null) return undefined;
  return requiredInteger(raw, field);
}

function requiredInteger(raw: unknown, field: string): number {
  if (typeof raw !== 'number' || !Number.isInteger(raw)) throw new ToolError(`${field} must be an integer`);
  return raw;
}

function requireIntegerArray(raw: unknown, field: string): number[] {
  if (!Array.isArray(raw)) throw new ToolError(`${field} must be an array of integers`);
  return raw.map((v) => requiredInteger(v, field));
}

export function idempotencyKey(id: string | number | null, params: Record<string, unknown>): string {
  return `mcp:${sha256Hex(JSON.stringify([id === null ? '' : String(id), deepSort(params)]))}`;
}

function deepSort(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(deepSort);
  if (value && typeof value === 'object') {
    const obj = value as Record<string, unknown>;
    const sorted: Record<string, unknown> = {};
    for (const key of Object.keys(obj).sort()) sorted[key] = deepSort(obj[key]);
    return sorted;
  }
  return value;
}

function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}
