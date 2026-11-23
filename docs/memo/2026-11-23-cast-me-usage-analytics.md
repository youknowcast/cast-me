# cast-me の利用状況分析（調査メモ）

作成日: 2026-11-23
対象: Inkdrop タスク「cast-me アプリの利用状況を分析する（家族ごとのログイン状況、利用状況を可視化する）」
種別: 調査メモ（2026-11-23 に「家族にも公開」で実装済み。実装内容は §4）

## 1. 結論（先に）

- **今の DB だけでは「ログイン回数・最終ログイン」は 1 件も分からない。** Devise は `:trackable` を使っておらず、セッションは Rails のクッキーストアなので、ログインはどこにも記録されていない。
- 一方で **「誰がいつ何を書いたか」は既存の `created_at` / `updated_at` / `created_by_id` / `last_edited_by_id` でかなり分かる**。新しいテーブルを足さずに、家族ごとの「書いた日数」「直近の書き込み」は今日から集計できる。
- ただし `remember_for = 6.months` かつログイン画面で「ログイン状態を保持する」が既定 ON なので、**ログイン回数は実利用の指標にならない**（数週間〜数ヶ月に 1 回しか発生しない）。「ログイン状況」は「最終アクセス（last_seen）＋実際に書いた日数」に読み替えるべき。
- **オーナーの決定により、家族メンバー全員が見られる読み取り専用ページ `/usage` として実装した**（ログイン済みなら誰でも、`current_user.family` の範囲だけ）。計測は `users.last_seen_at` の 1 列のみで、IP・端末情報・ログイン回数・時刻は保存も表示もしない。日次履歴テーブルは作っていない。
- 家族向けに開くにあたり、**表示は「日数」と「相対日付」に丸めた**。個人の最終アクセスは「今日 / 昨日 / n日前 / 30日以上前」だけで、時刻は出さない（§4.4）。

## 2. 現状の調査

### 2.1 認証の仕組み

`app/models/user.rb`:

```ruby
devise :database_authenticatable, :rememberable, :timeoutable
```

- 認証は Devise（`config/initializers/devise.rb`、認証キーは `login_id`）。
- `:trackable` は無効。したがって `sign_in_count` / `current_sign_in_at` / `last_sign_in_at` / `*_ip` は **カラム自体が存在しない**（`db/Schemafile` の `users` は `login_id`, `family_id`, `encrypted_password`, `remember_created_at`, `avatar`, `birth`, timestamps のみ）。
- セッションは Rails 既定の CookieStore（`config/initializers/session_store.rb` は無く、DB セッションテーブルも無い）。**ログインイベントはサーバ側に残らない。**
- `config.timeout_in = 1.month`、`remember_for = 6.months`、`extend_remember_period = true`。ログイン画面（`app/views/devise/sessions/new.html.slim`）では remember_me が `checked: true`。
- 家族・ユーザーの作成 UI は無い（`devise_for :users` の登録画面はあるが `family_id` 必須のため実質使えず、実データは `db/seeds.rb` 相当の手作業投入）。**「家族のオーナー」という概念・カラム・ロールは存在しない。** 家族内は全員対等（週間ダッシュボードも「相互管理」方針で他人のマスを編集できる）。
- `app/controllers/application_controller.rb` から各コントローラの `before_action :authenticate_user!` で認証する。ログイン記録のフックは無かった（実装後は `touch_last_seen` が `last_seen_at` だけを更新する）。

### 2.2 既存データに残っている「誰がいつ」

