import type { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import { TOOLS, ToolError, Unauthorized, callTool, type FetchImpl } from './tools';

const PROTOCOL_VERSION = '2025-11-25';
const SERVER_INFO = { name: 'cast-me', version: '1.0.0' };
const DEFAULT_API_BASE = 'https://castme.daycrift.net';
const UNAUTHORIZED_BODY = JSON.stringify({ error: 'unauthorized' });

const PARSE_ERROR = -32700;
const INVALID_REQUEST = -32600;
const METHOD_NOT_FOUND = -32601;

interface JsonRpcRequest {
  jsonrpc: '2.0';
  id: string | number | null;
  method: string;
  params?: unknown;
}

export async function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> {
  const token = bearerToken(event.headers ?? {});
  if (!token) return json(401, UNAUTHORIZED_BODY);

  const apiBase = process.env['CASTME_API_BASE'] ?? DEFAULT_API_BASE;
  const fetchImpl: FetchImpl = fetch;

  try {
    return await dispatch(event, { token, apiBase, fetchImpl });
  } catch (err) {
    if (err instanceof Unauthorized) return json(401, err.body || UNAUTHORIZED_BODY);
    throw err;
  }
}

async function dispatch(
  event: APIGatewayProxyEventV2,
  ctx: { token: string; apiBase: string; fetchImpl: FetchImpl },
): Promise<APIGatewayProxyResultV2> {
  const rawBody = event.isBase64Encoded ? Buffer.from(event.body ?? '', 'base64').toString('utf8') : (event.body ?? '');

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return rpcResponse(null, { code: PARSE_ERROR, message: 'Parse error' }, false);
  }

  if (!isValidRpc(parsed)) {
    return rpcResponse(extractId(parsed), { code: INVALID_REQUEST, message: 'Invalid Request' }, false);
  }

  const rpc = parsed;
  const { id, method } = rpc;

  if (method.startsWith('notifications/')) {
    await verifyToken(ctx);
    return json(202, '');
  }

  switch (method) {
    case 'initialize':
      await verifyToken(ctx);
      return rpcResponse(id, { protocolVersion: PROTOCOL_VERSION, capabilities: { tools: {} }, serverInfo: SERVER_INFO }, true);
    case 'ping':
      await verifyToken(ctx);
      return rpcResponse(id, {}, true);
    case 'tools/list':
      await verifyToken(ctx);
      return rpcResponse(id, { tools: TOOLS }, true);
    case 'tools/call':
      return toolsCall(rpc, ctx);
    default:
      await verifyToken(ctx);
      return rpcResponse(id, { code: METHOD_NOT_FOUND, message: 'Method not found' }, false);
  }
}

async function toolsCall(rpc: JsonRpcRequest, ctx: { token: string; apiBase: string; fetchImpl: FetchImpl }): Promise<APIGatewayProxyResultV2> {
  const params = isRecord(rpc.params) ? rpc.params : {};
  const name = params['name'];
  const args = isRecord(params['arguments']) ? params['arguments'] : {};

  if (typeof name !== 'string' || name.length === 0) {
    return toolError(rpc.id, 'tools/call requires a tool name');
  }

  if (!TOOLS.some((t) => t.name === name)) {
    await verifyToken(ctx);
    return toolError(rpc.id, `Unknown tool: ${name}`);
  }

  try {
    const result = await callTool({ name, args, id: rpc.id, token: ctx.token, apiBase: ctx.apiBase }, ctx.fetchImpl);
    return rpcResponse(rpc.id, result, true);
  } catch (err) {
    if (err instanceof Unauthorized) throw err;
    if (err instanceof ToolError) return toolError(rpc.id, err.message);
    throw err;
  }
}

function toolError(id: string | number | null, message: string): APIGatewayProxyResultV2 {
  return rpcResponse(id, { content: [{ type: 'text', text: JSON.stringify({ error: message }) }], isError: true }, true);
}

async function verifyToken(ctx: { token: string; apiBase: string; fetchImpl: FetchImpl }): Promise<void> {
  const res = await ctx.fetchImpl(`${ctx.apiBase.replace(/\/+$/, '')}/api/v1/family/members`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${ctx.token}`, Accept: 'application/json' },
  });
  if (res.status === 401) {
    const body = await res.text();
    throw new Unauthorized(body || UNAUTHORIZED_BODY);
  }
}

function rpcResponse(id: string | number | null, payload: unknown, isResult: boolean): APIGatewayProxyResultV2 {
  const body = isResult ? { jsonrpc: '2.0', id, result: payload } : { jsonrpc: '2.0', id, error: payload };
  return json(200, JSON.stringify(body));
}

function json(statusCode: number, body: string): APIGatewayProxyResultV2 {
  return { statusCode, headers: { 'Content-Type': 'application/json' }, body };
}

function isValidRpc(value: unknown): value is JsonRpcRequest {
  if (!isRecord(value)) return false;
  if (value['jsonrpc'] !== '2.0') return false;
  if (typeof value['method'] !== 'string') return false;
  const id = value['id'];
  if (id !== undefined && id !== null && typeof id !== 'string' && typeof id !== 'number') return false;
  return true;
}

function extractId(value: unknown): string | number | null {
  if (isRecord(value)) {
    const id = value['id'];
    if (typeof id === 'string' || typeof id === 'number') return id;
  }
  return null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function bearerToken(headers: Record<string, string | undefined>): string | null {
  const auth = headerValue(headers, 'authorization');
  if (!auth) return null;
  const match = /^\s*Bearer\s+(.+?)\s*$/i.exec(auth);
  if (!match) return null;
  const token = match[1]?.trim();
  return token ? token : null;
}

function headerValue(headers: Record<string, string | undefined>, name: string): string | undefined {
  const target = name.toLowerCase();
  for (const [key, value] of Object.entries(headers)) {
    if (key.toLowerCase() === target) return value;
  }
  return undefined;
}
