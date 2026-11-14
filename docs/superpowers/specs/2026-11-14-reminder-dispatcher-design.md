# リマインダ送信基盤（分単位スケジューリング）設計

作成日: 2026-11-14

## 背景・目的

現在の定時通知は GitHub Actions の cron（毎時0分）から
`POST /api/scheduled_notifications/trigger` に `hour` を渡して起動している。
GitHub Actions の cron は**数時間レベルのずれが起きるラフな仕組み**で、
時間に正確なスケジューリングの土台には使えない。

最初の用途は「**一日のふりかえりの入力を促すリマインダ**」を
**人ごとに任意の時刻（30分刻み）** で送ること。
そのうえで、将来のリマインダ（予定の N 分前など）を載せられる土台にする。

**採用しない方向**: GitHub Actions cron の精度を上げる / 有料の外部スケジューラを導入する /
サーバを増やす / Redis を立てる。いずれもコスト増または外部依存の移動にしかならない。

## 目標

| 項目 | 目標 |
|---|---|
| 時刻精度 | 設定時刻から **1分以内**に送信開始（数分の遅れは許容） |
| 重複 | 同じ枠を **二度送らない**（デプロイ・再起動・多重起動のいずれでも） |
| 取りこぼし | 落ちていた枠は **5分以内なら遅れて送る**。それ以上は送らない |
| コスト | **ゼロ増**（新規サーバ・有料サービス・Redis なし） |
| 運用 | 設定はすべてリポジトリ内（コード + 環境変数）で完結する |

## 非目標

- 送信済みかどうかで送否を変える判定（「ふりかえり済みなら送らない」は**しない**。決めた時刻に必ず送る）。
- 任意時刻・繰り返しルール（RRULE）を持つ汎用リマインダ CRUD。今回のテーブルは「設定 + 送信履歴」に留める。
- バックアップ cron（`.github/workflows/backup.yml`）の移設。別件として扱う。
- アプリ内（Turbo）でのリマインダ表示。従来どおり OneSignal プッシュのみ。

## 制約

- 本番は AWS LightSail **1台**、**web コンテナ1つ**、SQLite（`data/production.sqlite3`）、常駐プロセスなし、1GB RAM。
- Kamal 2 のゼロダウンタイムデプロイにより、**一瞬だけ旧コンテナと新コンテナが併存**する。
  同じ枠を2プロセスが処理しうる前提で設計する。
- スキーマは Ridgepole（`db/Schemafile`）で管理し、コンテナ起動時に `-a` で自動適用される。
  SQLite のため**カラムリネームは行わず、追加のみ**にする。
- タイムゾーンは `Asia/Tokyo` 固定（`config.time_zone = 'Tokyo'`）。
- プッシュ送信は `PushNotificationService`（OneSignal）に集約済み。

## 全体像

```
[web コンテナ]
  Puma
   └─ ReminderDispatcher スレッド（1分ごと、production のみ）
        ├─ 候補枠を列挙（now-5分 〜 now の 30分境界）
        ├─ 枠に一致する設定を抽出
        ├─ notification_dispatches に slot_key を INSERT（UNIQUE で排他）
        │     └─ 挿入できたプロセスだけが送信する
        └─ 送信: DailyReviewNotificationService / FamilyCalendarNotificationService /
                 FamilyTaskStatusNotificationService
              └─ PushNotificationService → OneSignal

  bin/rails reminders:dispatch   … 同じ tick を手動実行（将来ホスト cron に載せ替え可能）
```

「スレッド」は**時計**であり、正しさ（重複防止・取りこぼし防止）は**DB**が担保する。
そのためスレッドが多重に走っても、ホスト cron に移しても、挙動は変わらない。

## なぜスレッドか

