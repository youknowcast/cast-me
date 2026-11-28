# CastMe × Alexa 読み取り API 実装 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> （本 Orca ディスパッチでは、単一 worker が TDD で順に実装する。）

**Goal:** cast-me に家族スコープ Bearer トークン認証の読み取り専用 API `/api/v1`（today / tasks / input_status / family/members）を追加し、Alexa+ 連携（Lambda / MCP / dummy）の Phase 1 を完成させる。設計は `docs/design/2026-11-28-cast-me-alexa-design.md`。

**Architecture:** `namespace :api { namespace :v1 }` に読み取り専用コントローラを追加。`Api::V1::ApplicationController` が `skip_forgery_protection` + `skip authenticate_user!/touch_last_seen/set_calendar_date` + Bearer 認証（`Authorization: Bearer <token>` → `ApiToken.authenticate`）。家族スコープ `api_tokens` テーブル（Ridgepole）+ `ApiToken` モデル（SHA256 digest 保存、`last_used_at`/`revoked_at`、`issue!`）。plans/tasks は `current_family` でスコープ、`Plan.for_date/for_family/ordered_by_time`、`Task.for_date/for_family/for_user/ordered_by_priority` を再利用。`PlanParticipant` status enum。input_status は `tasks` 集計（registered/completed → none/partial/complete）。日付は `Date.parse`、不正 400 `invalid_date`、省略時 Asia/Tokyo 今日（`config.time_zone='Tokyo'`）。v1 は meals/health/medications を返さない。CORS なし、`force_ssl` 不変。TDD。

**Tech Stack:** Ruby 4.0.10 / Rails 8.1 / SQLite / Ridgepole（db/Schemafile）/ RSpec 3.13 + FactoryBot / RuboCop / mise。テストは `mise exec -- bundle exec rspec`（CI と同じく `db:create` + `ridgepole --apply`）。

**Spec:** `docs/design/2026-11-28-cast-me-alexa-design.md`

## Global Constraints

- Ruby 4.0.10、Rails 8.1（`.tool-versions`）。コマンドは `mise exec --`。commit 前に RuboCop（`bundle exec rubocop -A`）と関連 spec。コメントは原則書かない。本体1行メソッドはエンドレス記法。
- Views は Slim（本変更は API のみで不要）。TS/Stimulus 不変。
- DB スキーマは Ridgepole `db/Schemafile`。CI は `db:create` + `ridgepole --apply -f db/Schemafile` + `rspec` + `rubocop`。秘密情報をコミットしない。
- **`/api/v1` 読み取り専用**。CSRF は API のみ skip。CORS 不要。`force_ssl` 不変。
- 認証 `Authorization: Bearer <token>`。**401 `{"error":"unauthorized"}`**。他家族データを返さない。
- `api_tokens`: `family_id`(not null), `name`(not null), `token_digest`(not null, unique), `last_used_at`, `revoked_at`, timestamps。**SHA256 digest**。生トークンは発行時のみ表示。**rake task / console 発行、seed に入れない**。
- 日付 `Date.parse`、**不正 400 `{"error":"invalid_date"}`**、省略時 **Asia/Tokyo 今日**。`config.time_zone='Tokyo'`。
- `display_name` = `User#display_name`。participants status `pending/joined/declined`。`priority` = tasks.priority（0..3）。`completed` 真偽。
- input_status: `registered`+`completed`、**none(0)/partial(未完了あり)/complete(全完了)**、**家族全員既定**、`user_id` 絞り込み可。v1 は meals/health/medications を返さない。
- テストは FactoryBot/fixtures。**本番の real family データを変更しない**。health/meals に触れない。
- **本変更は Phase 1（読み取り API + トークン + doc）のみ。書き込み API / MCP / Lambda / dummy / OneSignal / Google / OAuth は実装しない。**
- **マージしない。PR ready まで。CI 緑確認、失敗/レビュー指摘は修正。** PR は `gh` + リポジトリ `.github` の pull_request_template に従う。

## Review Focus

（spec が示唆するが各タスクのテストで必ずしも踏まない入力/失敗。各行にテストを追加する）

