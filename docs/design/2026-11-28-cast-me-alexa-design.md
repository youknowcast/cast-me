# CastMe × Alexa 設計 doc

- 作成日: 2026-11-28
- ステータス: 設計確定 / Phase 1 完了 / Phase 2 実装済み（書き込み API + MCP）/ MCP は AWS Lambda + API Gateway（`alexa-mcp/`）
- スキル名: **キャストミー**（Alexa カスタムスキル）
- 本番: https://castme.daycrift.net（AWS Lightsail / SQLite / Kamal 2）

## 1. 目的

CastMe（家族カレンダー・タスク・体調・食事の Rails 8.1 アプリ）を **音声インターフェース（Alexa+）** から使えるようにする。
具体的には「朝 7:00 のルーティンで今日の予定/タスクを読み上げる」「夕方 19:00 のルーティンで入力状況を確認する」ことを目的とする。

**cast-me 本体はデータ提供のみ**を担う。音声合成・意図解釈・ルーティン実行は Alexa 側、および別 repo の Lambda スキル / MCP サーバーが担う。

### 非ゴール

- **Google カレンダー連携はしない**（Google アカウント未所持の家族がいるため）。
- **OneSignal push は使わない**（本構成は Alexa からの pull 型）。
- **v1 では健康（health）・服薬（medications）・食事（meals）を出さない**。v1 読み取り API は plans / tasks / input_status / family のみ。
- **v1 は読み取り専用**。書き込み API（create_plan / complete_task 等）は v1 では実装しない（MCP tools 案には含めるが Phase 2 以降）。
- 本変更では **MCP サーバー / Lambda / dummy は実装しない**（設計に含めるのみ）。
- health / meals 関連には一切触れない。
- 本番 DB の実データは変更しない。テストは FactoryBot / fixtures で作る。

## 2. 全体構成

```
   [家族メンバー]            [Amazon Alexa / Alexa+]
        │                          │
        ▼                          ▼
  CastMe (Rails)            ┌──────────────────────┐
  cast-me.daycrift.net      │ Lambda カスタムスキル │ ← 朝7:00 / 夕方19:00 ルーティン
   ┌───────────────┐        │ (別 repo cast-me-alexa)│
   │ Read API v1   │◀──pull─┤  ・意図解釈 (intent)   │
   │ /api/v1/*     │        │  ・APL レンダリング     │
   │ api_tokens    │        │  ・Echo Show 10 gen 3   │
   └───────────────┘        └──────────────────────┘
        ▲
        │ pull（サーバー間、Bearer トークン）
        │
   ┌────────────────────┐
   │ MCP サーバー（Phase 2）│ ← 将来 Alexa+ MCP Add-on も同じ API を使う
   │ get_day / list_tasks… │
   └────────────────────┘
```

| コンポーネント | 役割 | 置き場 |
|---|---|---|
| **cast-me Read API** | 家族スコープの読み取り専用 JSON API `/api/v1/*`、Bearer トークン認証 | 本 repo `app/controllers/api/v1/*`（**本変更で実装**） |
| **MCP サーバー** | Alexa+ / 任意 MCP クライアント向け tools 層。cast-me API を内部で叩く。ステートレス。`Authorization: Bearer` を cast-me にそのまま転送（トークン保存しない） | **AWS Lambda + API Gateway HTTP API（us-west-2、provisioned concurrency=1、alias `live`）**。本 repo `alexa-mcp/`（TypeScript + AWS SAM）。`POST /mcp`。`CASTME_API_BASE=https://castme.daycrift.net` |
| **Lambda スキル「キャストミー」** | Alexa カスタムスキル。朝/夕方ルーティン、intent 処理、APL、cast-me API pull | **別 repo `cast-me-alexa`**（本変更では実装しない） |
| **Alexa+ MCP Add-on** | Alexa+ が MCP サーバーをツールとして呼ぶ統合 | Amazon 側仕様。OAuth 2.1 + PKCE は接続時に対応 |
| **Echo Show APL** | Echo Show 10（第3世代）向け画面テンプレート（今日の予定カード、入力状況など） | Lambda スキル側 |
| **ルーティン** | 朝 7:00 / 夕方 19:00 にスキルを起動する Alexa ルーティン | Alexa アプリ設定（ユーザー側） |