| テーブル | 誰（行為者） | いつ | 注意点 |
|---|---|---|---|
| `users` | — | `created_at` / `updated_at` | 更新はプロフィール・パスワード変更時のみ。ログインでは更新されない |
| `users.remember_created_at` | 本人 | remember_me を付けてログインした時刻 | `||=` で入るため**最初の 1 回しか更新されない**（`extend_remember_period` はクッキーの期限を延ばすだけで値を変えない）。sign_out すると nil に戻る。訪問回数の指標にはならない |
| `plans` | `created_by_id`, `last_edited_by_id` | `created_at` / `updated_at` | 予定の追加・編集。参加者の増減は別テーブル |
| `plan_participants` | `user_id` | `created_at` / `updated_at` | `status`（pending/joined/declined）の変更時刻が `updated_at` |
| `tasks` | `user_id`（**担当者であって作成者ではない**） | `created_at` / `updated_at`, `completed` | 家族スコープでは担当者を他人にできる（`app/views/tasks/_form.html.slim`）。完了時刻は `updated_at` だが、完了後に編集すると失われる |
| `meals` | `user_id` | `created_at` / `updated_at` | `my` スコープのみ `user_id` が入り、家族スコープの記録は `user_id = nil`（`MealsController#default_meal_attributes`）。**家族一括の食事記録は行為者不明** |
| `regular_task_user_usage_counts` | `user_id` | `usage_count`, `created_at` / `updated_at` | よく使うタスクの利用**回数のみ**。いつ使ったかの履歴は無い（既に「ユーザー別カウンタ」の前例） |
| `task_templates` | `user_id` | `created_at` | 雛形の所有者 |
| `day_memos` / `foods` / `everyday_task_templates` | なし | `created_at` / `updated_at` | 家族単位。最終更新者が区別できない |
| `user_notification_settings` | `user_id` | `updated_at` | 設定変更の最終時刻 |
| `calls`（`CallsController`） | — | — | 保存していない（OneSignal へ送るだけ）。呼び出し履歴は残らない |

補足:

- 個人の食事は `Meal.visible_to_user`（本人 + `user_id IS NULL`）で、家族ビューには出さない設計（プライバシーの前例）。ただし `MonthlyMealSummariesController` は `family.meals` をそのまま月次表示しており、ここは個人記録も含まれる（表示にはユーザー名を出していないので実害は小さいが、集計時は意識する）。
- `plans` は `created_by_id` が nullable（過去データや削除ユーザー）。
- **削除は物理削除**（`dependent: :destroy` のみ、論理削除なし）。したがって「今週書いた件数」は「今残っている件数」であり、消した行動は見えない。

### 2.3 分からないこと（＝追加しないと取れないもの）

1. ログイン回数・最終ログイン（最終アクセスは実装後 `users.last_seen_at` で分かる）
2. ログインしたが何も書かずに閉じた（＝閲覧だけの利用）
3. どの画面をどれくらい見たか（PV）
4. プッシュ通知の開封（OneSignal 側の統計のみ。アプリ内には来ない）
5. 家族一括の食事・メモ・食品を「誰が」記録したか
6. タスクの完了時刻の履歴（完了→編集で上書きされる）
7. 招待・退会などのイベント（該当機能自体が無い）

### 2.4 インフラ・運用の制約

