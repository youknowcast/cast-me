# リマインダ送信基盤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitHub Actions の毎時 cron をやめ、分単位で正確に動くリマインダ送信基盤（最初の利用者が「一日のふりかえり」）をアプリ内に持つ。

**Architecture:** web コンテナ内の常駐スレッドが1分ごとに `ReminderDispatcher.tick` を呼ぶ。正しさ（重複防止・取りこぼし回収）は `notification_dispatches` の UNIQUE 制約と `claimed_at` による再獲得で担保し、スレッドは単なる時計として扱う。

**Tech Stack:** Rails 8.1 / SQLite / Ridgepole / OneSignal / RSpec / Slim / daisyUI

**Spec:** `docs/superpowers/specs/2026-11-14-reminder-dispatcher-design.md`

## Global Constraints

- タイムゾーンは `Asia/Tokyo` 固定。時刻は `*_hour`（0..23）+ `*_minute`（0 か 30）の整数2列で持つ。
- `GRACE = 5分`（`REMINDER_GRACE_MINUTES`）、`STALE = 2分`。
- 設定は 30分刻み。`:00` / `:30` 以外を受け付けない。
- スキーマは `db/Schemafile` を直接編集する（マイグレーションファイルは作らない）。
- 追加のみのスキーマ変更。カラムのリネーム・削除はしない。
- 既存の `PushNotificationService.send_to_user` / `send_to_users` の戻り値契約（例外を握って `nil`）は変えない。
- `SCHEDULED_NOTIFICATION_API_TOKEN` は削除しない（週次通知が使っている）。
- 変更後は必ず `bundle exec rubocop -A` と `bundle exec rspec` を通す。

## Review Focus

- 送信中の強制終了で claim が残る → STALE 2分後に奪い直して送る（二重送信しない）
- デプロイで2コンテナが併存 → UNIQUE 制約で1回だけ送る
- サーバが5分以上落ちていた → 古い枠を送らない（記録も残さない）
- OneSignal の資格情報が無い環境 → 送信も claim もしない
- 設定行を持たないユーザー → 既定（有効・19:00）で通知が届く

---

### Task 1: スキーマとモデル

**Files:**
- Modify: `db/Schemafile`
- Create: `app/models/notification_dispatch.rb`
- Modify: `app/models/user_notification_setting.rb`
- Create: `spec/factories/notification_dispatches.rb`
- Modify: `spec/factories/user_notification_settings.rb`
- Test: `spec/models/notifications/notification_dispatch_spec.rb`
- Test: `spec/models/accounts/user_notification_setting_spec.rb`

**Interfaces:**
- Produces:
  - `NotificationDispatch.claim(kind:, user_id:, slot_at:) -> NotificationDispatch | nil`（所有権を取れたときだけレコードを返す）
  - `NotificationDispatch#mark_sent!(at = Time.current)`, `#mark_failed!(message)`
  - `NotificationDispatch::STALE_AFTER`（`2.minutes`）
  - `NotificationDispatch.build_key(kind, user_id, slot_at) -> String`
  - `UserNotificationSetting#reminder_time(prefix) -> [hour, minute]`（不要なら作らない）

- [ ] **Step 1: 失敗するテストを書く**

```ruby
# spec/models/notifications/notification_dispatch_spec.rb
RSpec.describe NotificationDispatch, type: :model do
  let(:slot) { Time.zone.local(2026, 11, 14, 21, 30) }

  it '同じ slot_key の2回目の claim は失敗する' do
    expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_present
    expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_nil
  end

  it '送信済みの枠は再獲得できない' do
    record = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
    record.mark_sent!
    expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_nil
  end

  it 'STALE より古い claim は奪い直し attempts が増える' do
    record = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
    record.update!(claimed_at: 3.minutes.ago)
    reclaimed = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
    expect(reclaimed).to be_present
    expect(reclaimed.attempts).to eq(1)
  end

  it 'STALE 以内の claim は奪えない' do
    described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
    expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_nil
  end
end
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `bundle exec rspec spec/models/notifications/notification_dispatch_spec.rb`
Expected: `uninitialized constant NotificationDispatch`

- [ ] **Step 3: `db/Schemafile` を編集**

`user_notification_settings` に5カラム追加（`family_calendar_reminder_minute` / `family_task_progress_reminder_minute` / `daily_review_reminder_enabled` default true / `daily_review_reminder_hour` default 19 / `daily_review_reminder_minute` default 0）、
`notification_dispatches` テーブルを追加（`slot_key` unique、`kind`、`user_id`、`slot_at`、`claimed_at`、`attempts` default 0、`sent_at`、`error`）。
インデックスは `slot_key` unique と `user_id`。

- [ ] **Step 4: `app/models/notification_dispatch.rb` を実装**

上の Interfaces のシグネチャで実装する。`claim` は INSERT → `ActiveRecord::RecordNotUnique` を rescue して既存行を確認 →
`sent_at` あり / STALE 以内なら `nil`、古ければ `where(id:, claimed_at:).update_all(...)` が 1 件のときだけ奪い直す。
`slot_key` は `"#{kind}:#{user_id}:#{slot_at.utc.strftime('%Y%m%d%H%M')}"`。

- [ ] **Step 5: バリデーションとファクトリ**

`UserNotificationSetting` に `*_minute` の `inclusion: { in: [0, 30] }`、`daily_review_reminder_hour` の `presence: { if: :daily_review_reminder_enabled? }` を追加。
ファクトリに `daily_review_reminder_enabled` / `_hour` / `_minute` と trait `:with_daily_review_reminder`（21:30）を追加。

- [ ] **Step 6: テストを通す**

Run: `bundle exec ridgepole -c config/database.yml -E test --apply -f db/Schemafile && bundle exec rspec spec/models`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add db/Schemafile app/models spec/models spec/factories
git commit -m "feat: add notification dispatches schema and models"
```

