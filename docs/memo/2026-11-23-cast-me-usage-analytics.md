# cast-me の利用状況分析（調査メモ）

作成日: 2026-11-23
対象: Inkdrop タスク「cast-me アプリの利用状況を分析する（家族ごとのログイン状況、利用状況を可視化する）」
種別: 調査・提案（コード変更なし）

## 1. 結論（先に）

- **今の DB だけでは「ログイン回数・最終ログイン」は 1 件も分からない。** Devise は `:trackable` を使っておらず、セッションは Rails のクッキーストアなので、ログインはどこにも記録されていない。
- 一方で **「誰がいつ何を書いたか」は既存の `created_at` / `updated_at` / `created_by_id` / `last_edited_by_id` でかなり分かる**。新しいテーブルを足さずに、家族ごとの「書いた日数」「直近の書き込み」は今日から集計できる。
- ただし `remember_for = 6.months` かつログイン画面で「ログイン状態を保持する」が既定 ON なので、**ログイン回数は実利用の指標にならない**（数週間〜数ヶ月に 1 回しか発生しない）。「ログイン状況」は「最終アクセス（last_seen）＋実際に書いた日数」に読み替えるべき。
- 推奨は **運営者（オーナー）向けの読み取り専用ページ `/usage` ＋ 最小限の計測（`users.last_seen_at` とログイン時刻/回数、IP は保存しない）**。家族メンバー向けには出さない。Phase 0 として、スキーマ変更なしで既存データだけを集計するスクリプトを先に用意すると、判断材料がすぐ揃う。

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
- `app/controllers/application_controller.rb` に認証前フックは無く、各コントローラの `before_action :authenticate_user!` のみ。

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

1. ログイン回数・最終ログイン・最終アクセス
2. ログインしたが何も書かずに閉じた（＝閲覧だけの利用）
3. どの画面をどれくらい見たか（PV）
4. プッシュ通知の開封（OneSignal 側の統計のみ。アプリ内には来ない）
5. 家族一括の食事・メモ・食品を「誰が」記録したか
6. タスクの完了時刻の履歴（完了→編集で上書きされる）
7. 招待・退会などのイベント（該当機能自体が無い）

### 2.4 インフラ・運用の制約

- 本番は **Lightsail 1GB 1 台**、Kamal 2、SQLite（`data/production.sqlite3` を Docker ボリューム `castme_data` に置く）。`config/deploy.yml` に常駐ワーカー・cron は無い。
- 定時処理は **GitHub Actions の cron → `POST /api/scheduled_notifications/trigger`（トークン認証）** という前例がある。常駐プロセスを足さずに定期処理をしたい場合はこの型を踏襲できる。
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

| | A. 家族向け簡易ダッシュボード | B. オーナー向け分析ページ（推奨） | C. 外部ツール / オフライン集計 |
|---|---|---|---|
| 何が見えるか | 家族メンバー全員の「最終アクセス・今週の記録数」 | 家族ごと・メンバーごとの最終アクセス、直近 7/30 日の書き込み数、アクティブ家族数、離脱気味の家族 | OneSignal の配信・開封率、S3 バックアップへの SQL、`kamal app exec` でのアドホック集計 |
| 実装コスト | 中（計測 + 画面 + 家族内公開の是非の調整） | 小〜中（計測 + 管理ガード + 1 画面。既存カラムの集計が主） | 極小（スクリプトのみ。ログイン系は取れない） |
| 運用コスト | 小（読み取りのみ） | 小（読み取りのみ。管理者リストを env で持つ） | 小〜中（人手で実行、S3/SSH 権限、毎回の作業） |
| プライバシー | **要注意**。子ども同士・親子で互いの行動時間が見える。心理的圧力になりうる | 中。運営者のみ。IP を保存しなければ最小限。将来の家族向け公開とは分離できる | 小（画面に出さない）。ただし作業者=運営者に集約される |
| 主なリスク | 家族の人間関係に踏み込む。あとから撤回しづらい | 管理者ガードの実装ミス（=情報漏えい）。集計クエリの N+1 | 属人化。意思決定のたびに手作業。ログインは永久に不明 |

- **A は「今週の記録数」程度ならまだしも、最終アクセス時刻を見せると家族内の監視になる。** 週間ダッシュボードの延長として作るなら、個人の時刻は出さず「家族全体で今週 n 日記録があった」のような家族単位の粗い数字に留めるべき。
- **C はログインを一切解決しない**ので単独では目的を満たさない。ただし B の前段（Phase 0）として「今すぐ現状を知る」用途に強い。
- 外部 SaaS（Plausible / GA / Umami 等）は、①常駐/外部依存を増やす ②CSP（`config/initializers/content_security_policy.rb`）の緩和が必要 ③子ども含む全操作を第三者に送る、の 3 点でこの制約下では不適。OneSignal は既に導入済みで、通知の配信・開封はその管理画面で見られる（＝追加コスト 0 で使える唯一の「外部ツール」枠）。