- 本番は **Lightsail 1GB 1 台**、Kamal 2、SQLite（`data/production.sqlite3` を Docker ボリューム `castme_data` に置く）。`config/deploy.yml` に別プロセスの常駐ワーカーや cron は無い（定時リマインダーは #112 以降、Puma 内の常駐スレッド `ReminderDispatcher::Runner` が 1 分ごとに回す。プロセスは増えていない）。
- 定期処理は「**web コンテナ内のスレッド**」で行うのが現在の型（`app/services/reminder_dispatcher/runner.rb`。送信の重複防止は DB の `slot_key` UNIQUE で担保）。GitHub Actions の cron に残っているのは週次サマリーと DB バックアップだけ。今回の集計はリクエスト時に読むだけなので、どちらの型も使っていない。
- ログは `RAILS_LOG_TO_STDOUT=1` でコンテナ標準出力のみ。**ログ用ボリュームは無く、ログは揮発**。過去のログからログイン履歴を復元することはできない。
- スキーマは Ridgepole（`db/Schemafile`）。`bin/docker-entrypoint` がコンテナ起動時に毎回 `ridgepole -a -r config/ridgepole.rb` を実行するため、**Schemafile に追記してデプロイすれば本番にも自動で列追加される**（`entrypoint.sh` の「DB ファイルが無い時だけ」という記述は使われていない）。CI（`.github/workflows/deploy.yml`）もテスト DB に同じ Schemafile を適用している。
- 毎日 JST 0:00 に SQLite を S3 へバックアップする workflow がある（`.github/workflows/backup.yml`）。**オフラインで集計したいならこのコピーを使える。**
- SQLite なので「読むだけの集計」は 1 リクエスト内で普通に回せる規模（家族数・ユーザー数は二桁、行数も数万オーダー）。書き込みはなるべく増やさない（1 台・単一 DB ファイル）。
- タイムゾーンは `config.time_zone = 'Tokyo'`、DB には UTC で保存。「日」単位の集計は JST に直す必要がある（SQLite なら `date(created_at, '+9 hours')`、Ruby 側なら `in_time_zone`）。

### 2.5 プライバシー前提

- 家族内は「相互管理」文化（他人の予定・タスクを編集できる）だが、**ログイン時刻・最終アクセスは予定より踏み込んだ情報**。子どもを含む前提では「見張り」になりやすい。
- 子どもは同意能力や離脱手段が限られる。**監視っぽさを出さない**（時刻そのものより「今週 3 日使った」のような粗い粒度）方が安全。
- IP アドレスは保存自体が不要（Devise `:trackable` は既定で IP を 2 列保存する）。IP は「誰がどこから」という追加の個人情報で、この目的には寄与しない。
- 運営者（オーナー）が見るのか、家族内で見せ合うのかで設計が変わる。**まず「誰に見せるか」を決めるのが先。**

## 3. 選択肢の比較

| | A. 家族向け簡易ダッシュボード（採用） | B. オーナー向け分析ページ | C. 外部ツール / オフライン集計 |
|---|---|---|---|
| 何が見えるか | 自分の家族の「記録日数・件数・メンバーの最終アクセス（相対日付）」 | 家族ごと・メンバーごとの最終アクセス、直近 7/30 日の書き込み数、アクティブ家族数、離脱気味の家族 | OneSignal の配信・開封率、S3 バックアップへの SQL、`kamal app exec` でのアドホック集計 |
| 実装コスト | 小（計測 1 列 + 1 画面。既存カラムの集計が主） | 中（計測 + 管理者ガード + 家族横断の画面） | 極小（スクリプトのみ。ログイン系は取れない） |
| 運用コスト | 小（読み取りのみ） | 小（読み取りのみ。管理者リストを env で持つ） | 小〜中（人手で実行、S3/SSH 権限、毎回の作業） |
| プライバシー | 中（設計で抑えられる）。時刻・回数・IP を出さず、家族スコープに限定すれば「監視」にはならない | 中。運営者のみ。IP を保存しなければ最小限 | 小（画面に出さない）。ただし作業者=運営者に集約される |
| 主なリスク | 数字が家族の人間関係に踏み込む。表示項目を増やしたくなったときが危険 | 管理者ガードの実装ミス（=情報漏えい） | 属人化。意思決定のたびに手作業。ログインは永久に不明 |