---

### Task 2: `PushNotificationService.deliver`

**Files:**
- Modify: `app/services/push_notification_service.rb`
- Test: `spec/services/notifications/push_notification_service_spec.rb`

**Interfaces:**
- Produces: `PushNotificationService.deliver(user_ids:, title:, message:, url: nil) -> :sent | :skipped`、失敗時 `PushNotificationService::DeliveryError`
- Produces: `PushNotificationService.configured? -> Boolean`

- [ ] **Step 1: 失敗するテストを追加**

```ruby
describe '.deliver' do
  it '資格情報が無ければ :skipped を返し API を呼ばない'
  it 'API エラーのとき DeliveryError を投げる'
  it '成功したら :sent を返す'
end
```

- [ ] **Step 2: 失敗を確認** — Run: `bundle exec rspec spec/services/notifications/push_notification_service_spec.rb`

- [ ] **Step 3: 実装** — 現在の本文を `deliver` に移し、`OneSignal::ApiError` を `DeliveryError` に変換する。
  `send_to_user` / `send_to_users` は `deliver` を呼び、`DeliveryError` と `StandardError` を rescue して `nil` を返す（従来の挙動）。

- [ ] **Step 4: テストを通す**

- [ ] **Step 5: Commit**

---

### Task 3: `ReminderDispatcher`

**Files:**
- Create: `app/services/reminder_dispatcher.rb`
- Create: `lib/tasks/reminders.rake`
- Test: `spec/services/reminders/reminder_dispatcher_spec.rb`

**Interfaces:**
- Consumes: `NotificationDispatch.claim`、`PushNotificationService.deliver`、`DailyReviewNotificationService.notify(user)`、
  `FamilyCalendarNotificationService.notify(user)`、`FamilyTaskStatusNotificationService.notify(user)`
- Produces: `ReminderDispatcher.tick(now: Time.current) -> { sent:, failed:, skipped: }`
- Produces: `ReminderDispatcher::GRACE`、`ReminderDispatcher.candidate_slots(now)`、`ReminderDispatcher.background_enabled?`

- [ ] **Step 1: 失敗するテストを書く**

Review Focus の5項目を全部テストにする。

```ruby
RSpec.describe ReminderDispatcher, type: :service do
  let(:slot) { Time.zone.local(2026, 11, 14, 21, 30) }

  before { allow(PushNotificationService).to receive(:configured?).and_return(true) }

  it '枠時刻ちょうどの設定に送信する'
  it '枠時刻でない設定には送信しない'
  it '同じ tick を2回実行しても送信は1回'
  it '5分遅れの tick でも猶予内なら送信する'
  it '6分遅れの tick では送信せず、記録も残さない'
  it '送信が失敗しても tick は止まらず error が残る'
  it '設定行を持たないユーザーには既定値で送る'
  it '資格情報が無いときは送信も claim もしない'
end
```

- [ ] **Step 2: 失敗を確認**

- [ ] **Step 3: 実装**

`tick` の手順は spec の「tick の手順」1〜8 のとおり。候補枠は `[now - GRACE, now]` の 30分境界。
3種類のリマインダは `{ kind:, enabled:, hour:, minute:, service: }` の配列で持つ。
冒頭で `User.where.missing(:notification_setting).find_each { |u| u.create_notification_setting }` を実行（自己修復）。
`SQLite3::BusyException` / `ActiveRecord::StatementInvalid` は rescue してログのみ。
30日より古い `notification_dispatches` を削除。