1. **未認証 / 不正トークン / 失効トークン** → 401 `unauthorized`、データを返さない。→ Task 2 のテスト。
2. **他家族トークン** → 自家族以外の plans/tasks/members が混ざらない。`user_id` に他家族 user を指定しても空。→ Task 2, 4, 5, 6, 7 のテスト。
3. **不正日付**（`not-a-date` / 空 / 不正な月日 `2026-13-40`）→ 400 `invalid_date`。→ Task 4, 5, 6 のテスト。
4. **date 省略** → Asia/Tokyo 今日（UTC 日跨ぎで Tokyo の今日）。→ Task 4 のテスト（`travel_to`）。
5. **input_status 境界**: registered=0→none / completed=0→partial / completed==registered→complete / registered>0&&0<completed<registered→partial。→ Task 6 のテスト。
6. **`user_id` フィルタ**: 該当ユーザーのみ、counts もフィルタ後、他家族/存在しない user_id→空。→ Task 5, 6 のテスト。
7. **participants**: pending/joined/declined、`display_name`、participant 0 件。→ Task 4 のテスト。
8. **`start_time`/`end_time` null** → `null`、`"HH:MM"` 整形。→ Task 4 のテスト。
9. **v1 は meals/health/medications を返さない**（体調/食事/服薬レコードがあっても出ない、キーも出さない）。→ Task 4, 5, 6 のテスト。
10. **CSRF**: API は CSRF 無しで動く（GET でも確認、forgery 設定下）。Web 側は不変。→ Task 3 のテスト。

---

## File Structure

| File | 責務 |
|---|---|
| `db/Schemafile` | `api_tokens` テーブル追加（Ridgepole） |
| `app/models/api_token.rb` | 家族スコープトークン。`issue!`, `authenticate`, `digest`, `revoke!`, `revoked?`, `touch_last_used!` |
| `app/models/family.rb` | `has_many :api_tokens, dependent: :destroy` |
| `app/controllers/api/v1/application_controller.rb` | API 共通基盤（CSRF skip, Bearer 認証, `current_family`, 日付解決, 400/401 render） |
| `app/controllers/api/v1/today_controller.rb` | `GET /api/v1/today` |
| `app/controllers/api/v1/tasks_controller.rb` | `GET /api/v1/tasks` |
| `app/controllers/api/v1/input_status_controller.rb` | `GET /api/v1/input_status` |
| `app/controllers/api/v1/family/members_controller.rb` | `GET /api/v1/family/members` |
| `app/serializers/api/v1/plan_serializer.rb` | Plan → `{id,title,start_time,end_time,participants}` |
| `app/serializers/api/v1/task_serializer.rb` | Task → `{id,title,user,completed,priority}` |
| `app/serializers/api/v1/participant_serializer.rb` | PlanParticipant → `{id,display_name,status}` |
| `app/services/api/v1/input_status.rb` | scope → `{registered,completed,status}` |
| `lib/tasks/api_tokens.rake` | `api_tokens:create FAMILY_ID=.. NAME=..`（生トークン一度だけ出力）。revoke は console |
| `config/routes.rb` | `/api/v1` routes |
| `spec/factories/api_tokens.rb` | `api_token` factory（family, name, token_digest。生トークンはテスト側で `issue!` 利用も可） |
| `spec/models/api_token_spec.rb` | digest 保存、issue!、authenticate、revoked、touch_last_used |
| `spec/requests/api/v1/authentication_spec.rb` | 401 群 + 家族分離 + CSRF + last_used_at |
| `spec/requests/api/v1/today_spec.rb` | today 全体 + Asia/Tokyo + invalid_date + participants + 非 v1 除外 |
| `spec/requests/api/v1/tasks_spec.rb` | tasks + counts + user フィルタ + invalid_date + 家族分離 |
| `spec/requests/api/v1/input_status_spec.rb` | none/partial/complete + registered/completed + user フィルタ + invalid_date |
| `spec/requests/api/v1/family/members_spec.rb` | members + 家族分離 + display_name |

---

## Phase 1: cast-me Read API v1（本変更・詳細）

### Task 1: `api_tokens` スキーマ + `ApiToken` モデル + factory

**Files:**
- Modify: `db/Schemafile`
- Create: `app/models/api_token.rb`
- Modify: `app/models/family.rb`
- Create: `spec/factories/api_tokens.rb`
- Test: `spec/models/api_token_spec.rb`