### 構成のデータフロー

1. Alexa ルーティン（朝7:00/夕方19:00）→ Lambda「キャストミー」起動。
2. Lambda が `Authorization: Bearer <token>` で cast-me `/api/v1/today` 等を pull。
3. cast-me が家族スコープで JSON を返す（v1 は読み取りのみ）。
4. Lambda が音声テキスト + APL を返す。Echo Show 10 gen 3 で画面表示。
5. 将来 Alexa+ MCP Add-on は MCP サーバー経由で同じ情報/操作を利用。

## 3. 読み取り API 仕様（`/api/v1`、v1 読み取り専用）

### 共通

- **ベースパス**: `/api/v1`。`namespace :api { namespace :v1 }`。
- **認証**: `Authorization: Bearer <token>`。トークン欠落・不正・失効は **401 `{"error":"unauthorized"}`**。
- **家族スコープ**: トークンは `family_id` に紐づく。**他家族のデータは一切返さない**。クエリで family を指定することはできない。
- **CSRF**: API のみ `skip_forgery_protection`。Web 側は変更しない。
- **CORS**: 不要（サーバー間通信）。
- **`force_ssl`**: 本番設定は変更しない（Kamal proxy が HTTPS を終端）。
- **日付**: `date=YYYY-MM-DD`。`date` が文字列で `\A\d{4}-\d{2}-\d{2}\z` に一致する場合のみ `Date.strptime(raw, '%Y-%m-%d')`、**strict `YYYY-MM-DD`**。`date` 省略（`nil`）時のみ **Asia/Tokyo の今日**。文字列以外（Array / `ActionController::Parameters` 等）・形式不一致・実在しない日付は **400 `{"error":"invalid_date"}`**。`Date::Error` / `ArgumentError` / `TypeError` を rescue。（アプリ `config.time_zone = 'Tokyo'`）
- **v1 では meals / health / medications を返さない**。
- `display_name` は既存の `User#display_name`（= `login_id`）。
- `priority` は `tasks.priority`（整数 0..3）。`completed` は真偽値。
- participants の `status` は `PlanParticipant` の enum 文字列 `pending` / `joined` / `declined`。

### エンドポイント

#### `GET /api/v1/today?date=YYYY-MM-DD`

`date` 省略時は Asia/Tokyo の今日。

```json
{
  "date": "2026-11-28",
  "family": { "id": 1, "name": "..." },
  "plans": [
    { "id": 10, "title": "歯医者", "start_time": "10:00", "end_time": null,
      "participants": [ { "id": 1, "display_name": "father", "status": "joined" } ] }
  ],
  "tasks": [
    { "id": 20, "title": "ゴミ出し", "user": { "id": 1, "display_name": "father" },
      "completed": false, "priority": 1 }
  ],
  "input_status": { "registered": 3, "completed": 1, "status": "partial" }
}
```

- `plans`: その日の **family plans**（`plans.date`、`family_id` でスコープ、`start_time` 昇順）。`start_time`/`end_time` は `"HH:MM"` または `null`。`participants` に `id` / `display_name` / `status`。
- `tasks`: その日の **family tasks**（`tasks.date`、`family_id`、全ユーザー）。`user` に `id` / `display_name`。`completed` / `priority`。
- `input_status`: 下記。家族全員が対象（user フィルタなし）。

#### `GET /api/v1/tasks?date=YYYY-MM-DD&user_id=...`

- その日の family tasks の `tasks` 配列 + `counts`。
- `user_id` 指定時はそのユーザーの tasks のみ（他家族の user_id を指定しても何も返らない＝データ混入しない）。
- `counts` はフィルタ適用後の集計: `{ "registered", "completed", "pending" }`。
- `date` 不正は 400 `invalid_date`。

#### `GET /api/v1/input_status?date=YYYY-MM-DD&user_id=...`

```json
{ "date": "2026-11-28", "registered": 3, "completed": 1, "status": "partial" }
```