## 4. 推奨案: オーナー向け `/usage` ＋ 最小計測

### 4.1 方針

1. **見せる相手は運営者だけ。** 家族メンバー向けの画面は作らない（必要になったら Phase 2 で、粗い家族単位の数字のみ）。
2. **計測は 3 つだけ足す。** `users.last_seen_at`、`users.last_sign_in_at`、`users.sign_in_count`。IP は保存しない。
3. **それ以外は既存の `created_at` / `updated_at` / `created_by_id` / `user_id` から集計する。** イベントログテーブル（PV ログ）は作らない。1 台 SQLite に書き込みを増やす価値が無い。
4. **画面は 1 枚。** 家族一覧 + メンバー行 + 直近数値。絞り込みは「期間（7/30/90 日）」くらい。

### 4.2 スキーマ変更（`db/Schemafile`）

```ruby
create_table 'users', force: :cascade do |t|
  # 既存カラム...
  t.datetime 'last_seen_at'          # 最終アクセス（書き込みは throttle する）
  t.datetime 'last_sign_in_at'       # ログインフォーム/Warden 経由の認証時刻
  t.integer  'sign_in_count', null: false, default: 0
end
```

- 追加テーブルは無し。`users(family_id)` のインデックスが無いので、ついでに `t.index ['family_id']` を足す（SQLite では FK に自動索引が付かない）。データ量が小さいので必須ではないが、家族ごと集計の JOIN で効く。
- Devise `:trackable` を使えば 1 行で済むが、`current_sign_in_ip` / `last_sign_in_ip` が付いてくるので**使わない**（プライバシーとノイズの両面で不要）。列名だけ `trackable` 互換にしておくと将来移行しやすい。

### 4.3 計測の実装

- 最終アクセス: `ApplicationController` に `before_action :touch_last_seen`（`user_signed_in?` のときだけ）。
  - **毎リクエスト UPDATE しない。** セッションに「最後に記録した時刻」を持たせ、30 分以上空いたときだけ `update_column(:last_seen_at, Time.current)`。SQLite の書き込み競合と無駄な WAL を避ける。
  - Turbo Stream / `format.turbo_stream` の細かいリクエストでも同じ扱いで問題ない（throttle があるため）。
- ログイン: Warden フック（`config/initializers/` に 1 ファイル）で `after_authentication` のときに `sign_in_count += 1` と `last_sign_in_at` を `update_columns` で更新。Devise の `update_tracked_fields` 相当を自前で最小実装するイメージ。
  - 注意: remember_me による復元も「認証」としてフックが走る。それは「セッション開始＝アプリを開いた」に近いので、むしろ **visit 回数として有用**。ただし「ログインフォームを通った回数」とは別物になるので、画面のラベルは「ログイン回数」ではなく **「アクセス回数（セッション開始数）」** と表現する。実装時に request spec で挙動を固定する。
  - ログイン画面には既に remember_me 既定 ON があるため、`sign_in_count` は「アプリを開いた回数」の下限値として読む。

### 4.4 画面とルーティング

- `GET /usage` → `UsageReportsController#show`（`resources` ではなく `get 'usage'`）。
- `before_action :require_operator!`: `ENV['CASTME_OPERATOR_LOGIN_IDS']`（カンマ区切りの `login_id`）に含まれない場合は **404**（403 ではなく存在を隠す）。DB にロール列を足さないので、権限昇格の面も増えない。
- サイドバー / ボトムナビには**出さない**（運営者が URL を知っていればよい）。リンクを出すなら設定画面の奥に置く。
- 表示内容（家族ごと）:
  - メンバー数、作成日
  - 家族の最終アクセス（メンバーの `last_seen_at` の最大）
  - 直近 7 / 30 日の「記録日数」（予定・タスク・食事のいずれかを書いた日、JST 基準）
  - 直近 7 / 30 日の書き込み件数（plans / tasks 完了 / meals）
  - メンバー行: 表示名、最終アクセス（日付まで。時刻は出さない）、アクセス回数、直近 30 日の記録日数
- 「離脱気味」の判定は画面にラベルを付けるだけ（例: 30 日記録なし）。自動通知はしない（YAGNI）。

### 4.5 集計クエリ（N+1 を避ける）

家族数は二桁なので、家族ごとにループして 4 クエリずつ、でも実害は無いが、以下のように **1 テーブル 1 クエリ** で `family_id => 値` のハッシュを作る方が素直:

```ruby
since = 30.days.ago
plan_counts  = Plan.where(created_at: since..).group(:family_id).count
task_counts  = Task.where(completed: true, updated_at: since..).group(:family_id).count
meal_counts  = Meal.where(created_at: since..).group(:family_id).count
```

「記録日数」は JST の日付で DISTINCT を取る:

