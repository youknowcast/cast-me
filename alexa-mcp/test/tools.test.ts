import { describe, expect, it } from 'vitest';
import { TOOLS, ToolError, Unauthorized, callTool } from '../src/tools';
import { jsonResponse, makeFetchStub } from './helpers';

const TOKEN = 'test-token';
const API_BASE = 'https://castme.example.test';

function call(name: string, args: Record<string, unknown>, id: string | number | null = 1) {
  return { name, args, id, token: TOKEN, apiBase: API_BASE };
}

describe('TOOLS definitions', () => {
  it('exposes exactly the six Rails-MCP-compatible tools', () => {
    expect(TOOLS.map((t) => t.name)).toEqual([
      'get_day',
      'create_plan',
      'list_tasks',
      'complete_task',
      'get_input_status',
      'list_family',
    ]);
  });

  it('each tool has description and inputSchema', () => {
    for (const tool of TOOLS) {
      expect(typeof tool.description).toBe('string');
      expect(tool.description.length).toBeGreaterThan(0);
      expect(tool.inputSchema).toMatchObject({ type: 'object' });
    }
  });
});

describe('get_day', () => {
  it('GETs /api/v1/today forwarding Bearer token, with no date param when omitted', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, { date: '2026-11-28' }));
    await callTool(call('get_day', {}), stub.fetch);
    expect(stub.requests).toHaveLength(1);
    const req = stub.requests[0]!;
    expect(req.method).toBe('GET');
    expect(req.url).toBe('https://castme.example.test/api/v1/today');
    expect(req.headers['authorization']).toBe('Bearer test-token');
  });

  it('appends ?date=YYYY-MM-DD', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await callTool(call('get_day', { date: '2026-11-28' }), stub.fetch);
    expect(stub.requests[0]!.url).toBe('https://castme.example.test/api/v1/today?date=2026-11-28');
  });

  it('returns cast-me JSON as MCP text content', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, { plans: [], tasks: [] }));
    const result = await callTool(call('get_day', {}), stub.fetch);
    expect(result.content).toEqual([{ type: 'text', text: JSON.stringify({ plans: [], tasks: [] }) }]);
  });

  it('rejects a malformed date with ToolError and does not call cast-me', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await expect(callTool(call('get_day', { date: '2026/11/28' }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    expect(stub.requests).toHaveLength(0);
  });

  it('rejects a non-existent calendar date', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await expect(callTool(call('get_day', { date: '2026-02-30' }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    expect(stub.requests).toHaveLength(0);
  });
});

describe('create_plan', () => {
  const args = { date: '2026-11-28', title: '歯医者', start_time: '10:00', end_time: '11:00', participant_ids: [1, 2] };

  it('POSTs /api/v1/plans with body fields and an Idempotency-Key generated from JSON-RPC id', async () => {
    const stub = makeFetchStub(() => jsonResponse(201, { id: 10 }));
    await callTool(call('create_plan', args, 42), stub.fetch);
    expect(stub.requests).toHaveLength(1);
    const req = stub.requests[0]!;
    expect(req.method).toBe('POST');
    expect(req.url).toBe('https://castme.example.test/api/v1/plans');
    expect(req.headers['content-type']).toBe('application/json');
    expect(typeof req.headers['idempotency-key']).toBe('string');
    expect(req.headers['idempotency-key']!.length).toBeGreaterThan(0);
    expect(JSON.parse(req.body!)).toEqual({
      date: '2026-11-28',
      title: '歯医者',
      start_time: '10:00',
      end_time: '11:00',
      participant_ids: [1, 2],
    });
  });

  it('produces a stable Idempotency-Key for identical JSON-RPC id + args', async () => {
    const stub = makeFetchStub(() => jsonResponse(201, {}));
    await callTool(call('create_plan', args, 'abc'), stub.fetch);
    await callTool(call('create_plan', args, 'abc'), stub.fetch);
    expect(stub.requests[0]!.headers['idempotency-key']).toBe(stub.requests[1]!.headers['idempotency-key']);
  });

  it('produces different Idempotency-Keys for different JSON-RPC ids', async () => {
    const stub = makeFetchStub(() => jsonResponse(201, {}));
    await callTool(call('create_plan', args, 'a'), stub.fetch);
    await callTool(call('create_plan', args, 'b'), stub.fetch);
    expect(stub.requests[0]!.headers['idempotency-key']).not.toBe(stub.requests[1]!.headers['idempotency-key']);
  });

  it('omits optional fields from the body when absent', async () => {
    const stub = makeFetchStub(() => jsonResponse(201, {}));
    await callTool(call('create_plan', { date: '2026-11-28', title: 'x' }), stub.fetch);
    expect(JSON.parse(stub.requests[0]!.body!)).toEqual({ date: '2026-11-28', title: 'x' });
  });

  it('requires date and title', async () => {
    const stub = makeFetchStub(() => jsonResponse(201, {}));
    await expect(callTool(call('create_plan', { title: 'x' }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    await expect(callTool(call('create_plan', { date: '2026-11-28' }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
  });

  it('forwards cast-me 4xx as ToolError', async () => {
    const stub = makeFetchStub(() => jsonResponse(422, { error: 'unprocessable_content' }));
    await expect(callTool(call('create_plan', args), stub.fetch)).rejects.toBeInstanceOf(ToolError);
  });

  it('surfaces cast-me 401 as Unauthorized', async () => {
    const stub = makeFetchStub(() => jsonResponse(401, { error: 'unauthorized' }));
    await expect(callTool(call('create_plan', args), stub.fetch)).rejects.toBeInstanceOf(Unauthorized);
  });
});

describe('list_tasks', () => {
  it('GETs /api/v1/tasks with date and user_id', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, { tasks: [] }));
    await callTool(call('list_tasks', { date: '2026-11-28', user_id: 3 }), stub.fetch);
    const url = new URL(stub.requests[0]!.url);
    expect(url.pathname).toBe('/api/v1/tasks');
    expect(url.searchParams.get('date')).toBe('2026-11-28');
    expect(url.searchParams.get('user_id')).toBe('3');
  });

  it('omits optional params', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await callTool(call('list_tasks', {}), stub.fetch);
    expect(stub.requests[0]!.url).toBe('https://castme.example.test/api/v1/tasks');
  });

  it('rejects non-integer user_id', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await expect(callTool(call('list_tasks', { user_id: 'abc' }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    expect(stub.requests).toHaveLength(0);
  });
});

describe('complete_task', () => {
  it('PATCHes /api/v1/tasks/:id/complete', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, { id: 123, completed: true }));
    const result = await callTool(call('complete_task', { task_id: 123 }), stub.fetch);
    expect(stub.requests).toHaveLength(1);
    const req = stub.requests[0]!;
    expect(req.method).toBe('PATCH');
    expect(req.url).toBe('https://castme.example.test/api/v1/tasks/123/complete');
    expect(req.headers['authorization']).toBe('Bearer test-token');
    expect(JSON.parse(result.content[0]!.text)).toEqual({ id: 123, completed: true });
  });

  it('rejects non-integer task_id without calling cast-me', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await expect(callTool(call('complete_task', { task_id: '123' }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    await expect(callTool(call('complete_task', {}), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    expect(stub.requests).toHaveLength(0);
  });

  it('forwards cast-me 404 as ToolError', async () => {
    const stub = makeFetchStub(() => jsonResponse(404, { error: 'not_found' }));
    await expect(callTool(call('complete_task', { task_id: 999 }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
  });

  it('surfaces cast-me 401 as Unauthorized', async () => {
    const stub = makeFetchStub(() => jsonResponse(401, { error: 'unauthorized' }));
    await expect(callTool(call('complete_task', { task_id: 1 }), stub.fetch)).rejects.toBeInstanceOf(Unauthorized);
  });
});

describe('get_input_status', () => {
  it('GETs /api/v1/input_status with date and user_id', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, { status: 'none' }));
    await callTool(call('get_input_status', { date: '2026-11-28', user_id: 2 }), stub.fetch);
    const url = new URL(stub.requests[0]!.url);
    expect(url.pathname).toBe('/api/v1/input_status');
    expect(url.searchParams.get('date')).toBe('2026-11-28');
    expect(url.searchParams.get('user_id')).toBe('2');
  });

  it('rejects non-integer user_id', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await expect(callTool(call('get_input_status', { user_id: 1.5 }), stub.fetch)).rejects.toBeInstanceOf(ToolError);
  });
});

describe('list_family', () => {
  it('GETs /api/v1/family/members', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, [{ id: 1, display_name: 'father' }]));
    const result = await callTool(call('list_family', {}), stub.fetch);
    expect(stub.requests[0]!.url).toBe('https://castme.example.test/api/v1/family/members');
    expect(JSON.parse(result.content[0]!.text)).toEqual([{ id: 1, display_name: 'father' }]);
  });
});

describe('unknown tool', () => {
  it('rejects with ToolError', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    await expect(callTool(call('nope', {}), stub.fetch)).rejects.toBeInstanceOf(ToolError);
    expect(stub.requests).toHaveLength(0);
  });
});