- `user_id` 省略時は**家族全員**（既定）。指定時はそのユーザーのみ。
- `date` 不正は 400 `invalid_date`。

#### `GET /api/v1/family/members`

```json
[ { "id": 1, "display_name": "father" }, { "id": 2, "display_name": "mother" } ]
```

- 認証トークンの家族のメンバーのみ。`display_name` は `User#display_name`。`id` 昇順。

### 入力状況（input_status）の定義 — 決定事項

- **登録件数 + 完了件数**で判定する（`tasks` ベース。meals/health は見ない）。
  - `registered`: その日・そのスコープ（家族全員 or 指定ユーザー）の tasks 総数。
  - `completed`: うち `completed = true` の数。
- **status**:
  - `none`: `registered == 0`（0件）
  - `partial`: `registered > 0 && completed < registered`（**未完了あり**）
  - `complete`: `registered > 0 && completed == registered`（**全完了**）
- **家族全員を既定**（`user_id` で絞り込み可）。

## 4. トークン認証

- `Authorization: Bearer <token>`。
- **家族スコープ API トークン**を新設。実装は既存 `Api::TokenAuthenticatable` のパターンを参考に。
- **`api_tokens` テーブル（Ridgepole `db/Schemafile` で追加）**:

| カラム | 型 | 説明 |
|---|---|---|
| `family_id` | bigint NOT NULL | 紐づく家族。index |
| `name` | string NOT NULL | 発行名（例: `alexa-lambda`） |
| `token_digest` | string NOT NULL | **SHA256 hex digest**。生トークンは保存しない。unique index |
| `last_used_at` | datetime NULL | 最終使用時刻（認証成功時に更新） |
| `revoked_at` | datetime NULL | 失効時刻。**non-null なら 401** |
| `created_at` / `updated_at` | datetime NOT NULL | |

- **生トークンは発行時に一度だけ表示**。DB には `SHA256(token)` の digest のみ保存。**秘密情報をコミットしない**。
- **発行は rake task / console**（`ApiToken.issue!`）。**seed には入れない**。
  - 例: `bin/rails api_tokens:create FAMILY_ID=1 NAME=alexa-lambda`
- トークン無し・不正・失効は **401 `{"error":"unauthorized"}`**。他家族のデータは返さない。
- digest 比較は digest での検索（`find_by(token_digest: ...)`）。失効チェックは `revoked_at IS NULL`。

## 5. MCP tools 案（Phase 2。**12 で実装済み**）

| tool | 役割 | v1 API との関係 |
|---|---|---|
| `get_day` | 指定日の予定+タスク+入力状況をまとめて返す | `GET /api/v1/today` |
| `create_plan` | 予定を作成 | `POST /api/v1/plans`（Phase 2）。MCP はこれを呼ぶ |
| `list_tasks` | タスク一覧（フィルタ） | `GET /api/v1/tasks` |
| `complete_task` | タスクを完了にする | `PATCH /api/v1/tasks/:id/complete`（冪等。既に completed なら no-op。`completed=true`）。Rails MCP は従来通り |
| `get_input_status` | 入力状況 none/partial/complete | `GET /api/v1/input_status` |
| `list_family` | 家族メンバー一覧 | `GET /api/v1/family/members` |

MCP サーバーは cast-me の API を内部で利用する（**cast-me 本体はデータ API に徹する**）。**入力状況の定義（registered+completed / none/partial/complete / 家族全員既定）は v1 と統一する。** Alexa+ 向け MCP は `alexa-mcp/` の AWS Lambda 版（**12.7**）。Rails MCP（`POST /mcp`）は残す（比較・フォールバック。削除しない）。

## 6. dummy cast-me-alexa 検証フェーズ（Phase 3。本変更では実装しない）

MCP サーバーの置き場（**cast-me 内 / AWS 別サービス**）を決める前に、**dummy `cast-me-alexa`** を立てて検証する。

### 検証シナリオ

1. 朝ルーティン: 今日の plans + tasks + input_status を取得して読み上げ。
2. 夕方ルーティン: 入力状況（none/partial/complete）を確認。
3. 家族メンバー取得 → 個人別タスク照会（user_id フィルタ）。
4. `get_day` のレイテンシ実測。
5. Echo Show APL 表示確認。