**Interfaces:**
- Produces: `ApiToken.issue!(family:, name:) -> [ApiToken, String raw_token]`
- Produces: `ApiToken.authenticate(raw_token) -> ApiToken | nil`（`revoked_at` non-null は nil、blank は nil）
- Produces: `ApiToken.digest(token) -> String`（SHA256 hex）
- Produces: `ApiToken#revoke!`, `ApiToken#revoked?`, `ApiToken#touch_last_used!`
- Produces: `Family#api_tokens`

- [ ] **Step 1: 失敗するモデルテストを書く** — 生トークンは保存されず SHA256 digest のみ。`issue!` は `[record, raw]`、raw から `authenticate` できる、revoked は nil、`touch_last_used!` が `last_used_at` を更新。`Family#api_tokens`。
- [ ] **Step 2: テストを実行して失敗を確認** — `mise exec -- bundle exec rspec spec/models/api_token_spec.rb` → `ApiToken` uninitialized / table missing。
- [ ] **Step 3: `db/Schemafile` に `api_tokens` を追加**（`family_id` not null + index、`name` not null、`token_digest` not null + unique index、`last_used_at`、`revoked_at`、timestamps）。ridgepole `--apply`。
- [ ] **Step 4: `app/models/api_token.rb` を実装**（`belongs_to :family`、`active` scope、`digest`/`issue!`/`authenticate`/`revoked?`/`revoke!`/`touch_last_used!`、`validates name/token_digest`）。`app/models/family.rb` に `has_many :api_tokens`。
- [ ] **Step 5: `spec/factories/api_tokens.rb`** 追加。
- [ ] **Step 6: テストが通ることを確認**。
- [ ] **Step 7: Commit** `git add db/Schemafile app/models spec/factories spec/models` `git commit -m "feat: add api_tokens table and ApiToken model"`

### Task 2: API v1 認証基盤 `Api::V1::ApplicationController`

**Files:**
- Create: `app/controllers/api/v1/application_controller.rb`
- Test: `spec/requests/api/v1/authentication_spec.rb`

**Interfaces:**
- Consumes: `ApiToken.authenticate`, `ApiToken#touch_last_used!`
- Produces: `Api::V1::ApplicationController < ::ApplicationController`; `#current_api_token`, `#current_family`; `render unauthorized`; `#requested_date`（`nil`=invalid / `Time.zone.today`=省略 / `Date`）; `#render_invalid_date!`; `#apply_user_filter(scope)`。

- [ ] **Step 1: 失敗する request spec を書く**（`GET /api/v1/family/members` を題材に、後続エンドポイント実装前の段階では **認証** のみを確認する最小コントローラを Step 3 で用意）:
  - Authorization ヘッダ無し → 401 `{"error"=>"unauthorized"}`
  - `Bearer invalid` → 401
  - `Authorization: Token xxx` / `Bearer`（トークン無し）/ 空 → 401
  - 失効トークン（`revoked_at` 設定済み）→ 401
  - 他家族トークン → 自家族データのみ（後続 Task と合わせて再確認）
  - 成功時 `last_used_at` が更新される
  - CSRF 無効（forgery 設定下でも通る。`ActionController::Base.allow_forgery_protection` 確認）
- [ ] **Step 2: テスト失敗確認**。
- [ ] **Step 3: `Api::V1::ApplicationController` 実装** + `skip_forgery_protection` + `skip_before_action :authenticate_user!, raise:false` + `skip_before_action :touch_last_seen, raise:false` + `skip_before_action :set_calendar_date, raise:false` + `before_action :authenticate_api_token!`。`Authorization` の `Bearer`（大文字小文字非依存）パース。401 `{error:"unauthorized"}`。`requested_date`（`params[:date]` nil→Asia/Tokyo 今日、`Date.parse` 失敗→nil、`TypeError/ArgumentError` rescue）。TIME_ZONE='Asia/Tokyo'。
- [ ] **Step 4: テストが通ることを確認**。
- [ ] **Step 5: Commit**。

### Task 3: routes `/api/v1`

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1:** `namespace :api { namespace :v1 { ... } }` に `get 'today'`, `get 'tasks'`, `get 'input_status'`, `namespace :family { get 'members' }` を追加（既存 `/api` は不変）。
- [ ] **Step 2:** `bin/rails routes | grep api/v1` で確認。
- [ ] **Step 3: Commit**。

