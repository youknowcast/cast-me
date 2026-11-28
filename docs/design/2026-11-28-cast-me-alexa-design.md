# CastMe × Alexa 設計 doc

- 作成日: 2026-11-28
- ステータス: 設計確定 / Phase 1 実装中
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
| **MCP サーバー** | Alexa+ / 任意 MCP クライアント向け tools 層。内部で Read API（将来は同等の権限で DB 直）を叩く | **未決**（cast-me 内 / AWS 別サービス。dummy の 500ms 実測で決める） |
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

## 5. MCP tools 案（Phase 2。本変更では実装しない）

| tool | 役割 | v1 API との関係 |
|---|---|---|
| `get_day` | 指定日の予定+タスク+入力状況をまとめて返す | `GET /api/v1/today` |
| `create_plan` | 予定を作成 | **v1 読み取りのみ。Phase 2 で書き込み API を追加** |
| `list_tasks` | タスク一覧（フィルタ） | `GET /api/v1/tasks` |
| `complete_task` | タスクを完了にする | **v1 読み取りのみ。Phase 2** |
| `get_input_status` | 入力状況 none/partial/complete | `GET /api/v1/input_status` |
| `list_family` | 家族メンバー一覧 | `GET /api/v1/family/members` |

MCP サーバーは cast-me の Read API を内部で利用する（または同一 DB を家族スコープで参照）。**入力状況の定義（registered+completed / none/partial/complete / 家族全員既定）は v1 と統一する。**

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

- **MCP サーバーの置き場**: cast-me 内 / AWS 別サービス。**dummy `cast-me-alexa` の `get_day` 500ms 実測で決める**（Phase 3）。
- **OAuth 2.1 + PKCE**: Alexa+ MCP Add-on 接続時に対応要否を判断（Amazon 仕様確定待ち）。
- （v1 スコープ外）書き込み API の冪等性・二重登録抑止の詳細は Phase 2。
- Alexa+ の MCP Add-on の tool 命名・スキーマ確定は Amazon 仕様待ち。

## 11. 本変更のスコープ（Phase 1）

- `GET /api/v1/today` / `GET /api/v1/tasks` / `GET /api/v1/input_status` / `GET /api/v1/family/members`（読み取り専用）。
- `api_tokens` テーブル（Ridgepole）+ `ApiToken` モデル + Bearer 認証 + `api_tokens:create` rake task。
- request specs（認証なし 401 / 不正トークン 401 / 他家族非混入 / today / user フィルタ / input_status none/partial/complete / 不正日付 400）。
- 本 doc + `docs/superpowers/plans/2026-11-28-cast-me-alexa.md`。
- **書き込み API / MCP / Lambda / dummy / OneSignal / Google / health / meals は実装しない。**