### レイテンシ

- **`get_day`（Lambda→cast-me→Lambda→Alexa 全体）の 500ms を実測**し、MCP サーバーの置き場を決める。
  - cast-me 内 MCP vs AWS 別サービス MCP の比較。
- 音声応答は Alexa のタイムアウト（通常 ~8s）内。余裕を見て cast-me 側は十分速く。

### 認証

- dummy でも **Bearer トークン**の動作を検証。テスト用にトークンを発行。
- 401 / 失効 / 他家族トークンの非混入を確認。
- 将来 Alexa+ 接続時は **OAuth 2.1 + PKCE**（MCP 仕様準拠）を検討（**未決**、Alexa+ の MCP Add-on 仕様確定後）。

### 二重登録（double registration）

- 書き込み（create_plan / complete_task）を入れる際、ルーティンの二重発火やリトライで**二重登録が起きないこと**を検証。
- 冪等キー / 重複抑止を Phase 2 設計に含める。**v1 は読み取りのみのため影響なし**だが dummy で確認する。

### テスト家族

- 本番投入可。`real family` とは **`family_id` で分離**した**テスト家族**を本番に投入してよい。
- テスト家族用に家族スコープトークンを発行。real family のデータと混ざらないことを検証。
- **本番 DB の実データ（real family）は変更しない。**

## 7. Lambda スキル（Phase 4。本変更では実装しない）

- **別 repo `cast-me-alexa`**。本 repo はデータ提供のみ。
- **スキル名「キャストミー」**。
- **ルーティン**: 朝 **7:00** / 夕方 **19:00**。
- **APL**: Echo Show 向け画面。**Echo Show 10（第3世代）**を対象。今日の予定カード、タスク、入力状況を表示。音声のみ端末では音声のみ。
- **入力状況の声かけ**: `none`「まだ何も登録されていません」/ `partial`「未完了があります」/ `complete`「すべて完了しています」。
- cast-me API を Bearer トークンで pull。トークンは Lambda 環境変数（Kamal secrets 同様に秘密管理、コミットしない）。

## 8. Alexa+ の不確実性

Alexa+ の **MCP Add-on** の詳細仕様は現時点で完全には公開されていない。以下は**未確定**:

- MCP サーバーの公開要件（ホスティング、TLS、ドメイン）。
- **OAuth 2.1 + PKCE** の認可フロー詳細（Alexa+ 接続時に必要になる可能性）。本変更の Bearer トークンとは別レイヤ。
- Alexa+ が呼ぶ tool の命名・スキーマ確定。
- Echo Show APL と Alexa+ の画面連携。

→ Phase 1（読み取り API）は Alexa+ 仕様に依存しない形で切り出し、Alexa+ 接続は Phase 5 で確定する。

## 9. 決定事項

| # | 決定 |
|---|---|
| D1 | **入力状況は登録件数 + 完了件数**で判定。`status` = **none（0件）/ partial（未完了あり）/ complete（全完了）**。`tasks` ベース、meals/health は見ない。 |
| D2 | **家族全員を既定**。`user_id` で絞り込み可。`input_status` も家族全員既定。 |
| D3 | **Lambda スキルは別 repo `cast-me-alexa`**。本 repo（cast-me）はデータ提供のみ。 |
| D4 | **スキル名「キャストミー」**。 |
| D5 | 読み取り API は **`/api/v1`**、**読み取り専用**。 |
| D6 | **v1 では meals / health / medications を返さない**。health/meals に触れない。 |
| D7 | 認証は **`Authorization: Bearer <token>`**、**家族スコープ `api_tokens`**（SHA256 digest、`last_used_at`、`revoked_at`）。**生トークンは発行時のみ表示、rake/console 発行、seed に入れない、401 `unauthorized`、他家族非混入**。 |
| D8 | **`date=YYYY-MM-DD`、`Date.strptime(raw, '%Y-%m-%d')`、strict `\A\d{4}-\d{2}-\d{2}\z`、String 以外/形式不一致/実在しない日付は 400 `invalid_date`、`Date::Error`/`ArgumentError`/`TypeError` rescue、省略時（`nil`）は Asia/Tokyo の今日**。 |
| D9 | **CSRF は API のみ skip、CORS 不要、`force_ssl` は変更しない**。 |
| D10 | `display_name` は既存 `User#display_name`。participants status は `pending/joined/declined`。`priority` は tasks.priority。 |
| D11 | テスト用データは FactoryBot。**本番の real family データは変更しない**。テスト家族は本番投入可で `family_id` 分離。 |
| D12 | **Google Calendar 不使用、OneSignal 不使用**。 |

