import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { handler } from '../src';
import { jsonResponse, makeFetchStub } from './helpers';

const API_BASE = 'https://castme.example.test';
const TOKEN = 'test-token';

function event(body: string | undefined, headers: Record<string, string> = {}): APIGatewayProxyEventV2 {
  return {
    version: '2.0',
    routeKey: 'POST /mcp',
    rawPath: '/mcp',
    rawQueryString: '',
    headers: { 'content-type': 'application/json', ...headers },
    requestContext: {} as APIGatewayProxyEventV2['requestContext'],
    isBase64Encoded: false,
    body,
  };
}

function rpc(method: string, params?: unknown, id: string | number | null = 1, headers: Record<string, string> = {}): APIGatewayProxyEventV2 {
  return event(JSON.stringify({ jsonrpc: '2.0', id, method, ...(params === undefined ? {} : { params }) }), {
    authorization: `Bearer ${TOKEN}`,
    ...headers,
  });
}

beforeEach(() => {
  process.env.CASTME_API_BASE = API_BASE;
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('authentication', () => {
  it('returns 401 JSON without an Authorization header', async () => {
    const res = await handler(event(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'initialize' })));
    expect(res.statusCode).toBe(401);
    expect(JSON.parse((res as { body: string }).body)).toEqual({ error: 'unauthorized' });
  });

  it('returns 401 JSON with a non-Bearer Authorization header', async () => {
    const res = await handler(rpc('initialize', undefined, 1, { authorization: 'Basic abc' }));
    expect(res.statusCode).toBe(401);
  });

  it('returns 401 JSON with an empty Bearer token', async () => {
    const res = await handler(rpc('initialize', undefined, 1, { authorization: 'Bearer ' }));
    expect(res.statusCode).toBe(401);
  });

  it('forwards cast-me 401 verbatim for an invalid token on tools/call', async () => {
    const stub = makeFetchStub(() => jsonResponse(401, { error: 'unauthorized' }));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('tools/call', { name: 'list_family', arguments: {} }));
    expect(res.statusCode).toBe(401);
    expect(JSON.parse((res as { body: string }).body)).toEqual({ error: 'unauthorized' });
  });

  it('returns 401 for an invalid token on initialize', async () => {
    const stub = makeFetchStub(() => jsonResponse(401, { error: 'unauthorized' }));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('initialize', { protocolVersion: '2025-11-25' }));
    expect(res.statusCode).toBe(401);
    expect(JSON.parse((res as { body: string }).body)).toEqual({ error: 'unauthorized' });
  });

  it('forwards the client Bearer token to cast-me unchanged', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    await handler(rpc('tools/call', { name: 'list_family', arguments: {} }, 1, { authorization: 'Bearer secret-xyz' }));
    expect(stub.requests[0]!.headers['authorization']).toBe('Bearer secret-xyz');
  });
});

describe('initialize', () => {
  it('returns protocolVersion 2025-11-25, capabilities.tools, serverInfo', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('initialize', { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'x', version: '1' } }));
    expect(res.statusCode).toBe(200);
    const body = JSON.parse((res as { body: string }).body);
    expect(body.jsonrpc).toBe('2.0');
    expect(body.id).toBe(1);
    expect(body.result.protocolVersion).toBe('2025-11-25');
    expect(body.result.capabilities.tools).toEqual({});
    expect(body.result.serverInfo.name).toBe('cast-me');
    expect(typeof body.result.serverInfo.version).toBe('string');
  });
});

describe('ping', () => {
  it('returns empty result', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('ping'));
    expect(JSON.parse((res as { body: string }).body).result).toEqual({});
  });
});

describe('notifications/initialized', () => {
  it('returns 202 with empty body', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(event(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }), { authorization: `Bearer ${TOKEN}` }));
    expect(res.statusCode).toBe(202);
    expect((res as { body: string }).body).toBe('');
  });
});

describe('tools/list', () => {
  it('lists the six tools', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('tools/list'));
    const tools = JSON.parse((res as { body: string }).body).result.tools;
    expect(tools.map((t: { name: string }) => t.name)).toEqual([
      'get_day',
      'create_plan',
      'list_tasks',
      'complete_task',
      'get_input_status',
      'list_family',
    ]);
  });
});

describe('tools/call', () => {
  it('returns isError content for an invalid tool', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('tools/call', { name: 'nope', arguments: {} }));
    const body = JSON.parse((res as { body: string }).body);
    expect(res.statusCode).toBe(200);
    expect(body.result.isError).toBe(true);
    expect(body.result.content[0].type).toBe('text');
  });

  it('returns isError when tool arguments are invalid', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('tools/call', { name: 'complete_task', arguments: { task_id: 'x' } }));
    const body = JSON.parse((res as { body: string }).body);
    expect(body.result.isError).toBe(true);
  });

  it('defaults arguments to {} when absent', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, {}));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('tools/call', { name: 'list_family' }));
    expect(JSON.parse((res as { body: string }).body).result.isError).not.toBe(true);
  });
});

describe('JSON-RPC framing', () => {
  it('returns -32700 parse error on invalid JSON', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(event('{not json', { authorization: `Bearer ${TOKEN}` }));
    const body = JSON.parse((res as { body: string }).body);
    expect(body.error.code).toBe(-32700);
    expect(body.id).toBeNull();
  });

  it('returns -32600 invalid request when jsonrpc is not 2.0', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(event(JSON.stringify({ jsonrpc: '1.0', id: 1, method: 'ping' }), { authorization: `Bearer ${TOKEN}` }));
    expect(JSON.parse((res as { body: string }).body).error.code).toBe(-32600);
  });

  it('returns -32600 invalid request when method is missing', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(event(JSON.stringify({ jsonrpc: '2.0', id: 1 }), { authorization: `Bearer ${TOKEN}` }));
    expect(JSON.parse((res as { body: string }).body).error.code).toBe(-32600);
  });

  it('returns -32601 method not found', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('no/such/method'));
    const body = JSON.parse((res as { body: string }).body);
    expect(body.error.code).toBe(-32601);
    expect(body.id).toBe(1);
  });

  it('echoes a string id', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(rpc('ping', undefined, 'abc'));
    expect(JSON.parse((res as { body: string }).body).id).toBe('abc');
  });

  it('returns JSON-RPC error for a notification-style invalid request without id', async () => {
    const stub = makeFetchStub(() => jsonResponse(200, []));
    vi.stubGlobal('fetch', stub.fetch);
    const res = await handler(event(JSON.stringify({ jsonrpc: '2.0', method: 'ping', id: null }), { authorization: `Bearer ${TOKEN}` }));
    expect(res.statusCode).toBe(200);
  });
});
