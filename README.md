# CastMe

家族・個人向けのカレンダー＆タスク管理アプリケーション

## 機能

- 📅 **カレンダー管理** - 個人/家族の予定を一元管理
- ✅ **タスク管理** - 優先度付きタスクの作成・完了管理
- 👨‍👩‍👧‍👦 **家族共有** - 家族メンバー間での予定・タスク共有
- 🔔 **プッシュ通知** - OneSignal連携による定時リマインダー
- 📱 **モバイル対応** - PWA対応のレスポンシブデザイン

## 技術スタック

- Ruby 4.0 / Rails 8.1
- SQLite
- Hotwire (Turbo + Stimulus)
- Tailwind CSS + DaisyUI
- Kamal 2 (デプロイ)

## セットアップ

```bash
# 依存関係のインストール
bundle install
yarn install

# Docker Composeで起動
docker compose up

# ブラウザでアクセス
open http://localhost:1984
```

## 開発

```bash
# テスト実行
bundle exec rspec

# Lintチェック
bundle exec rubocop -A
```

### 家族スコープ API v1 + MCP サーバー（Alexa / LLM 連携）

`Authorization: Bearer <api_token>`（家族スコープ。`SHA256` digest 保存、生トークンは発行時のみ表示、401 `{"error":"unauthorized"}`）。

```bash
# トークン発行（USER_ID は任意。家族内ユーザー。生トークンは一度だけ表示）
bin/rails api_tokens:create FAMILY_ID=1 NAME=alexa-lambda USER_ID=1
```

**読み取り**: `GET /api/v1/today` / `GET /api/v1/tasks` / `GET /api/v1/input_status` / `GET /api/v1/family/members`。
**書き込み**: `POST /api/v1/plans`（`date` strict `YYYY-MM-DD`, `title`, `start_time?`, `end_time?`, `participant_ids?`、同一家族、省略時 token user、参加者0人→422、`Idempotency-Key` 対応、201 + PlanSerializer、400 invalid_date/invalid_time、401、422）、`PATCH /api/v1/tasks/:id/toggle`（family scope、`completed` トグル、TaskSerializer、404）。JSON のみ。
**MCP**: `POST /mcp` JSON-RPC 2.0（Streamable HTTP、SSE 不要）、`initialize`（protocolVersion `2025-11-25`）/ `ping` / `tools/list` / `tools/call` / `notifications/initialized`、Bearer。tools: `get_day`, `create_plan`, `list_tasks`, `complete_task`, `get_input_status`, `list_family`。結果 `{"content":[{"type":"text","text":JSON}]}`、エラー `isError:true`。health / meals / medications 非返却。設計: `docs/design/2026-11-28-cast-me-alexa-design.md` §12。ローカル `tools/call` 実測 ~2-5ms（500ms 要件内）。

### テスト用家族（`test_family`、本番は ria がデプロイ後実行・本 PR は触らない）

```bash
bin/rails test_family                      # ローカル
kamal app exec -i 'bin/rails test_family'  # 本番（ria）
```

冪等。`test_family` 家族 + `test_family_user_1/2` + `user_id` 付き api_token（name `test-family`）を作成し、**生トークンを一度だけ表示**。seed には入れない。real family と `family_id` 分離。手順詳細は design doc §12.5。

### リリースノート

利用者向けの変更は [`RELEASE_NOTES.md`](./RELEASE_NOTES.md) に追記します。見出しは `## YYYY-MM-DD 見出し`、内容は `- ` の箇条書きで、新しい日付を上に書きます。書式の詳細はファイル冒頭のコメントを参照してください。依存更新などの開発者向け変更は載せません。

詳細な開発ガイドラインは [AGENTS.md](./AGENTS.md) を参照してください。

## ライセンス

MIT License - 詳細は [LICENSE](./LICENSE) を参照