## 10. 未決

- **MCP サーバーの置き場**: **決定**。Alexa+ 向け MCP は **AWS Lambda + API Gateway（us-west-2、provisioned concurrency=1）**、本 repo `alexa-mcp/`。cast-me 本体はデータ API のみ。Rails MCP（`POST /mcp`）は残す。詳細 **12.7**。本番 dummy の 500ms 最終実測はデプロイ後（ria）。Rails MCP 内 vs AWS 別サービスの比較実測は当初の検討記録（12.4）。**別 repo にはしない**: デプロイは GitHub Actions OIDC の既存 `castme-deployer` ロールを流用するため（新 repo だと OIDC trust を増やす必要がある）、**本 repo 内 `alexa-mcp/`** に置く。将来分離可能な自己完結構成。
- **OAuth 2.1 + PKCE**: **Alexa+ MCP Add-on 接続時**に対応（Amazon 仕様確定待ち）。Bearer `api_tokens` とは別レイヤ。
- （v1 スコープ外）書き込み API の冪等性・二重登録抑止の詳細は Phase 2。
- Alexa+ の MCP Add-on の tool 命名・スキーマ確定は Amazon 仕様待ち。

## 11. 本変更のスコープ（Phase 1）

- `GET /api/v1/today` / `GET /api/v1/tasks` / `GET /api/v1/input_status` / `GET /api/v1/family/members`（読み取り専用）。
- `api_tokens` テーブル（Ridgepole）+ `ApiToken` モデル + Bearer 認証 + `api_tokens:create` rake task。
- request specs（認証なし 401 / 不正トークン 401 / 他家族非混入 / today / user フィルタ / input_status none/partial/complete / 不正日付 400）。
- 本 doc + `docs/superpowers/plans/2026-11-28-cast-me-alexa.md`。
- **書き込み API / MCP / Lambda / dummy / OneSignal / Google / health / meals は実装しない。**

## 12. Phase 2: 書き込み API + MCP サーバー（実装済み）

Phase 1 の読み取り API に、家族スコープの書き込みと MCP サーバーを追加する。**本番 DB は本 PR では触らない**。OAuth 2.1 + PKCE は未実装（後述）。

### 12.1 書き込み API（家族トークン）

認証は Phase 1 と同じ `Authorization: Bearer <api_token>`。CSRF は API のみ skip、CORS 不要、`force_ssl` 不変。エラーは JSON のみ。

#### `POST /api/v1/plans`

- 入力: `date`（**strict `YYYY-MM-DD`**、必須。不正/実在しない日付は **400 `invalid_date`**）、`title`（必須）、`start_time?` / `end_time?`（**`HH:MM` 24h**、任意。不正は **400 `invalid_time`**、end < start は **422**）、`participant_ids?`（任意）。
- **参加者は同じ family の user のみ**。不明 id / 他家族 user / 非整数は **422**。
- `participant_ids` **省略時は api_token の user を既定**にする（トークンに user が紐づいていない場合は参加者なし）。`participant_ids: []` を明示した場合も参加者なし。
- **参加者が 1 人も決まらない場合は 422**。
- `Plan` + `PlanParticipant`（status `pending`、`created_by`/`last_edited_by` は token user）を作成し、既存 **`Api::V1::PlanSerializer`** で返す。**201 Created**。
- エラー: **400 invalid_date / invalid_time、401、422**。JSON のみ。

#### `PATCH /api/v1/tasks/:id/toggle`

