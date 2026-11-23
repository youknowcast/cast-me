# AGENTS.md - Context & Summary for AI Agents

## Project Overview
**CastMe** is a Ruby on Rails application focused on personal/family organization. It provides features for calendar management, task tracking, and planning. The application is built to be responsive and interactive using modern Rails techniques (Hotwire).

## Tech Stack
### Backend
-   **Framework**: Ruby on Rails 8.1
-   **Language**: Ruby (version specified in `.tool-versions`)
-   **Database**: SQLite (configured for Development, Test, and Production in `config/database.yml`)
    -   *ORM*: Active Record

### Frontend
-   **Templating**: Slim (`.slim`) files instead of standard ERB.
-   **CSS Framework**: Tailwind CSS v4 (via `tailwindcss-rails`) + daisyUI 5.
-   **Interactivity**: Hotwire (Turbo + Stimulus).
-   **Scripting**: TypeScript (compiled via `esbuild`).
-   **Icons**: Likely FontAwesome or Heroicons (inferred from usage patterns generally, to be verified in views).

## Key Domain Models
-   **User**: Authentication managed via Devise.
-   **Plan**: Represents calendar events. Supports multiple **participants** (users) via `PlanParticipant`. Tracks `last_edited_by_id`.
-   **Task**: Represents actionable items, categorized by priority.
-   **PlanParticipant**: Junction model for Users and Plans, tracking `status` (joined, declined, pending).
-   **Family**: Represents groups of users for shared visibility.

## Architecture Highlights
-   **Mobile Optimization**: Uses a fixed Bottom Navigation Bar (`_bottom_nav.html.slim`) on mobile instead of the sidebar. Content stacks vertically on smaller screens.
-   **Calendar Interactivity**:
    -   Uses **Turbo Frames** (`daily_details`) for sectional updates.
    -   **Unified Interaction**: `calendar_interaction_controller.ts` manages both date selection and user filtering, ensuring state (date, user, scope) is preserved.
-   **File-based Separation**: "My" and "Family" views are separated into `my.html.slim` and `index.html.slim` with dedicated routes (`/calendar/my` and `/calendar`).
-   **Grouping**: Family daily view groups items by User.
-   **Data Consistency**: Uses `CalendarData` concern in controllers to standardize schedule fetching across different actions (Create/Update/Filter).
-   **Side Panel**: A dedicated side panel container (`#side-panel`) exists in the layout for dynamic content loading (e.g., forms).

## Key Principles
-   **Mutual Family Management**: In the "Family" view, family members can manage each other's participation status (Joined, Declined, Pending) and tasks. This fosters collaborative family scheduling.
-   **Context-Aware UI**: The application must always know if it's in a "My" (personal) or "Family" (shared) context, strictly filtering data and adjusting UI controls (like user selectors) accordingly.

## Development Guidelines
1.  **Views**: Always use **Slim** syntax. Do not create `.erb` files.
2.  **Styling**: Use **Tailwind CSS** + **DaisyUI**.
3.  **JavaScript**:
    -   Standard Stimulus setup: `application.js` imports `controllers/index.js`, which uses `controllers/application.js` for the instance.
    -   Use **TypeScript** (`.ts`) for controllers.
    -   Avoid inline JavaScript.
