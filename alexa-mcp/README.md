# CastMe Alexa+ MCP server (`alexa-mcp/`)

Stateless **MCP 2025-11-25** server on **AWS Lambda + API Gateway HTTP API** (`us-west-2`), JSON-RPC 2.0, Streamable HTTP (JSON responses, no SSE).

- **Transport**: `POST /mcp`, `Content-Type: application/json`.
- **Endpoint**: `https://<api-id>.execute-api.us-west-2.amazonaws.com/mcp`. No custom domain.
- **Auth**: client sends `Authorization: Bearer <cast-me api token>`. The header is forwarded unchanged to the cast-me data API. **No token is stored.** Missing/invalid token → `401 {"error":"unauthorized"}`; cast-me `401` is returned verbatim.
- **Cold starts**: `AutoPublishAlias: live` + `ProvisionedConcurrentExecutions: 1`.
- **cast-me stays the data API**: `CASTME_API_BASE=https://castme.daycrift.net`.
- Latency target: **500ms**; cast-me calls are sequential, **one request per tool** (no fan-out).

## MCP methods

`initialize` (`protocolVersion: "2025-11-25"`, `capabilities.tools`, `serverInfo {name:"cast-me", version}`), `ping`, `tools/list`, `tools/call`, `notifications/initialized` (no body, `202`). Unknown method → `-32601`, parse error → `-32700`, invalid request → `-32600`. `tools/call` errors → `isError: true`; invalid token → `401`. Existing Rails MCP (`POST https://castme.daycrift.net/mcp`) is unchanged (comparison / fallback).

## Tools (same as Rails MCP; no health / meals)

| tool | cast-me request |
|---|---|
| `get_day` (`date?` `YYYY-MM-DD`, default today Asia/Tokyo) | `GET /api/v1/today` |
| `create_plan` (`date`, `title`, `start_time?`, `end_time?`, `participant_ids?`) | `POST /api/v1/plans`, `Idempotency-Key` generated from JSON-RPC `id` + args |
| `list_tasks` (`date?`, `user_id?`) | `GET /api/v1/tasks` |
| `complete_task` (`task_id`) | `PATCH /api/v1/tasks/:id/complete` (idempotent; already-completed is a no-op) |
| `get_input_status` (`date?`, `user_id?`) | `GET /api/v1/input_status` |
| `list_family` | `GET /api/v1/family/members` |

`description` / `inputSchema` match Rails MCP. A *plan* is a calendar event; a *task* is a todo. `user_id` / `participant_ids` are integers from `list_family`, same family only. `complete_task` `task_id` is an integer.

## Layout

- `src/index.ts` — Lambda handler + JSON-RPC 2.0 dispatch, auth, `initialize`/`ping`/`tools/list`/`tools/call`/`notifications/*`, `CASTME_API_BASE`.
- `src/tools.ts` — six tool definitions + cast-me request construction, `Idempotency-Key`, validation.
- `template.yaml` — SAM: `AWS::Serverless::HttpApi` + `AWS::Serverless::Function` (Node 22, `POST /mcp`, provisioned concurrency, `CASTME_API_BASE`).
- `test/` — vitest unit tests (request construction, JSON-RPC, `401`, invalid tool).

## Local

```sh
npm ci
npm run lint
npm test
npm run typecheck
npm run build          # tsc -> dist
sam validate --region us-west-2
sam build              # needs dist/ from `npm run build`
```

## Deploy

Deployed by `.github/workflows/deploy-alexa-mcp.yml` on push to `alexa-mcp/**` or `workflow_dispatch`, using GitHub Actions **OIDC**:

```sh
aws-actions/configure-aws-credentials
  role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/castme-deployer
  aws-region: us-west-2
```

`permissions: { id-token: write, contents: read }`, `pip install aws-sam-cli`, `sam build`, then:

```sh
sam deploy --stack-name castme-alexa-mcp --region us-west-2 \
  --capabilities CAPABILITY_IAM --no-confirm-changeset --no-fail-on-empty-changeset
```

API URL is printed to the workflow summary (`McpApiUrl` output). No real AWS deploy is done in this PR (no local AWS credentials).

**`castme-deployer` role needs**: `cloudformation:*` (or at least Create/Update/DeleteStack, CreateChangeSet/ExecuteChangeSet, Describe*), `lambda:CreateFunction/UpdateFunctionCode/UpdateFunctionConfiguration/DeleteFunction/PublishVersion/AddPermission/GetFunction/InvokeFunction`, `lambda:CreateAlias/UpdateAlias/DeleteAlias`, `lambda:PutProvisionedConcurrencyConfig/DeleteProvisionedConcurrencyConfig`, `apigatewayv2:*` (CreateApi/UpdateApi/DeleteApi/CreateIntegration/CreateRoute/CreateStage/UpdateStage + tagging), `iam:CreateRole/DeleteRole/AttachRolePolicy/DetachRolePolicy/PutRolePolicy/DeleteRolePolicy/GetRole/PassRole` (Lambda execution role `AWS::IAM::Role`), `s3:*` (SAM artifact bucket), `sts:GetCallerIdentity`. **No attempt is made to bypass permissions; if deploy fails on `AccessDenied`, add these to `castme-deployer`.**

## Dummy calls

Test token: `/tmp/castme-test-family.out` (not committed). `API_URL=https://<api-id>.execute-api.us-west-2.amazonaws.com/mcp`. `TOKEN=$(cat /tmp/castme-test-family.out)`.

```sh
# initialize
curl -sS "$API_URL" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"dummy","version":"1.0.0"}}}'

# notifications/initialized
curl -sS -o /dev/null -w '%{http_code}\n' "$API_URL" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'

# tools/list
curl -sS "$API_URL" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

# tools/call get_day
curl -sS "$API_URL" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_day","arguments":{}}}'

# tools/call list_family
curl -sS "$API_URL" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"list_family","arguments":{}}}'

# 401 checks
curl -sS -o /dev/null -w '%{http_code}\n' "$API_URL" -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":5,"method":"ping"}'
curl -sS -o /dev/null -w '%{http_code}\n' "$API_URL" -H 'Authorization: Bearer nope' -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":6,"method":"ping"}'
```

**500ms** final check is done post-deploy by `ria` against dummy; not in this PR.