- **family scope**（`current_family.tasks`）。`completed` をトグルして **`Api::V1::TaskSerializer`** で返す。**200**。
- 他家族 / 不明 / 非整数 id は **404 `{"error":"not_found"}`**。401。JSON のみ。

#### `PATCH /api/v1/tasks/:id/complete`

- **family scope**（`current_family.tasks`）。`completed=true` にする（**冪等**。**既に completed なら no-op**）。**`Api::V1::TaskSerializer`** で返す。**200**。
- 他家族 / 不明 / 非整数 id は **404 `{"error":"not_found"}`**。401。JSON のみ。**Alexa MCP `complete_task`（`alexa-mcp/`）はこれを呼ぶ。** request spec `spec/requests/api/v1/task_complete_spec.rb`。

#### 冪等性（`POST /api/v1/plans`）

- 任意の **`Idempotency-Key`** ヘッダー。新テーブル **`api_idempotency_keys`**（Ridgepole）: `family_id`, `key`, `request_hash`, `response_status`, `response_body`, `created_at`（index `(family_id, key)`、`NOT NULL`、no `updated_at`）。
- `request_hash` は **canonical JSON body の SHA256**（deep-sort）。
- **同じ key の再送は保存済みレスポンス（status + body）を返す**（二重作成しない）。
- **同じ key で body が違えば 409**（`idempotency_key_conflict`）。
- key は **家族ごと**。**24 時間**で再利用可能（`created_at` が 24h 以上前のものは無視。期限切れ掃除は任意）。
- 失敗したリクエスト（4xx）は記録せず、同じ key で再試行可能。成功（2xx）のみ保存。Plan 作成 + 冪等性記録はトランザクション。

### 12.2 token user（`api_tokens.user_id`）

- `api_tokens` に **`user_id`（nullable、家族内）** を追加。ユーザーは **token の family に所属**していることをバリデーション。
- 発行: `bin/rails api_tokens:create FAMILY_ID=1 NAME=alexa-lambda [USER_ID=1]`（`USER_ID` は任意。家族外は拒否。生トークンは一度だけ表示、digest のみ保存、seed に入れない）。
- `ApiToken.issue!(family:, name:, user: nil)`。

### 12.3 MCP サーバー（`POST /mcp`、cast-me 内）

- **JSON-RPC 2.0**、**Streamable HTTP（JSON レスポンス、SSE 不要）**。`POST /mcp`。CSRF skip、CORS 不要。
- 認証は既存 `api_tokens`（`Authorization: Bearer`）。**認証失敗は 401 JSON `{"error":"unauthorized"}`**。
- メソッド: **`initialize`**（**`protocolVersion: "2025-11-25"`**、`capabilities.tools`、`serverInfo` `{name:"cast-me", version}`）、**`ping`**（`{}`）、**`tools/list`**、**`tools/call`**、**`notifications/initialized`**（no-response、202）。未知 method は `-32601`、parse error `-32700`、invalid request `-32600`、invalid params `-32602`。
- `tools/call` 結果: `{"content":[{"type":"text","text":"<JSON>"}], ...}`。**エラーは `isError: true` + 内容**。未知 tool は `isError: true`。引数不正は `isError: true`。
- **MCP ホストはまず cast-me 内（Rails）**。Read API と同じ家族スコープ・同じ認証。入力状況定義は v1 と統一。**health / meals / medications は返さない**。
- tools（`description` / `inputSchema` は LLM が選びやすい具体形。**plan = カレンダー予定 / task = やること、日付は `YYYY-MM-DD`** を明記）:
  - **`get_day`**（`date?`）→ `plans` / `tasks` / `input_status`（= `GET /api/v1/today`）。
  - **`create_plan`**（`date`, `title`, `start_time?`, `end_time?`, `participant_ids?`）→ **書き込み API（`POST /api/v1/plans`）を呼ぶ**。`date` 形式 `YYYY-MM-DD`。`participant_ids` は同一家族。省略時は token user。
  - **`list_tasks`**（`date?`, `user_id?`）→ tasks + counts（= `GET /api/v1/tasks`）。
  - **`complete_task`**（`task_id`）→ `completed=true`（PATCH toggle と違い常に完了にする。冪等）。
  - **`get_input_status`**（`date?`, `user_id?`）→ `none/partial/complete` + counts。
  - **`list_family`** → 家族メンバー `[{id, display_name}]`。