### Task 4: `GET /api/v1/today`

**Files:**
- Create: `app/controllers/api/v1/today_controller.rb`
- Create: `app/serializers/api/v1/plan_serializer.rb`, `app/serializers/api/v1/task_serializer.rb`, `app/serializers/api/v1/participant_serializer.rb`
- Create: `app/services/api/v1/input_status.rb`
- Test: `spec/requests/api/v1/today_spec.rb`

**Interfaces:**
- Consumes: `current_family`, `requested_date`, `render_invalid_date!`, `Plan.for_date/for_family/ordered_by_time`, `Task.for_date/for_family`, `PlanParticipant`。
- Produces: `PlanSerializer.call(plan)`, `TaskSerializer.call(task)`, `ParticipantSerializer.call(plan_participant)`, `InputStatus.call(task_scope) -> {registered:, completed:, status:}`。
- Produces JSON: `{date, family:{id,name}, plans:[...], tasks:[...], input_status:{registered,completed,status}}`。

- [ ] **Step 1: 失敗する request spec を書く**:
  - 認証済みで `date` 指定 → `date`, `family{id,name}`, `plans`, `tasks`, `input_status`。
  - plan: `id,title,start_time("HH:MM"),end_time(null/"HH:MM"),participants[{id,display_name,status}]`。pending/joined/declined。participant 0 件。start/end null。
  - task: `id,title,user{id,display_name},completed,priority`。
  - その日の family のみ。他日・他家族を除外。
  - `input_status` `{registered,completed,status}`。
  - `date` 省略 → Asia/Tokyo 今日（`travel_to` UTC 日跨ぎで Tokyo 今日、その日の plans/tasks）。
  - 不正日付 `not-a-date`/空/`2026-13-40` → 400 `{"error"=>"invalid_date"}`。
  - **v1 は meals/health/medications を返さない**（体調/食事/服薬レコードがあってもキーも含まない）。
- [ ] **Step 2: テスト失敗確認**。
- [ ] **Step 3: serializers + `InputStatus` + `TodayController` 実装**（`plans.ordered_by_time`, tasks `ordered_by_priority`, `includes` で N+1 回避、`for_date`, family scope）。
- [ ] **Step 4: テストが通ることを確認**。
- [ ] **Step 5: Commit**。

### Task 5: `GET /api/v1/tasks`

**Files:**
- Create: `app/controllers/api/v1/tasks_controller.rb`
- Test: `spec/requests/api/v1/tasks_spec.rb`

**Interfaces:**
- Consumes: Task4 の serializer / InputStatus。Produces JSON `{date, tasks:[...], counts:{registered,completed,pending}}`。

- [ ] **Step 1: 失敗する request spec を書く**:
  - `date`, family tasks 配列 + `counts{registered,completed,pending}`。
  - `user_id` フィルタ → そのユーザーのみ、counts もフィルタ後。他家族/存在しない user_id → 空 + counts 0。
  - 不正日付 → 400。他家族非混入。v1 meals/health/medications 非返却。
- [ ] **Step 2: テスト失敗確認**。
- [ ] **Step 3: `TasksController` 実装**（family scope, `for_date`, `for_user`, `ordered_by_priority`, `apply_user_filter`）。
- [ ] **Step 4: テストが通ることを確認**。
- [ ] **Step 5: Commit**。

### Task 6: `GET /api/v1/input_status`

**Files:**
- Create: `app/controllers/api/v1/input_status_controller.rb`
- Test: `spec/requests/api/v1/input_status_spec.rb`

**Interfaces:**
- Consumes: `InputStatus`. Produces JSON `{date, registered, completed, status}`。

- [ ] **Step 1: 失敗する request spec を書く**:
  - `none`: registered=0 → completed=0, status none。
  - `partial`: registered>0, completed<registered（completed=0 含む）→ partial。
  - `complete`: registered>0, completed==registered → complete。
  - `registered`/`completed` 件数。
  - `user_id` 省略=家族全員 / 指定=そのユーザー。他家族 user_id→none。他家族非混入。
  - 不正日付 → 400。
- [ ] **Step 2: テスト失敗確認**。
- [ ] **Step 3: `InputStatusController` 実装**。
- [ ] **Step 4: テストが通ることを確認**。
- [ ] **Step 5: Commit**。

### Task 7: `GET /api/v1/family/members`