- **A を採用する。** ただし「時刻を見せる」「回数を見せる」を足した瞬間に監視になるので、**表示は日数と相対日付に固定**する（§4.4）。実装もその前提で、`last_seen_at` 以外の履歴は持たない。
- **B は今回作らない。** 家族内に「オーナー」ロールが無く、家族横断の数字は家族メンバーには不要。将来 SaaS 的に複数家族を運用するなら、A の集計クラスを流用して B を足せる（`FamilyUsageReport` は family を受け取るだけなので、家族一覧で回せばよい）。
- **C はログインを一切解決しない**ので単独では目的を満たさない。今回の A で「書いた日数」は家族自身が見られるようになったので、運営側の定期レポートが必要になったら S3 バックアップ + SQL で足りる。
- 外部 SaaS（Plausible / GA / Umami 等）は、①常駐/外部依存を増やす ②CSP（`config/initializers/content_security_policy.rb`）の緩和が必要 ③子ども含む全操作を第三者に送る、の 3 点でこの制約下では不適。OneSignal は既に導入済みで、通知の配信・開封はその管理画面で見られる（＝追加コスト 0 で使える唯一の「外部ツール」枠）。

## 4. 実装したもの: 家族向け `/usage`

### 4.1 方針

1. **ログイン済みなら誰でも見られる。** ただし表示対象は常に `current_user.family`。`scope` パラメータ（my/family）を付けても家族ビュー固定。
2. **計測は 1 列だけ足す。** `users.last_seen_at`。IP・端末情報・ログイン回数・ログイン時刻は保存しない。
3. **それ以外は既存の `created_at` / `created_by_id` / `user_id` から集計する。** イベントログ・日次履歴・PV トラッキングは作らない。
4. **画面は 1 枚。** 家族全体のサマリとメンバー表だけ。期間は 7 日 / 30 日の切替。

### 4.2 スキーマ変更（`db/Schemafile`）

```ruby
create_table 'users', force: :cascade do |t|
  # 既存カラム...
  t.datetime 'last_seen_at'
end
```

- 追加テーブルなし・列 1 つだけ。Devise の `:trackable` は `current_sign_in_ip` / `last_sign_in_ip` が付いてくるので使っていない。
- 列は users テーブルの**末尾**に置いた。Ridgepole は既存テーブルへの列追加時に `after:` を付けるが、`:after` 非対応の ActiveRecord で失敗するため、CI の ridgepole 実行にも `-r ./config/ridgepole.rb`（本番の `bin/docker-entrypoint` と同じ設定）が必要。`test.yml` は main（#112）で既に入っていたので、**このブランチで足したのは `deploy.yml` の 1 行だけ**。

### 4.3 計測（最終アクセス）

`ApplicationController` に `before_action :touch_last_seen`（`app/controllers/application_controller.rb`）。

- `user_signed_in?` のときだけ動く。未ログインの訪問は記録しない。
- **毎リクエスト UPDATE しない。** `session[:last_seen_recorded_at]` に epoch 秒を持ち、30 分以上空いたときだけ `current_user.update_column(:last_seen_at, Time.current)`。SQLite の書き込みと WAL を増やさないための throttle。
- `update_column` なので `users.updated_at` は動かない（プロフィール更新時刻を汚さない）。
- セッションはクッキーなので、ブラウザを閉じて開き直すと throttle はリセットされる。その場合も最大 30 分に 1 回の書き込みで済む。

### 4.4 集計（`app/services/family_usage_report.rb`）

- `FamilyUsageReport.new(family:, days:)`。`days` は 7 か 30。
- 範囲は **JST の今日を含む直近 N 日**（`Date.current` 基準）。
- 「記録日数」= 予定・タスク・食事のいずれかを**作成した日**（`created_at`）の重複なし日数。JST に変換してから日付を取る（DB は UTC 保存なので、`created_at.in_time_zone.to_date`）。
- 件数 = 期間内に作られた予定 / タスク / 食事の件数。
- メンバー別の記録日数 = `plans.created_by_id` / `tasks.user_id` / `meals.user_id` ごとの重複なし日数。**家族一括の食事（`user_id = nil`）や、作成者が消えた予定は家族合計には入るがメンバー行には入らない。**
- メンバーの最終アクセスは `last_seen_at` を JST の日付に直し、`今日 / 昨日 / n日前 / 30日以上前 / まだ記録なし（未計測）` の相対表記だけ返す。**時刻は service の返り値にも含めない**（view に渡さないので漏れようがない）。
- クエリは family スコープ + `created_at` の範囲で 3 本（plans / tasks / meals）。行数が小さいので Ruby 側で日付に畳んでいる（SQLite の `date(created_at, '+9 hours')` に依存しない）。