- **`create_plan` の冪等性**: 同じ JSON-RPC `id` + 同じ引数の再送は冪等（`api_idempotency_keys`、key `mcp:...`）。`complete_task` は `completed=true` 固定で自然に冪等。
- `create_plan` の participant 省略時は token user。`complete_task` 等の `task_id` / `user_id` は整数。`get_day` 等の `date` 省略時は **Asia/Tokyo 今日**。

### 12.4 500ms 実測（ローカル）

**`POST /mcp` `tools/call` の応答時間をローカル実測**（Rails `test` 環境、SQLite、warmed、`127.0.0.1`、`n=10〜25`、HTTP round-trip、ms）。**Alexa+ からのネットワークは範囲外**。

| tool | n | min | median | mean | max |
|---|---|---|---|---|---|
| `get_day` `{}` | 25 | 3.8 | 4.2 | 5.1 | 20.2 |
| `get_day` `{date}` | 25 | 4.0 | 4.5 | 4.7 | 7.0 |
| `list_tasks` `{}` | 25 | 2.7 | 3.0 | 3.2 | 6.0 |
| `list_tasks` `{date,user_id}` | 25 | 2.7 | 3.3 | 3.4 | 4.4 |
| `get_input_status` `{}` | 25 | 2.1 | 2.8 | 3.1 | 10.0 |
| `list_family` `{}` | 25 | 1.7 | 1.9 | 2.0 | 3.1 |
| `create_plan` | 10 | 4.7 | 5.0 | 6.4 | 17.2 |
| `complete_task` | 10 | 2.2 | 2.5 | 3.2 | 9.5 |

**結論**: ローカルでは全 `tools/call` が **中央値 ~2〜5ms、最大 ~20ms、いずれも 500ms を大きく下回る**。**MCP サーバーはまず cast-me 内（Rails）に置く**判断。AWS 別サービスは不要。本番（Kamal/Lightsail）での再実測はデプロイ後（ria）。

### 12.5 テスト用家族（`lib/tasks/test_family.rake`、未シード・未実行）

- `bin/rails test_family`（本番では `kamal app exec -i 'bin/rails test_family'`）。**冪等**。
- `test_family` 家族 + test users（`test_family_user_1`, `test_family_user_2`）+ **`user_id` 付き api_token**（name `test-family`、token user = 1人目）を作成。**生トークンは一度だけ表示**。real family とは `family_id` で分離。
- **seed には入れない。本 PR では本番 DB を触らない。デプロイ後に ria が実行する。** 再実行では token を再表示しない（既存 token は失効させて再発行するか、初回表示を保存して使う）。token を失った場合は `bin/rails runner 'ApiToken.where(family: Family.find_by(name:"test_family"), name:"test-family").destroy_all'` で失効させて再実行。
- **本番テスト家族投入の手順（ria）**: 1) デプロイ 2) `kamal app exec -i 'bin/rails test_family'` 3) 表示された token を安全に保存 4) `POST /mcp` `initialize` → `tools/list` → `tools/call`（`get_day`, `list_family` 等）を Bearer で実行して疎通確認 5) `POST /api/v1/plans` の dummy 検証（`Idempotency-Key` 再送・409 等）。**この PR では本番を実行しない。**

### 12.6 OAuth 2.1 + PKCE

**未実装**。現状は Phase 1 と同じ **Bearer `api_tokens`**。**Alexa+ の MCP Add-on 接続時に OAuth 2.1 + PKCE（MCP 仕様準拠）を対応する**（Amazon 仕様確定待ち。Bearer とは別レイヤ）。MCP 置き場は **AWS Lambda + API Gateway（`alexa-mcp/`）**（12.7）。Rails MCP は残す。

### 12.7 MCP サーバー: AWS Lambda + API Gateway（`alexa-mcp/`）