| 案 | 判断 | 理由 |
|---|---|---|
| **web コンテナ内スレッド** | **採用** | 追加プロセス・追加課金なし。1分ごとの起床ならメモリ影響は無視できる |
| ホスト cron（毎分 curl / rake） | 保留 | 無料で正確だが、設定がコード外（ホスト）に出る。rake を公開しておくので後から移せる |
| GitHub Actions 継続 | 却下 | 数時間ずれる（今回の出発点） |
| 外部スケジューラ（cron-job.org 等） | 却下 | 外部依存が残り、無料枠は遅延する。優位性がない |
| Kamal accessory（別コンテナ） | 却下 | 1GB の枠に常駐プロセスを増やす。スレッドと得られるものが同じ |
| Solid Queue / GoodJob | 却下 | 1プロセス・低頻度には過剰。worker プロセスの分だけ RAM を食う |
| Sidekiq | 却下 | Redis が要る（コスト・RAM 増、運用対象が増える） |

スレッドは `Rails.application.executor.wrap` と `connection_pool.with_connection` で囲み、
DB 接続を毎回返却する。`preload_app!` は使っていないので fork 時の二重起動は起きない。
`REMINDER_DISPATCHER_ENABLED=0` でスレッドの起動だけを止められる（切り分け用。手動 tick は止まらない）。

## 送信アルゴリズム

### 枠（slot）

時刻設定は 30分刻み（`:00` / `:30`）。「枠」は `yyyy-mm-dd HH:MM` の 30分境界。

### tick の手順

1. OneSignal の資格情報（`ONESIGNAL_APP_ID` / `ONESIGNAL_API_KEY`）が無ければ、
   警告ログを1回だけ出して終了する（claim も作らない。開発環境で履歴を汚さないため）。
2. `now = Time.zone.now`。候補枠 = `[now - GRACE, now]` に含まれる 30分境界（幅が5分なので**高々1件**）。
3. 候補枠ごとに、その時刻に一致する有効な設定を持つユーザーを抽出する。
   - `daily_review_reminder_*` → 対象ユーザー
   - `family_calendar_reminder_*` → 対象ユーザー
   - `family_task_progress_reminder_*` → 対象ユーザー
4. 対象ごとに「その枠の所有権」を取る（`NotificationDispatch.claim`）。所有権の判定は次の順:
   - 行が無い → INSERT。**UNIQUE 違反なら他プロセスが取った**ので諦める。
   - 行があり `sent_at` あり → 送信済み。諦める。
   - 行があり `sent_at` が NULL で `claimed_at` が STALE より古い → 落ちた claim。
     `UPDATE ... WHERE id = ? AND claimed_at = ?` で奪い直す（`attempts` を +1）。更新行数 0 なら諦める。
   - それ以外（他プロセスが送信中）→ 諦める。
5. 所有権を取れたものだけ通知サービスを呼ぶ。
6. 成功 → `sent_at` を記録、`error` を NULL に。失敗 → `error` にメッセージを残す
   （claim は残すので、STALE 経過後に次の tick が奪い直して再試行する。猶予内なら最大数回）。
7. `SQLite3::BusyException` / `ActiveRecord::StatementInvalid`（ロック競合）は握ってログだけ。
   次の tick が拾う。
8. 30日より古い `notification_dispatches` を削除する（同じ tick 内で軽く）。

`GRACE` は既定 5分（`REMINDER_GRACE_MINUTES` で変更可）。
`STALE` は 2分（OneSignal 呼び出しは通常1秒未満なので、2分残っている claim は落ちたものとみなす）。

**猶予を超えた枠は候補に入らないため、送られず、記録も残らない。**
「送らなかった記録」は作らない（3時間前の「ふりかえりましょう」を送らないための意図的な割り切り）。

### 送信結果の判定

現状の `PushNotificationService.send_to_users` は、API エラーでも資格情報欠落でも `nil` を返すため、
ディスパッチャから成否を区別できない。そこで内部実装を `deliver` に切り出し、
`:sent` / `:skipped` を返し、API エラー時は `PushNotificationService::DeliveryError` を投げる。

既存の `send_to_user` / `send_to_users` は `deliver` を呼んで例外を握り `nil` を返す従来の契約のまま残す
（週次サマリー・予定通知・通話通知の呼び出し元は無変更）。ディスパッチャは `deliver` を使う。