### 4.5 画面（`app/views/usage_reports/show.html.slim`）

- `GET /usage`（`usage_path`、`UsageReportsController#show`）。`?period=7|30`、不正値は 7 日。
- 表示項目:
  - 家族名（「〇〇家の記録のようす」）
  - 期間切替（今週（7日） / 今月（30日））
  - 家族全体: 「直近7日で 3日 記録しました」＋「予定 n件・タスク n件・食事 n件」＋対象期間の日付
  - メンバー表: 表示名 / 記録日数 / 最終アクセス（相対日付）
  - 注記: 「最終アクセスは日付だけの目安です。時刻・回数は記録していません。」
- 導線: 設定ページの「家族の利用状況」と、週間ダッシュボードのヘッダ（グラフアイコン）。どちらも my / family どちらのスコープからでも辿れる。
- スクリーンショット: `docs/memo/images/usage-desktop.png`、`usage-mobile.png`、`usage-desktop-month.png`、`settings-entry-mobile.png`

### 4.6 プライバシー上の割り切り

家族に公開するにあたって、**「見せない」を実装で固定した**。

| 項目 | 扱い | 理由 |
|---|---|---|
| 最終アクセスの時刻 | **出さない**（相対日付のみ） | 何時に開いたかは生活時間の監視になる。日付だけでも「最近使っているか」は分かる |
| アクセス回数・ログイン回数 | **保存も表示もしない** | remember_me 6 ヶ月で意味のある回数にならず、比較して競わせる材料にもなる |
| IP・端末情報 | **保存しない** | 目的に寄与せず、子どもの位置・端末を追う情報になる |
| 日次履歴・PV ログ | **作らない** | 「いつ何日使ったか」の履歴は監視色が強い。必要になったら別途判断 |
| 他家族のデータ | クエリで `family_id` 固定 | 家族をまたぐ比較・ランキングはしない |
| 記録の粒度 | 日数と件数のみ | 個々の記録内容（何を書いたか）は既存画面の領分。ここでは出さない |

- 残る割り切り: **「記録日数」は「アプリを開いた日」ではない。** 開いたが何も書かなかった日は 0 日になる。逆に、家族の誰かが書けば家族全体の日数は増える。この 2 点は画面の注記では説明しきれないので、必要なら後で文言を足す。
- 未計測（`last_seen_at` が nil）は「まだ記録なし」。デプロイ直後は全員この表示になる。

### 4.7 テスト

- `spec/services/family_usage_report_spec.rb`
  - 期間（JST の直近 7 日 / 30 日）、範囲外の除外、他家族の除外
  - 記録日数の重複なしカウント、種類別件数
  - **JST の日付境界**（`2026-11-16 23:30 JST` は範囲外、`2026-11-17 00:30 JST` は範囲内、`23:30` と翌 `00:30` は別日）
  - メンバー行の並び・0 日のメンバー・相対日付ラベル（今日 / 昨日 / n日前 / 30日以上前 / まだ記録なし）
- `spec/requests/usage_reports_spec.rb`
  - 未ログインはリダイレクト、ログイン済みは 200
  - 自家族の名前・メンバーが出る / **他家族の名前・メンバーが出ない**
  - 他家族の記録が件数に混ざらない
  - 期間パラメータ（30 日で古い記録が入る、不正値は 7 日）
  - `scope=my` でも家族ビュー
  - **出力に時刻（`\d{1,2}:\d{2}`）と「ログイン回数」が無い**
- `spec/requests/last_seen_tracking_spec.rb`
  - ログイン中のリクエストで記録、30 分以内は更新しない、31 分後に更新、未ログインは記録しない