**Files:**
- Create: `app/controllers/api/v1/family/members_controller.rb`
- Test: `spec/requests/api/v1/family/members_spec.rb`

**Interfaces:**
- Produces JSON `[{id, display_name}]`。

- [ ] **Step 1: 失敗する request spec を書く** — 自家族のみ `[{id,display_name}]`、`User#display_name`、id 昇順、他家族非混入、未認証 401。
- [ ] **Step 2: テスト失敗確認**。
- [ ] **Step 3: `Api::V1::Family::MembersController` 実装**（`current_family.users.order(:id)`）。
- [ ] **Step 4: テストが通ることを確認**。
- [ ] **Step 5: Commit**。

### Task 8: トークン発行 rake task

**Files:**
- Create: `lib/tasks/api_tokens.rake`

- [ ] **Step 1:** `api_tokens:create`（`FAMILY_ID`, `NAME` 必須、`ApiToken.issue!`、**生トークンを一度だけ stdout**、digest のみ保存）。
- [ ] **Step 2:** `mise exec -- bundle exec rails api_tokens:create FAMILY_ID=1 NAME=alexa-lambda`（テスト DB で確認、生トークンはコミットしない）。
- [ ] **Step 3: Commit**。

### Task 9: 全体検証 + RuboCop + サンプル

- [ ] **Step 1:** `RAILS_ENV=test mise exec -- bundle exec ridgepole -c config/database.yml -E test -r ./config/ridgepole.rb --apply -f db/Schemafile`。
- [ ] **Step 2:** `mise exec -- bundle exec rspec` 全 suite 緑（既存も含む）。出力記録。
- [ ] **Step 3:** `mise exec -- bundle exec rubocop -A` → 再度 `mise exec -- bundle exec rubocop` で 0 offenses。`git diff` で自分の変更のみか確認。
- [ ] **Step 4:** API サンプル（request spec 出力 or 手動 `curl`、トークンは一時発行→破棄、秘密をコミットしない）。
- [ ] **Step 5: Commit**。

---

## Phase 2: MCP サーバー（本変更では実装しない）

- MCP tools: **get_day, create_plan, list_tasks, complete_task, get_input_status, list_family**。
- 置き場**未決**（cast-me 内 / AWS 別サービス）。Phase 3 の dummy **500ms 実測**で決定。
- v1 読み取り API を内部利用。**書き込み（create_plan/complete_task）は Phase 2 で追加**し、二重登録抑止（冪等キー等）を設計。
- 入力状況定義（registered+completed / none/partial/complete / 家族全員既定）は v1 と統一。

## Phase 3: dummy `cast-me-alexa` 検証（本変更では実装しない）

- dummy スキル/MCP で検証シナリオ: 朝/夕方ルーティン、今日の予定/タスク、入力状況、家族メンバー、個人別。
- **`get_day` 500ms レイテンシ実測** → MCP 置き場決定。
- 認証: Bearer トークン / 401 / 失効 / 他家族非混入。将来 **OAuth 2.1 + PKCE**（未決）。
- **二重登録**: リトライ/ルーティン二重発火での重複を確認（Phase 2 の書き込み）。
- **テスト家族**: 本番投入可。`family_id` 分離。real family データは不変。

## Phase 4: Lambda スキル「キャストミー」（別 repo `cast-me-alexa`。本変更では実装しない）

- 朝 **7:00** / 夕方 **19:00** ルーティン。cast-me API pull（Bearer）。
- **APL**、**Echo Show 10 第3世代**。入力状況の声かけ。スキル名「キャストミー」。トークンは秘密管理。

## Phase 5: Alexa+ MCP Add-on（本変更では実装しない）

- Alexa+ が MCP サーバーを利用。**OAuth 2.1 + PKCE**（Amazon 仕様確定待ち、未決）。**Alexa+ の MCP Add-on 仕様は未確定**。

---

## 完了の証拠（本変更）

- PR URL。
- 変更ファイル一覧（設計 doc / plan / `api_tokens` schema+model / `Api::V1` controllers / serializers / `InputStatus` / rake / routes / request specs / factory / model spec）。
- API サンプル（request spec 出力 or curl）。
- RSpec 全緑出力、RuboCop 0 offenses 出力。
- 認証・家族分離・input_status のテスト結果。