### 時刻の一致判定

SQLite に `time` 型を増やさず、`*_hour`（0..23）と `*_minute`（0 or 30）の整数2列で持つ。
照合は `hour = t.hour AND minute = t.min`。Ridgepole の `-a` 一発適用で済み、既存データも壊れない。

## データ変更

### 新規テーブル `notification_dispatches`

| カラム | 型 | 制約 | 用途 |
|---|---|---|---|
| `id` | bigint | PK | |
| `slot_key` | string | not null, **unique** | `"daily_review:12:2026-11-14 21:30"` |
| `kind` | string | not null | `daily_review` / `family_calendar` / `family_task_progress` |
| `user_id` | bigint | not null, index | |
| `slot_at` | datetime | not null | 枠の時刻 |
| `claimed_at` | datetime | not null | 所有権を取った時刻（STALE 判定に使う） |
| `attempts` | integer | not null, default 0 | 送信試行回数 |
| `sent_at` | datetime | | 送信完了時刻 |
| `error` | string | | 失敗理由 |
| `created_at` / `updated_at` | datetime | not null | |

`slot_key` の UNIQUE インデックスが**排他の一次機構**。`claimed_at` による奪い直しが**二次機構**
（送信中にプロセスが落ちた claim を回収する）。

### `user_notification_settings` 追加カラム

| カラム | 型 | default | 備考 |
|---|---|---|---|
| `family_calendar_reminder_minute` | integer | 0 | |
| `family_task_progress_reminder_minute` | integer | 0 | |
| `daily_review_reminder_enabled` | boolean | **true** | 既存ユーザーの従来挙動（毎日19:00送信）を保つため |
| `daily_review_reminder_hour` | integer | **19** | 同上（現行 `DAILY_REVIEW_HOUR = 19`） |
| `daily_review_reminder_minute` | integer | 0 | |

既存行はカラム追加時の default で埋まる。追加のみのため Ridgepole の適用は安全。

**ただし「行が存在するユーザー」に限る。** 現在 `user_notification_settings` の行は
`SettingsController` を開いたときにだけ遅延生成され、`User` 側にコールバックは無い。
つまり**行を持たないユーザーは、このカラム default の恩恵を受けられない**
（従来は `DailyReviewNotificationService.notify_all` が `User.pluck(:id)` 全員に送っていた）。

これを埋めるため、ディスパッチャは tick の冒頭で欠けている設定行を作る（自己修復）。

```ruby
User.where.missing(:notification_setting).find_each(&:create_notification_setting!)
```

`User` の作成時コールバックや起動時バックフィルは入れない。設定画面を開かずに終わるユーザー、
デプロイ後に作られたユーザー、どちらも同じ経路で救われる。

バリデーション:
- `*_minute` は `{ in: [0, 30] }`
- `*_hour` は `0..23`
- `daily_review_reminder_hour` は enabled のとき必須

インデックス: `(daily_review_reminder_enabled, daily_review_reminder_hour, daily_review_reminder_minute)`。
既存の2つの複合インデックスも分を含む形に置き換える。

## 廃止・変更するもの

| 対象 | 扱い |
|---|---|
| `.github/workflows/scheduled_notifications.yml` | **削除** |
| `Api::ScheduledNotificationsController` と `/api/scheduled_notifications/trigger` | **削除**（呼び出し元が消えるため）。`Api::TokenAuthenticatable` は週次通知で使うので残す |
| `SCHEDULED_NOTIFICATION_API_TOKEN` | **残す**。`Api::TokenAuthenticatable` は週次通知（`/api/weekly_notifications`）でも使い、`weekly_notification.yml` が同じヘッダを送っている。ここで消すと週次が静かに 401 になる。汎用名（`API_TOKEN`）への改名は別件 |
| `DAILY_REVIEW_HOUR` 定数 | 削除（ユーザー設定に移行） |
| `DailyReviewNotificationService.notify_all` | `notify(user)` に置き換え（文面・URL は現状維持） |
| `SettingsController#show` の `HourOption` / `@hour_options` | `TimeOption` / `@time_options`（48件）に置き換え |