- [ ] **Step 4: rake タスク**

`lib/tasks/reminders.rake` に `reminders:dispatch` を追加し、`puts ReminderDispatcher.tick.inspect` する。

- [ ] **Step 5: テストを通す**

Run: `bundle exec rspec spec/services/reminders/reminder_dispatcher_spec.rb`

- [ ] **Step 6: Commit**

---

### Task 4: 常駐スレッドとデプロイ設定

**Files:**
- Create: `app/services/reminder_dispatcher/runner.rb`
- Create: `config/initializers/reminder_dispatcher.rb`
- Modify: `config/deploy.yml`
- Test: `spec/services/reminders/reminder_dispatcher_runner_spec.rb`

**Interfaces:**
- Produces: `ReminderDispatcher::Runner.start(interval: 60)`、`ReminderDispatcher::Runner.enabled?`
- Consumes: `ReminderDispatcher.tick`

- [ ] **Step 1: 失敗するテストを書く**

`Runner.enabled?` が `REMINDER_DISPATCHER_ENABLED=0` で false、未設定で true（production のとき）になることを確認する。
`Runner.start` を2回呼んでもスレッドが1本であること（`Thread.list` の増分で確認）。

- [ ] **Step 2: 失敗を確認**

- [ ] **Step 3: 実装**

`Runner.start` は `Rails.application.executor.wrap` と `ActiveRecord::Base.connection_pool.with_connection` で
`ReminderDispatcher.tick` を呼び、例外は `Rails.logger.error` に落として `sleep interval` を繰り返す。
initializer は `Runner.enabled?` のときだけ `start` する（`Rails.application.config.after_initialize`）。

- [ ] **Step 4: `config/deploy.yml` に `RAILS_MAX_THREADS: 6` と `REMINDER_DISPATCHER_ENABLED: "1"` を追加**

- [ ] **Step 5: テストを通す**

- [ ] **Step 6: Commit**

---

### Task 5: ふりかえり通知の個人化と設定UI

**Files:**
- Modify: `app/services/daily_review_notification_service.rb`
- Modify: `app/controllers/settings_controller.rb`
- Modify: `app/views/settings/show.html.slim`
- Test: `spec/services/notifications/daily_review_notification_service_spec.rb`
- Test: `spec/requests/settings/settings_spec.rb`

**Interfaces:**
- Produces: `DailyReviewNotificationService.notify(user)`（`notify_all` は削除）
- Produces: `SettingsController#minute_options`（`[0, 30]`）

- [ ] **Step 1: 失敗するテストに書き換える**

`notify(user)` が1ユーザーに送ること。設定更新で `family_calendar_reminder_minute` / `daily_review_reminder_*` が保存されること。
`minute: 15` はバリデーションエラーになること。

- [ ] **Step 2: 失敗を確認**

- [ ] **Step 3: 実装**

`notify(user)` は既存の文面・URL のまま `PushNotificationService.send_to_user` を呼ぶ。
設定ビューは「時」「分」の2セレクト（`mobile_collection_select`）にし、ふりかえりのトグルを1つ追加する。
strong params に5キー追加。

- [ ] **Step 4: テストを通す**

- [ ] **Step 5: Commit**

---

### Task 6: 旧 cron とエンドポイントの撤去

**Files:**
- Delete: `.github/workflows/scheduled_notifications.yml`
- Delete: `app/controllers/api/scheduled_notifications_controller.rb`
- Delete: `spec/requests/notifications/api/scheduled_notifications_spec.rb`
- Modify: `config/routes.rb`
- Modify: `AGENTS.md`（cron の説明を新しい仕組みに更新）

- [ ] **Step 1: 削除とルート削除**

- [ ] **Step 2: 参照が残っていないことを確認**

Run: `grep -rn "scheduled_notifications" app config spec .github`
Expected: 出力なし（`.kamal/secrets.example` のトークンは残す）

- [ ] **Step 3: テストを通す** — Run: `bundle exec rspec`

- [ ] **Step 4: Commit**

---

### Task 7: 仕上げと PR

- [ ] **Step 1: `bundle exec rubocop -A`** → offenses 0 を確認
- [ ] **Step 2: `bundle exec rspec`** → 全件 PASS
- [ ] **Step 3: `docs/superpowers/specs/2026-11-14-reminder-dispatcher-design.md` を最終状態に合わせる**
- [ ] **Step 4: PR 作成**

```bash
git push -u origin feat/reminder-dispatcher
gh pr create --title "feat: 分単位で動くリマインダ送信基盤" --body "..."
```
