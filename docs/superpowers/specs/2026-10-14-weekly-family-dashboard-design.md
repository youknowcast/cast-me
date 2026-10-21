# 一週間の家族ダッシュボード 設計

作成日: 2026-10-14

## 目的

紙運用している「一週間の家族予定表」を CastMe 上で置き換える。家族メンバー（行）× 曜日（列）のグリッドで、各人の予定を一望し、その場で追加・編集できるようにする。

元になった紙（写真）の構成:

- 列 = 月〜日の7日間（週は月曜始まり）
- 行 = 家族メンバー（`は` `中` `か` `父` `母` のような表示名）
- 各マス = その人のその日の予定（`テニス 8:00`、`バイオリン 16:30` など）。〇数字は学校の時限・連絡事項の走り書きで、ダッシュボードの主役ではない。

## スコープ

- 家族スコープ専用（"my"（個人）版は作らない）。
- マスに表示するのは **予定（Plan）** と **日ごとの家族メモ** のみ。タスクは表示しない。
- 繰り返し予定は扱わない（毎週手入力）。
- 読み書き可能。編集権限は家族全員が全員のマスを編集できる（既存の家族ビューと同じ「相互管理」方針）。

## 決定事項（ブレインストーミングの結論）

| 論点 | 決定 |
|---|---|
| レイアウト | 案A: 紙そのままのグリッド。行=メンバー、列=曜日 |
| スマホ表示 | 横スクロールで日を送る。メンバー列は sticky |
| 編集の動線 | マスをタップ → PC は右サイドパネル、スマホはボトムシート（既存 `#side-panel` を再利用） |
| マスの内容 | 予定（Plan）＋ 日ごとの家族メモ |
| メモの単位 | 1日につき家族共通で1つ |
| 繰り返し | なし（毎週手入力） |
| 複数人の予定 | 既存 `PlanParticipant` を使い複数メンバーで共有（家族行事は全員の行に出る） |
| 編集権限 | 家族全員が全員のマスを編集可 |
| 週の開始 | 月曜 |

## 1. 画面・ルーティング

- `GET /weekly` → `WeeklyDashboardController#show`
  - `?week=YYYY-MM-DD`（その週の月曜日）で週を移動。省略時は今週。
  - 不正な日付は今週にフォールバック.
- ナビゲーション（`shared/_sidebar` と `shared/_bottom_nav`）に「ウィークリー」を追加（アイコン `fa-calendar-week`）。
- ヘッダ: 前週 / 今週 / 次週ボタンと期間表示（例 `2026/10/12〜10/18`）。

## 2. レイアウト

- グリッド: 行 = `current_user.family.users`、列 = 月〜日の7日。
- 1行目は曜日ヘッダ（今日の列を強調）。
- 各セル: そのメンバーが参加する予定を開始時刻順に表示。時刻があれば `タイトル 16:30` のように併記。
- メンバー列は sticky、グリッド本体は横スクロール（スマホ）。
- グリッド最下行に「メモ」行。日ごとに家族共通メモを1件表示。タップで編集。
- 祝日は `HolidayService` を使い日付ヘッダに印を付ける（既存カレンダーと同じ）。

## 3. データモデル

### 予定（既存をそのまま利用）

- `Plan`（`family_id`, `date`, `title`, `start_time`, `end_time`）＋ `PlanParticipant`（`user_id`, `status`）。
- セルに表示する条件: その Plan に該当メンバーが participant として存在し、`status` が `joined` または `pending`（`declined` は除外）。
- クエリ: 週内の Plan を `plan_participants` ごと eager load し、`user_id × date` のハッシュにまとめてビューへ渡す。

### メモ（新規 `DayMemo`）

| カラム | 型 | 制約 |
|---|---|---|
| `family_id` | bigint | not null |
| `date` | date | not null |
| `body` | text | |

- unique index `[family_id, date]`（1日1件）。
- `belongs_to :family`
- `Family has_many :day_memos, dependent: :destroy`
- バリデーション: `date` presence、`body` は max 1000。
- Ridgepole（`db/Schemafile`）で追加。

## 4. 動線（編集）

- マスをタップ → `#side-panel` に詳細を描画。
  - デスクトップ: 右からスライドするサイドパネル（既存 `side_panel_controller`）。
  - スマホ: 既存の modal-bottom 系に合わせたボトムシート。
- パネル内容（その人・その日）:
  - 当日の予定リスト。各予定をタップすると既存の `/plans/:id/edit` フォームを開く。
  - 「＋予定を追加」→ 既存 `/plans/new` を開き `date` とその人を participant にプリセット。
    - `PlansController#new` に `participant_ids` の受け取りを小追加する。
- メモ行をタップ → `DayMemo` を upsert する簡易フォーム。
- 追加・編集・削除後は Turbo Stream で**当該セルとメモ行のみ**を replace する（既存 `plans_controller#update` の `turbo_stream.replace("calendar-cell-...")` と同じ流儀）。

## 5. コントローラ・ビュー構成

- `WeeklyDashboardController#show` … 週データを組み立てて描画。
- セル詳細パネルは Turbo Frame ではなく既存のサイドパネル方式に合わせる。セルのタップで `GET /weekly/cell?user_id=..&date=..`（`text/vnd.turbo-stream.html` を要求）を fetch し、`turbo_stream.update('side-panel', ...)` でパネルを描画する（既存 `side_panel_opener_controller.ts` と同じ流儀）。
- ビュー:
  - `app/views/weekly_dashboard/show.html.slim`
  - `app/views/weekly_dashboard/_grid_cell.html.slim`
  - `app/views/weekly_dashboard/_cell_panel.html.slim`
  - `app/views/weekly_dashboard/_memo_form.html.slim`
- 既存の `CalendarData` concern は日単位なので流用せず、週単位の組み立てをコントローラ内（または専用 concern）に置く。

## 6. テスト

- `DayMemo` model spec（validation / uniqueness）。
- `/weekly` request spec:
  - 未認証はリダイレクト。
  - 週パラメータのパースとフォールバック。
  - メンバー×日へのグルーピング（declined 参加者は出ない、複数参加者は複数行に出る）。
- セル／メモ更新の controller spec（Turbo Stream でセル・メモ行が replace される）。
- 仕上げに `rubocop -A`。

## 非ゴール（YAGNI）

- 繰り返し予定。
- 個人（my）スコープ版。
- タスク・食事のグリッド表示。
- 印刷レイアウト。
- ドラッグ&ドロップでの移動。