`.github/workflows/weekly_notification.yml`（金 21:00 JST）は**今回は触らない**。
同じ理由（GH cron の不安定さ）で移したくなるが、頻度が低く影響が小さいため別件とする。

## 設定 UI

`app/views/settings/show.html.slim` の通知設定ブロック:

- 3つのリマインダ（家族カレンダー / タスク進捗 / ふりかえり）を同じ見た目で並べる。
- 時刻セレクトは `00:00`〜`23:30` の48択。ラベルは `HH:MM`。
- ふりかえりは「🌙 一日のふりかえりを促す」トグル + 時刻セレクト。
- 文言の追加説明: 「設定時刻に毎日プッシュ通知が届きます」。

`SettingsController#notification_setting_params` に新しいキーを追加する。

## 実装ファイル

| ファイル | 変更 |
|---|---|
| `db/Schemafile` | `notification_dispatches` 追加、`user_notification_settings` に5カラム追加 |
| `app/models/user_notification_setting.rb` | バリデーション追加、`minute` を含む |
| `app/models/notification_dispatch.rb` | 新規（UNIQUE 制約の扱い、`claim` / 再獲得） |
| `app/services/reminder_dispatcher.rb` | 新規（tick / 候補枠 / claim / 送信 / 掃除） |
| `app/services/push_notification_service.rb` | `deliver` 切り出し（`:sent` / `:skipped` / `DeliveryError`）。既存メソッドの契約は不変 |
| `config/initializers/reminder_dispatcher.rb` | 新規（production のみスレッド起動、`REMINDER_DISPATCHER_ENABLED`） |
| `lib/tasks/reminders.rake` | 新規 `reminders:dispatch`（手動実行・将来の cron 用） |
| `app/services/daily_review_notification_service.rb` | `notify(user)` 化 |
| `app/controllers/settings_controller.rb` | 時刻オプション48件、strong params 追加 |
| `app/views/settings/show.html.slim` | ふりかえり設定の追加、時刻セレクト変更 |
| `app/controllers/api/scheduled_notifications_controller.rb` | 削除 |
| `config/routes.rb` | 該当ルート削除 |
| `.github/workflows/scheduled_notifications.yml` | 削除 |
| `.github/workflows/test.yml` | ridgepole に `-r ./config/ridgepole.rb` を渡す（このリポジトリの SQLite パッチ） |
| `config/deploy.yml` | `RAILS_MAX_THREADS: 6`、`REMINDER_DISPATCHER_ENABLED` を追加（トークンは残す） |

## テスト（RSpec）

`spec/services/reminder_dispatcher_spec.rb`:

1. 枠時刻ちょうどの設定に対して送信される
2. 枠時刻でない設定には送信されない
3. 同じ tick を2回実行しても送信は1回（UNIQUE による排他）
4. 5分遅れの tick でも猶予内なら送信される
5. 6分遅れの tick では送信されず、**記録も残らない**
6. 送信が `DeliveryError` を投げても tick 全体は止まらず、`error` が記録される
7. `claimed_at` が STALE より古い claim は奪い直して再送する（`attempts` が増える）
8. OneSignal の資格情報が無いときは送信も claim もしない
9. カレンダー／タスク進捗のリマインダもそれぞれの列の時刻で送られる
10. 30日より古い送信履歴が掃除される

`ReminderDispatcher` は `tick(now:)` で時刻を注入できるので、`travel_to` は使わない。
通知サービスと `PushNotificationService.configured?` をスタブする。
`ReminderDispatcher::Runner` は `enabled?` の3条件と、スレッドが1本しか立たないこと、
tick の例外を握りつぶしてログに落とすことを単体で確認する（フラグは**スレッド起動のみ**を制御し、tick は見ない）。
`NotificationDispatch` は claim の排他・再獲得・`attempts` を直接確認する。
`spec/models/accounts/user_notification_setting_spec.rb`: `minute` の `0/30` 制約、既定値、enabled 時の hour 必須。
`spec/requests/settings/settings_spec.rb`: 30分刻みとふりかえり設定の保存、`minute: 15` の拒否。