- `spec/requests/settings/settings_spec.rb` / `weekly_dashboard_spec.rb` に導線のリンク
- `spec/rails_helper.rb` に `ActiveSupport::Testing::TimeHelpers` を追加（`travel_to` で日付を固定）

### 4.8 変更ファイル一覧

| 種別 | パス |
|---|---|
| スキーマ | `db/Schemafile`（users に `last_seen_at`） |
| 計測 | `app/controllers/application_controller.rb`（`touch_last_seen`） |
| 集計 | `app/services/family_usage_report.rb` |
| 画面 | `app/controllers/usage_reports_controller.rb`、`app/views/usage_reports/show.html.slim` |
| ルート | `config/routes.rb`（`get 'usage'`） |
| 導線 | `app/views/settings/show.html.slim`、`app/views/weekly_dashboard/show.html.slim` |
| CI | `.github/workflows/deploy.yml`（ridgepole に `-r`。`test.yml` は main で追加済み） |
| テスト | `spec/services/family_usage_report_spec.rb`、`spec/requests/usage_reports_spec.rb`、`spec/requests/last_seen_tracking_spec.rb`、`spec/rails_helper.rb`、既存 spec 2 本に追記 |

## 5. 補足: オフライン集計（今回は実装せず）

運営側で家族横断の数字が必要になったら、`kamal app exec` か S3 バックアップの SQLite に対して同じ集計を流せばよい（`bin/usage_report` のようなスクリプト 1 本）。今回の `/usage` は家族スコープ専用なので、運営側の横断ビューは別途必要になったら足す。

## 6. 決めたこと / 見送ったもの

決めたこと（2026-11-23 実装）:

1. **誰が見るか**: 家族メンバー全員（ログイン済みなら誰でも）。表示は自家族のみ。
2. **「ログイン状況」の定義**: ログイン回数ではなく「最終アクセス（相対日付）」＋「記録日数」。remember_me が 6 ヶ月なので回数は使わない。
3. **どこまで記録するか**: `last_seen_at`（最終のみ）。日次履歴は作らない。
4. **IP・端末情報**: 保存しない。
5. **期間**: 直近 7 日 / 30 日の切替（90 日は今のところ不要）。
6. **家族向け公開**: する。粒度は記録日数・件数・相対日付まで。
7. **未計測・記録なしの表示**: 「まだ記録なし」。
8. **文言**: 「直近7日で n日 記録しました」のまま（2026-11-23 決定）。

見送ったもの（必要になったら再検討）:

- **「開いたが書かなかった日」**: 記録日数には出さない（日次履歴テーブルを作らない方針）。
- **運営側の横断ビュー**: 複数家族を運用するなら `/usage` の集計クラスを家族一覧で回すだけ（§3 の B）。

## 7. 参考: 集計に使えるカラム早見表

```
users:        id, login_id, family_id, created_at, updated_at, remember_created_at, birth, last_seen_at
families:     id, name, created_at, updated_at
plans:        family_id, date, created_by_id, last_edited_by_id, created_at, updated_at
plan_participants: plan_id, user_id, status, created_at, updated_at
tasks:        family_id, user_id, date, completed, created_at, updated_at
meals:        family_id, user_id(NULL可), date, meal_type, created_at, updated_at
regular_task_user_usage_counts: user_id, usage_count, created_at, updated_at
day_memos:    family_id, date, created_at, updated_at  (行為者なし)
foods / everyday_task_templates: family_id, created_at, updated_at  (行為者なし)
```

- 「誰が」= `plans.created_by_id` / `tasks.user_id`（担当者） / `meals.user_id`（個人記録のみ） / `plan_participants.user_id`。
- 「いつ」= 各テーブルの `created_at`（作成）/ `updated_at`（最終変更）。**削除は物理削除なので、消した行動は残らない。**
- 日付集計は JST 換算必須（DB は UTC）。