```ruby
# SQLite: UTC 保存なので +9h してから date() に渡す。
# 行数が小さいので pluck + Ruby 側で畳むのが一番読みやすい
jst_date = Arel.sql("date(created_at, '+9 hours')")
Plan.where(created_at: since..)
    .pluck(:family_id, jst_date)
    .uniq
    .group_by(&:first)
    .transform_values(&:size)
```

複数テーブルの「いずれかを書いた日」を正確に出すなら、各テーブルの `(family_id, jst_date)` を UNION して外側で `COUNT(DISTINCT)` する。SQLite でも 1 本で書けるが、可読性を取って Ruby 側で Set を合成してもよい（行数が小さいため）。

### 4.6 テスト

- `spec/requests/usage_reports_spec.rb`
  - 運営者（env 設定済みユーザー）は 200
  - 非運営者は 404（本文に他家族の名前・数値が出ないこと）
  - 未ログインはログイン画面へ
  - 期間パラメータの解釈（不正値は 30 日にフォールバック）
  - 集計値: 2 家族を作り、片方の予定がもう片方の合計に混ざらないこと
  - 出力に IP が含まれないこと（列を持たないので自明だが、回帰防止として件数だけ確認）
- `spec/requests/user_sessions_spec.rb` に追記
  - ログインで `sign_in_count` が 1 増え、`last_sign_in_at` が入る
  - remember_me の復元でもアクセス回数が増える（仕様として固定）
- 最終アクセスの throttle は concern / controller spec で「同一セッションで 2 回叩いても 1 回しか UPDATE しない」ことを確認（`ActiveSupport::Testing::TimeHelpers#travel`）。
- 仕上げに `bundle exec rubocop -A`。

### 4.7 変更ファイル一覧（実装する場合）

| 種別 | パス |
|---|---|
| スキーマ | `db/Schemafile`（users に 3 列 + family_id index） |
| 計測 | 新規 `app/controllers/concerns/last_seen_tracking.rb`、新規 `config/initializers/warden_usage_tracking.rb` |
| 画面 | 新規 `app/controllers/usage_reports_controller.rb`、新規 `app/views/usage_reports/show.html.slim` |
| ルート | `config/routes.rb`（`get 'usage'`） |
| 設定 | 運営者用 env `CASTME_OPERATOR_LOGIN_IDS`（`config/deploy.yml` の `env.clear`） |
| テスト | 新規 `spec/requests/usage_reports_spec.rb`、`spec/requests/user_sessions_spec.rb` 追記 |

見積り: 半日〜1 日。DB 変更は列追加のみで、Ridgepole が起動時に自動適用するため手作業のマイグレーションは不要。ただし本番の `users` は小さいのでロックの心配も無い。

## 5. Phase 0（スキーマ変更なしで、今すぐ現状を知る）

`/usage` を作る前に、**既存データだけで「どの家族が今も書いているか」を出す**のは今日できる。`kamal app exec` で流す一時スクリプト（`bin/usage_report`）を 1 本置くだけ。

出すもの:

- 家族ごとのメンバー数、最終書き込み日（plans / tasks / meals の `max(updated_at)`）
- 直近 7 / 30 日の書き込み件数と記録日数
- メンバーごとの直近 30 日の `created_at` 件数（plans.created_by_id / tasks.user_id / meals.user_id）

これで「ログインは分からないが、実際に使われているかは分かる」状態になる。`last_seen_at` を入れるかどうかの判断材料にもなる。

（バックアップ SQLite をローカルに持ってきて同じ SQL を流す運用でもよい。その場合は個人情報のコピーを手元に置くことになるので、削除タイミングを決めておく。）

## 6. オーナーに決めてほしい点

1. **誰が見るか**: 運営者だけ（推奨）か、家族メンバー同士でも見せるか。前者なら `/usage` + env ガード、後者なら「個人の時刻は出さず家族単位の粗い数字だけ」に制限する。
2. **「ログイン状況」の定義**: ログインフォームを通った回数ではなく「最終アクセス＋アクセス回数（セッション開始数）」でよいか。remember_me が 6 ヶ月なので、前者は実質使えない。
3. **どこまで記録するか**: `last_seen_at`（最終のみ）で足りるか、日次の履歴（`usage_daily` ロールアップ）が要るか。履歴が要るなら 1 日 1 行/ユーザーの追記テーブルを足す（書き込みは throttle 済みなので軽い）。
4. **IP・端末情報を保存するか**: 推奨は「保存しない」。
5. **継続期間**: 直近 30 日固定か、期間切替（7/30/90 日）を出すか。過去データは `created_at` がある限りいつでも遡れる。
6. **家族向け公開（Phase 2）をやるか**: やる場合の粒度（例: 「今週 家族で 5 日記録しました」まで）と、子どもへの説明の仕方。

## 7. 参考: 集計に使えるカラム早見表

```
users:        id, login_id, family_id, created_at, updated_at, remember_created_at, birth
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