## リリース手順

1. デプロイ（起動時の Ridgepole `-a` で追加カラム/テーブルが適用される）。
   設定行を持たないユーザーは最初の tick で既定値の行が作られる。
2. ログ（`ReminderDispatcher: sent ...`）で次回の 30分境界に送信されることを確認。
3. 同一枠で2件出ていないこと、`notification_dispatches` の該当 `slot_key` が1行だけであることを確認。
4. 旧 GH Actions ワークフローは同一 PR で削除済み。Actions 画面から手動実行できないことを確認。
5. 問題があれば `REMINDER_DISPATCHER_ENABLED=0` で**スレッドだけ**止め、
   `bin/rails reminders:dispatch` を手動/ホスト cron から叩く運用に切り替えられる（tick 自体は止まらない）。

`RAILS_MAX_THREADS` を 6 にする（Puma 5 スレッド + ディスパッチャ1）。
プール枯渇による `ConnectionTimeoutError` で tick を落とさないため。RAM 増は 1 スレッド分で無視できる。

SQLite のジャーナルモード（WAL）は**変更しない**。書き込みは毎分数行で既定モードでも十分であり、
`backup.yml` は `docker cp` で DB ファイルを素朴にコピーしているため、WAL にすると
未チェックポイント分がバックアップに載らない罠を作ってしまう。ロック競合は rescue して次の tick に委ねる。

## 判断したこと（レビュー時に見てほしい点）

- **猶予5分で打ち切る**: 「必ず送る」は「その日に済んでいなくても送る」の意味と解釈し、
  遅延については 5分で諦める。長時間落ちていた場合に古いリマインダを送らないため。
  猶予外の枠は記録も残さない（「送らなかった」履歴は運用上の価値が無い）。
- **`daily_review_reminder_enabled` の default を true、時刻 19:00**: 既存ユーザーが
  現在受け取っている毎日19:00の通知を黙って止めないため。新規ユーザーも既定で受け取る。
- **全ユーザーに設定行を保証する**: 行は遅延生成される作りだったため、default 頼みでは
  行の無いユーザーが静かに脱落する。ディスパッチャの tick 冒頭で欠けている行を作る（自己修復）。
  `User` の callback を足すと既存スペックの「設定行が0件から1件になる」前提が崩れるため採らない。
- **`*_hour` + `*_minute` の2列**: `time` 型 1列のほうが綺麗だが、
  Ridgepole + SQLite でカラム移行（リネーム）を伴うため、追加のみで済む形を選んだ。
- **スレッド起動場所が initializer**: Puma プラグインでも同等。initializer のほうが差分が小さい。
  `REMINDER_DISPATCHER_ENABLED` は**スレッド起動のみ**を制御する（非常口の手動 tick を殺さないため）。
- **claim の二次機構（`claimed_at` / `attempts`）**: UNIQUE だけだと、送信中にプロセスが落ちた枠が
  永久に送られなくなる。STALE 2分で奪い直すことで、二重送信の危険をほぼゼロに保ちながら回収できる。
- **`PushNotificationService` に `deliver` を足す**: 既存の `send_to_*` は例外を握って `nil` を返す契約で、
  週次・予定・通話の呼び出し元が依存している。契約は変えず、ディスパッチャ専用の入口を追加する。
- **`SCHEDULED_NOTIFICATION_API_TOKEN` は残す**: 週次通知が同じ仕組みで認証している。
  名前が実態と合わないが、改名はワークフローと secret の同時変更が要るので別件。
- **旧エンドポイントの即時削除**: 呼び出し元が GH Actions だけなので、残す理由がない。
  ただしデプロイ直後に旧コンテナが数秒生きる可能性があるため、
  削除は「通知の停止」ではなく「404 を返すだけ」であり、実害はない。