Phase 2 の Rails MCP（`POST /mcp`、cast-me 内、**残す・削除しない**）の**機能をそのまま、cast-me とは別の AWS サービス**に移した版。**本番 dummy 実測で Rails MCP が 500ms に届かない（median ~746ms / max ~1623ms）**ため、**Alexa+ 向け MCP を AWS Lambda + API Gateway** に置く。

- **場所**: 本 repo `alexa-mcp/`（**別 repo にしない**）。**置き場は cast-me 内 MCP から AWS 別サービスへ変更**（10 参照）。
- **別 repo にしない理由**: デプロイは GitHub Actions **OIDC** の既存 **`castme-deployer`** ロールを使う。新 repo だと **OIDC trust policy に repo を追加する必要**がある。本 repo 内 `alexa-mcp/` にすれば OIDC 変更不要。**将来分離可能**: `alexa-mcp/` は自己完結（独自 `package.json` / `template.yaml` / workflow `deploy-alexa-mcp.yml`）。**本番 DB・秘密情報は触らない**。
- **cast-me 本体はデータ API のみ**: MCP サーバーは cast-me `/api/v1/*` を呼ぶ。**Rails アプリに MCP/音声ロジックを足さない**。
- **構成**: `AWS::Serverless::HttpApi` + `AWS::Serverless::Function`（**Node 22**、`POST /mcp`、`CASTME_API_BASE=https://castme.daycrift.net`、`AWS::Serverless` **alias `live`** + **`ProvisionedConcurrentExecutions: 1`**）。**us-west-2**。**Lambda ステートレス**。**provisioned concurrency で cold start 回避**。カスタムドメイン不要。API URL `https://<api-id>.execute-api.us-west-2.amazonaws.com/mcp`。
- **認証**: クライアントの **`Authorization: Bearer <cast-me api token>`** をそのまま cast-me API に転送。**トークン保存しない**。**認証なし・不正トークンは 401 JSON**。**cast-me の 401 をそのまま返す**。
- **MCP**: **2025-11-25 / JSON-RPC 2.0 / Streamable HTTP（JSON、SSE 不要）**。`initialize` / `ping` / `tools/list` / `tools/call` / `notifications/initialized`。serverInfo `{name:"cast-me", version}`。`complete_task` は `PATCH /api/v1/tasks/:id/complete`。**tools（description/inputSchema）は Rails MCP と同じ具体性**。**health / meals は返さない**。**500ms を意識し、cast-me API 呼び出しは並列化しない（各 tool 1 リクエスト）**。`create_plan` の **`Idempotency-Key` は JSON-RPC `id` から生成**。
- **構成ファイル**: `alexa-mcp/template.yaml`, `package.json`, `tsconfig.json`, `src/index.ts`, `src/tools.ts`, `test/`, `README.md`, `.github/workflows/deploy-alexa-mcp.yml`。
- **デプロイ**: `.github/workflows/deploy-alexa-mcp.yml`（`push` `alexa-mcp/**` + `workflow_dispatch`、`permissions: id-token: write, contents: read`、`aws-actions/configure-aws-credentials` role `arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/castme-deployer` region `us-west-2`、`pip install aws-sam-cli`、`sam build`、`sam deploy --stack-name castme-alexa-mcp --region us-west-2 --capabilities CAPABILITY_IAM --no-confirm-changeset --no-fail-on-empty-changeset`、Output `McpApiUrl` を summary）。**本 PR では実 AWS デプロイしない**（マージ後の workflow。ローカル AWS creds なし）。
- **IAM 注意**: `castme-deployer` に **Lambda / API Gateway / CloudFormation / IAM（Lambda 実行ロール作成）** の権限が必要（`lambda:*`, `apigatewayv2:*`, `cloudformation:*`, `iam:CreateRole/DeleteRole/AttachRolePolicy/DetachRolePolicy/PutRolePolicy/DeleteRolePolicy/PassRole`, `s3:*` 等）。**権限がないと deploy で失敗する。無理に回避しない。**
- **OAuth 2.1 + PKCE** は **Alexa+ 接続時**（12.6）。