4.  **Testing**: Use **RSpec** (`spec/`).
5.  **Local Verification**:
    -   The application is hosted via Docker Compose.
    -   Access the local development environment at **[http://localhost:1984](http://localhost:1984)**.
    -   **CRITICAL**: Do not use port 3000 for local browser verification, as it is not the external port mapped by Docker.
6.  **Code Quality**:
    -   **CRITICAL**: After making any code changes, always run `rubocop -A` (or `bundle exec rubocop -A`) to ensure the code follows the project's style guide and to auto-fix any offenses. Always verify that no new offenses were introduced.

## Key Configuration Files
-   `Procfile.dev`: Runs Rails and `yarn build --watch` for JS.
-   `package.json`: Build script uses `esbuild` targeting `app/javascript/application.js`.
-   `app/assets/tailwind/application.css`: Tailwind v4 のエントリポイント。v4 は CSS ファースト設定なので `tailwind.config.js` は存在せず、プラグイン (`@plugin`) / スキャン対象 (`@source`) / テーマ (`@theme`) をすべてこのファイルに書く。daisyUI 5 で削除された `form-control` / `label` / `label-text` の互換定義もここにある。
-   `db/Schemafile`: Database schema managed via **Ridgepole**.
-   `config/routes.rb`: definition of available endpoints.

## Infrastructure

### Deployment Stack
-   **Deployment Tool**: [Kamal 2](https://kamal-deploy.org/) - zero-downtime Docker deployments
-   **Cloud Provider**: AWS LightSail (recommended: 1GB RAM minimum)
-   **Container Registry**: AWS ECR
-   **Database**: SQLite (file-based, stored in Docker volume)

### Key Files
-   `config/deploy.yml`: Kamal deployment configuration
-   `.kamal/secrets`: Environment variables (gitignored, see `.kamal/secrets.example`)
-   `Dockerfile`: Production multi-stage build
-   `bin/docker-entrypoint`: Runs ridgepole schema migration on container start

### Environment Variables (Required)
Configure these in `.kamal/secrets` or your CI/CD environment:

| Variable | Description |
|----------|-------------|
| `DEPLOY_HOST` | Server IP or hostname |
| `DEPLOY_DOMAIN` | Domain for SSL (e.g., `app.example.com`) |
| `AWS_ACCOUNT_ID` | AWS account ID for ECR |
| `RAILS_MASTER_KEY` | Rails credentials key |
| `SECRET_KEY_BASE` | Rails secret key |
| `KAMAL_REGISTRY_PASSWORD` | ECR auth token (via `aws ecr get-login-password`) |

### Data Persistence
-   **Docker Volume**: `castme_db` persists SQLite database across deployments
-   **Backup**: Optional S3 backup can be configured for disaster recovery
-   **Schema Migration**: Automatically applied via `bin/docker-entrypoint` on each deploy

### Deployment Commands
```bash
# Initial setup
kamal setup

# Deploy updates
kamal deploy

# View logs
kamal app logs

# Run console
kamal app exec -i 'bin/rails console'
```

## Scheduled Notifications (Reminders)

### Overview
定時プッシュ通知は **web コンテナ内の常駐スレッド** が1分ごとに実行します。
GitHub Actions の cron は数時間レベルでずれるため、時間に正確な仕組みとしては使いません。
通知時刻はユーザーごとに **30分刻み**（`:00` / `:30`）で設定できます。

### Architecture
```
web コンテナ（Puma）
  ReminderDispatcher::Runner（1分ごと、production のみ）
      ↓ ReminderDispatcher.tick
  候補枠（[now-5分, now] の30分境界）を列挙
      ↓ NotificationDispatch.claim（slot_key の UNIQUE 制約で二重送信を防ぐ）
  該当ユーザーの設定を DB から取得
      ↓
DailyReviewNotificationService / FamilyCalendarNotificationService /
FamilyTaskStatusNotificationService
      ↓
PushNotificationService → OneSignal API
```

送信の正しさ（重複防止・落ちた claim の回収）は DB 側で担保しているため、
スレッドが多重に走っても、`bin/rails reminders:dispatch` をホスト cron から叩いても同じ挙動になる。

### Key Files
| File | Description |
|------|-------------|
| `app/services/reminder_dispatcher.rb` | 枠の列挙・claim・送信・履歴の掃除 |
| `app/services/reminder_dispatcher/runner.rb` | 1分ごとの常駐スレッド |
| `config/initializers/reminder_dispatcher.rb` | production でのスレッド起動 |
| `app/models/notification_dispatch.rb` | 送信済みの枠（`slot_key` UNIQUE） |
| `app/models/user_notification_setting.rb` | ユーザーごとの通知設定（時・分） |
| `app/services/push_notification_service.rb` | OneSignal API 呼び出し一元化 |
| `lib/tasks/reminders.rake` | 手動実行 `reminders:dispatch` |

### Environment Variables
| Variable | Description |
|----------|-------------|
| `REMINDER_DISPATCHER_ENABLED` | `0` で常駐スレッドだけを止める（手動 tick は動く） |
| `REMINDER_GRACE_MINUTES` | 遅れて送る猶予（既定 5 分。超えた枠は送らない） |
| `ONESIGNAL_APP_ID` | OneSignal アプリID |
| `ONESIGNAL_API_KEY` | OneSignal REST API キー |

### Manual Trigger
```bash
kamal app exec -i 'bin/rails reminders:dispatch'
```

### User Settings
`/settings` ページで各ユーザーが設定可能：
- 家族カレンダリマインダー（有効/時刻）
- タスク進捗リマインダー（有効/時刻）
- 一日のふりかえりリマインダー（有効/時刻、既定 19:00 有効）

### Out of scope (still on GitHub Actions)
- `weekly_notification.yml`（週次サマリー）
- `backup.yml`（DB バックアップ）
