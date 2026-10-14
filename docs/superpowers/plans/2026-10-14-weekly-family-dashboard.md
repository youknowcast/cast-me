# 一週間の家族ダッシュボード 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 紙の週間予定表を置き換える、家族メンバー（行）× 月〜日（列）のグリッド画面を追加し、その場で予定と日ごとの家族メモを編集できるようにする。

**Architecture:** 既存の `Plan` / `PlanParticipant` をそのまま使い、新規テーブルは日ごとの家族メモ `DayMemo` のみ。読み書きは新しい `WeeklyDashboardController` と、既存の `#side-panel` ＋ Turbo Stream パターンで行う。

**Tech Stack:** Rails 8.1 / Slim / Tailwind v4 + daisyUI 5 / Hotwire（Turbo + Stimulus, TypeScript）/ RSpec + FactoryBot + Shoulda / Ridgepole / SQLite。

**Spec:** `docs/superpowers/specs/2026-10-14-weekly-family-dashboard-design.md`

## Global Constraints

- コマンドはすべて開発コンテナ内で実行する。ワンショット実行（サーバー起動不要）を基本とする。
  - テスト: `docker compose run --rm --no-deps app bundle exec rspec <path>`
  - Lint: `docker compose run --rm --no-deps app bundle exec rubocop -A <path>`
  - スキーマ適用（Ridgepole）:
    - dev: `docker compose run --rm --no-deps app bundle exec rake ridgepole:apply`
    - test: `docker compose run --rm --no-deps -e RAILS_ENV=test app bundle exec rake ridgepole:apply`
      （compose が `RAILS_ENV=development` を設定するため、rake タスクの test 適用は環境変数の上書きが必要）
- ビューは必ず Slim（`.slim`）。ERB は作らない。
- コードコメントは書かない。意図は命名と構造で示す。
- 各タスクの最後に必ず対象ファイルへ `rubocop -A` を掛け、新しい offense が出ていないことを確認する。
- 週の開始は月曜（`Date#beginning_of_week` の既定）。
- 行 = `current_user.family.users`、列 = 月〜日の7日。
- 予定をセルに出す条件は既存 `CalendarData` と同じく `plan_participants.status IN (joined, pending)`（`declined` は除外）。
- 編集権限は家族全員が全員のマスを編集できる（`current_user.family` でスコープ）。
- トップレベル定数・メソッド名は計画内で統一する（例: `WeeklyDashboardController`, `DayMemo`, `weekly_scope?`, `weekly_dashboard_path`, `weekly_cell_path`, `weekly_memo_path`）。

---

### Task 1: `DayMemo` モデルとスキーマ

日ごとの家族共通メモ（1日1件）を保存するモデルを追加する。

**Files:**
- Modify: `db/Schemafile`（`meal_foods` テーブル定義の後ろに追加）
- Create: `app/models/day_memo.rb`
- Modify: `app/models/family.rb`（関連を追加）
- Create: `spec/factories/day_memos.rb`
- Create: `spec/models/calendar/day_memo_spec.rb`

**Interfaces:**
- Produces: `DayMemo`（`belongs_to :family`、属性 `date: Date`, `body: String|nil`）、`Family#day_memos`。
- バリデーション: `date` presence かつ `[family_id, date]` で unique、`body` は最大1000文字。

- [ ] **Step 1: Schemafile にテーブルを追加する**

`db/Schemafile` の `create_table 'meal_foods'` ブロックの直後に追記する。

```ruby
create_table 'day_memos', force: :cascade do |t|
  t.bigint 'family_id', null: false
  t.date 'date', null: false
  t.text 'body'
  t.timestamps

  t.index %w[family_id date], name: 'index_day_memos_on_family_id_and_date', unique: true
end
```

- [ ] **Step 2: スキーマを dev/test に適用する**

Run: `docker compose run --rm --no-deps app bundle exec rake ridgepole:apply`
Expected: `Apply `...` ... Done` が出力され、`day_memos` が作成される（テストDBにも適用される）。

- [ ] **Step 3: 失敗するモデルスペックを書く**

`spec/models/calendar/day_memo_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe DayMemo, type: :model do
  let(:family) { create(:family) }

  describe 'associations' do
    it { is_expected.to belong_to(:family) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_length_of(:body).is_at_most(1000) }
  end

  describe 'date uniqueness within a family' do
    it 'rejects a duplicate date in the same family' do
      create(:day_memo, family: family, date: Date.current)
      duplicate = build(:day_memo, family: family, date: Date.current)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date]).to be_present
    end

    it 'allows the same date in another family' do
      create(:day_memo, family: family, date: Date.current)
      other = build(:day_memo, family: create(:family), date: Date.current)
      expect(other).to be_valid
    end
  end
end
```

- [ ] **Step 4: テストを実行して失敗を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/models/calendar/day_memo_spec.rb`
Expected: FAIL（`uninitialized constant DayMemo`）。

- [ ] **Step 5: モデルとファクトリを実装する**

`app/models/day_memo.rb`:

```ruby
# == Schema Information
#
# Table name: day_memos
#
#  id         :integer          not null, primary key
#  body       :text
#  date       :date             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
# Indexes
#
#  index_day_memos_on_family_id_and_date  (family_id,date) UNIQUE
#
class DayMemo < ApplicationRecord
  belongs_to :family

  validates :date, presence: true, uniqueness: { scope: :family_id }
  validates :body, length: { maximum: 1000 }
end
```

`spec/factories/day_memos.rb`:

```ruby
FactoryBot.define do
  factory :day_memo do
    association :family
    date { Time.zone.today }
    body { '家族メモ' }
  end
end
```

`app/models/family.rb` の `has_many :meals, dependent: :destroy` の後に追記する:

```ruby
  has_many :day_memos, dependent: :destroy
```

- [ ] **Step 6: テストを実行して成功を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/models/calendar/day_memo_spec.rb`
Expected: PASS（4 examples）。

- [ ] **Step 7: Lint とコミット**

```bash
docker compose run --rm --no-deps app bundle exec rubocop -A app/models/day_memo.rb app/models/family.rb spec/factories/day_memos.rb spec/models/calendar/day_memo_spec.rb
git add db/Schemafile app/models/day_memo.rb app/models/family.rb spec/factories/day_memos.rb spec/models/calendar/day_memo_spec.rb
git commit -m "feat: add DayMemo model for weekly dashboard"
```

---

### Task 2: `/weekly` グリッド画面とナビゲーション

週グリッド本体・週送り・ナビ追加まで。セルのタップ挙動は Task 3。

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/weekly_dashboard_controller.rb`
- Create: `app/views/weekly_dashboard/show.html.slim`
- Create: `app/views/weekly_dashboard/_grid_cell.html.slim`
- Create: `app/views/weekly_dashboard/_memo_cell.html.slim`
- Modify: `app/controllers/application_controller.rb`（`weekly_scope?`）
- Modify: `app/views/shared/_bottom_nav.html.slim`
- Modify: `app/views/shared/_sidebar.html.slim`
- Create: `spec/requests/weekly_dashboard_spec.rb`

**Interfaces:**
- Consumes: `DayMemo`（Task 1）。
- Produces: `GET /weekly`（`weekly_dashboard_path`）、`WeeklyDashboardController#show`、`weekly_scope?` helper。ビュー用ローカル partial `_grid_cell`（locals: `member`, `day`, `plans`）と `_memo_cell`（locals: `date`, `memo`）。`memo` は Task 4 で埋め込む。

- [ ] **Step 1: 失敗するリクエストスペックを書く**

`spec/requests/weekly_dashboard_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'WeeklyDashboard', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'はは') }
  let(:member) { create(:user, family: family, login_id: 'ちち') }
  let(:week_start) { Date.current.beginning_of_week }

  before { sign_in user }

  describe 'GET /weekly' do
    it 'returns http success' do
      get weekly_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it 'shows a plan in the participating member row' do
      plan = create(:plan, family: family, date: week_start, title: 'バイオリン練習')
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_dashboard_path
      expect(response.body).to include('バイオリン練習')
    end

    it 'shows a shared plan once per participating member' do
      plan = create(:plan, family: family, date: week_start, title: '家族イベント')
      create(:plan_participant, plan: plan, user: user, status: :joined)
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_dashboard_path
      expect(response.body.scan('家族イベント').size).to eq(2)
    end

    it 'hides a plan the member declined' do
      plan = create(:plan, family: family, date: week_start, title: '辞退した予定')
      create(:plan_participant, plan: plan, user: member, status: :declined)
      get weekly_dashboard_path
      expect(response.body).not_to include('辞退した予定')
    end

    it 'does not show plans from another family' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      plan = create(:plan, family: other_family, date: week_start, title: '他家族の予定')
      create(:plan_participant, plan: plan, user: other_user, status: :joined)
      get weekly_dashboard_path
      expect(response.body).not_to include('他家族の予定')
    end

    it 'shows the requested week when week param is given' do
      target = week_start - 1.week
      plan = create(:plan, family: family, date: target, title: '先週の予定')
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_dashboard_path(week: target.to_s)
      expect(response.body).to include('先週の予定')
    end

    it 'falls back to the current week for an invalid week param' do
      get weekly_dashboard_path(week: 'not-a-date')
      expect(response).to have_http_status(:success)
    end
  end

  context 'when not signed in' do
    before { sign_out user }

    it 'redirects to sign in page' do
      get weekly_dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/requests/weekly_dashboard_spec.rb`
Expected: FAIL（`undefined method 'weekly_dashboard_path'`）。

- [ ] **Step 3: ルートとコントローラを実装する**

`config/routes.rb` の `get 'calendar/monthly_list', ...` の後ろに追記する:

```ruby
  # 週間家族ダッシュボード
  get 'weekly', to: 'weekly_dashboard#show', as: :weekly_dashboard
```

`app/controllers/weekly_dashboard_controller.rb`:

```ruby
class WeeklyDashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @week_start = week_start
    @week_end = @week_start + 6
    @days = (@week_start..@week_end).to_a
    @members = current_user.family.users.order(:id)
    @plans_by_user = weekly_plans_index
    @memos_by_date = current_user.family.day_memos.where(date: @week_start..@week_end).index_by(&:date)
    @holidays = HolidayService.holidays
  end

  private

  def week_start
    return Date.current.beginning_of_week if params[:week].blank?

    Date.parse(params[:week].to_s).beginning_of_week
  rescue Date::Error, TypeError
    Date.current.beginning_of_week
  end

  def weekly_plans_index
    plans = current_user.family.plans
                        .where(date: @week_start..@week_end)
                        .includes(:plan_participants)
                        .ordered_by_time
    index = Hash.new { |hours, user_id| hours[user_id] = Hash.new { |days, date| days[date] = [] } }
    plans.each do |plan|
      plan.plan_participants.reject(&:declined?).each do |participant|
        index[participant.user_id][plan.date] << plan
      end
    end
    index
  end
end
```

`app/controllers/application_controller.rb` の `helper_method` 行と `setting_scope?` を変更する:

```ruby
  helper_method :current_scope, :my_scope?, :family_scope?, :setting_scope?, :weekly_scope?
```

```ruby
  def weekly_scope? = controller_name == 'weekly_dashboard'
```

- [ ] **Step 4: ビューを実装する**

`app/views/weekly_dashboard/show.html.slim`:

```slim
.container.mx-auto.px-2.py-4
  .flex.items-center.justify-between.mb-3
    = link_to weekly_dashboard_path(week: (@week_start - 7).to_s), class: 'btn btn-ghost btn-sm', aria: { label: '前週' } do
      i.fas.fa-chevron-left
    .flex.flex-col.items-center
      h1.text-xl.font-bold 家族ウィークリー
      span.text-xs.text-gray-500 = "#{@week_start.strftime('%-m/%-d')}〜#{@week_end.strftime('%-m/%-d')}"
    .flex.items-center.gap-1
      = link_to '今週', weekly_dashboard_path, class: 'btn btn-ghost btn-xs'
      = link_to weekly_dashboard_path(week: (@week_start + 7).to_s), class: 'btn btn-ghost btn-sm', aria: { label: '次週' } do
        i.fas.fa-chevron-right

  .overflow-x-auto.border.border-base-300.rounded-lg
    .grid style="grid-template-columns: 64px repeat(7, minmax(88px, 1fr));"
      .sticky.left-0.z-10.bg-base-200.border-b.border-r.border-base-300.p-1
      - @days.each do |day|
        .border-b.border-l.border-base-300.p-1.text-center.text-xs class=('bg-primary/10' if day == Date.current)
          .font-bold = %w[日 月 火 水 木 金 土][day.wday]
          .text-gray-500 = day.strftime('%-m/%-d')
          - if @holidays&.key?(day.to_s)
            .text-red-500.truncate = @holidays[day.to_s]

      - @members.each do |member|
        .sticky.left-0.z-10.bg-base-100.border-b.border-r.border-base-300.p-1.text-xs.font-medium.flex.items-center
          = member.display_name
        - @days.each do |day|
          = render 'grid_cell', member: member, day: day, plans: @plans_by_user[member.id][day]

      .sticky.left-0.z-10.bg-amber-50.border-t.border-r.border-base-300.p-1.text-xs.font-medium メモ
      - @days.each do |day|
        = render 'memo_cell', date: day, memo: @memos_by_date[day]
```

`app/views/weekly_dashboard/_grid_cell.html.slim`:

```slim
button.w-full.h-full.text-left.min-h-16.border-b.border-l.border-base-300.p-1.text-xs.hover:bg-base-200[
  data-controller="side-panel-opener"
  data-action="click->side-panel-opener#openWeeklyCell"
  data-user-id=member.id
  data-date=day.to_s
  class=('bg-primary/5' if day == Date.current)
]
  - plans.each do |plan|
    .truncate
      - if plan.start_time.present?
        span.text-gray-400 = plan.start_time.strftime('%H:%M')
      span.ml-1 = plan.title
```

`app/views/weekly_dashboard/_memo_cell.html.slim`:

```slim
button.w-full.text-left.min-h-12.border-b.border-l.border-base-300.p-1.text-xs.hover:bg-base-200[
  id="weekly-memo-#{date}"
  data-controller="side-panel-opener"
  data-action="click->side-panel-opener#openMemoForm"
  data-date=date.to_s
]
  - if memo&.body.present?
    span.text-amber-700 = "📝 #{memo.body.truncate(16)}"
  - else
    span.text-gray-300 ＋
```

- [ ] **Step 5: ナビゲーションを更新する**

`app/views/shared/_bottom_nav.html.slim` の Family リンクの後ろに追記し、Family リンクの active 判定を変更する:

```slim
    = link_to calendar_path(date: @date), class: "#{'dock-active' if family_scope? && !weekly_scope?}", data: { calendar_sync_date: 'true' } do
      i.fas.fa-users.text-3xl
      span.dock-label Family
    = link_to weekly_dashboard_path(date: @date), class: "#{'dock-active' if weekly_scope?}" do
      i.fas.fa-calendar-week.text-3xl
      span.dock-label 週
```

`app/views/shared/_sidebar.html.slim` の Family リンクの後ろに追記し、Family リンクの active 判定を変更する:

```slim
    li
      = link_to calendar_path(date: @date), class: "tooltip tooltip-right #{'menu-active' if family_scope? && !weekly_scope?}", data: { tip: 'Family Calendar', calendar_sync_date: 'true' } do
        i.fas.fa-users.text-3xl
    li
      = link_to weekly_dashboard_path(date: @date), class: "tooltip tooltip-right #{'menu-active' if weekly_scope?}", data: { tip: '週間ダッシュボード' } do
        i.fas.fa-calendar-week.text-3xl
```

- [ ] **Step 6: テストを実行して成功を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/requests/weekly_dashboard_spec.rb`
Expected: PASS（7 examples）。

- [ ] **Step 7: Lint とコミット**

```bash
docker compose run --rm --no-deps app bundle exec rubocop -A app/controllers/weekly_dashboard_controller.rb app/controllers/application_controller.rb spec/requests/weekly_dashboard_spec.rb config/routes.rb
git add config/routes.rb app/controllers/weekly_dashboard_controller.rb app/views/weekly_dashboard app/controllers/application_controller.rb app/views/shared/_bottom_nav.html.slim app/views/shared/_sidebar.html.slim spec/requests/weekly_dashboard_spec.rb
git commit -m "feat: add weekly family dashboard grid and navigation"
```

---

### Task 3: セル詳細パネル（予定の一覧・追加・編集）

セルをタップすると既存 `#side-panel` にその人・その日の予定一覧を表示し、追加・編集に進めるようにする。

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/weekly_dashboard_controller.rb`
- Create: `app/views/weekly_dashboard/_cell_panel.html.slim`
- Create: `app/views/weekly_dashboard/_cell_plan.html.slim`
- Modify: `app/javascript/controllers/side_panel_opener_controller.ts`
- Modify: `app/controllers/plans_controller.rb`（`new` で `participant_ids` を受ける）
- Modify: `spec/requests/weekly_dashboard_spec.rb`（cell の examples を追記）
- Modify: `spec/requests/calendar/plans_spec.rb`（新規作成しない。既存ファイルに `describe 'GET /plans/new'` を追記する）

**Interfaces:**
- Consumes: `weekly_cell_path`、`weekly_dashboard#cell`。
- Produces: `GET /weekly/cell?user_id=&date=`（`text/vnd.turbo-stream.html` で `#side-panel` を update）。Stimulus メソッド `openWeeklyCell()` と `openWeeklyPlanForm()`。`PlansController#new` が `participant_ids` を受け付ける。

- [ ] **Step 1: 失敗するリクエストスペックを書く**

`spec/requests/weekly_dashboard_spec.rb` の `describe 'GET /weekly'` ブロックの後に追記する:

```ruby
  describe 'GET /weekly/cell' do
    let(:date) { week_start }
    let(:turbo_headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

    it 'renders a turbo stream updating the side panel with the member plans' do
      plan = create(:plan, family: family, date: date, title: 'テニス')
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_cell_path(user_id: member.id, date: date.to_s), headers: turbo_headers
      expect(response).to have_http_status(:success)
      expect(response.body).to include('side-panel')
      expect(response.body).to include('テニス')
    end

    it 'does not include plans the member declined' do
      plan = create(:plan, family: family, date: date, title: '辞退した予定')
      create(:plan_participant, plan: plan, user: member, status: :declined)
      get weekly_cell_path(user_id: member.id, date: date.to_s), headers: turbo_headers
      expect(response.body).not_to include('辞退した予定')
    end

    it 'raises RecordNotFound for a member of another family' do
      other = create(:user, family: create(:family))
      expect do
        get weekly_cell_path(user_id: other.id, date: date.to_s), headers: turbo_headers
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'returns 400 for an invalid date' do
      get weekly_cell_path(user_id: member.id, date: 'not-a-date'), headers: turbo_headers
      expect(response).to have_http_status(:bad_request)
    end
  end
```

> 注意: テスト環境は `config.action_dispatch.show_exceptions = :none` のため、未捕捉例外はレスポンスではなく例外として伝播する（既存の `plans_spec.rb` も `raise_error(ActiveRecord::RecordNotFound)` で検証している）。他家族メンバーの 404 検証はこの形に合わせる。

`spec/requests/calendar/plans_spec.rb`（既存ファイル）の末尾 `end` の直前に `describe 'GET /plans/new'` ブロックを追記する（`sign_in user` はファイル冒頭の `before` で済んでいる）:

```ruby
  describe 'GET /plans/new' do
    it 'prefills the given participants' do
      get new_plan_path(date: Date.current.to_s, participant_ids: [other_user.id])
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/value="#{other_user.id}"[^>]*checked/)
    end
  end
```

> 注意: 既存の `plans_spec.rb` の内容は一切壊さない。`other_user` は既にファイル冒頭で定義済み。

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/requests/weekly_dashboard_spec.rb spec/requests/calendar/plans_spec.rb`
Expected: FAIL（`weekly_cell_path` 未定義、`participant_ids` の prefill が未実装）。

- [ ] **Step 3: ルートとコントローラを実装する**

`config/routes.rb` の `weekly` ルートの後に追記する:

```ruby
  get 'weekly/cell', to: 'weekly_dashboard#cell', as: :weekly_cell
```

`app/controllers/weekly_dashboard_controller.rb` の `show` の後に追記する:

```ruby
  def cell
    @member = current_user.family.users.find(params[:user_id])
    @date = Date.parse(params[:date].to_s)
    @plans = plans_for(@member, @date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel',
                                                 partial: 'weekly_dashboard/cell_panel',
                                                 locals: { member: @member, date: @date, plans: @plans })
      end
      format.html { redirect_to weekly_dashboard_path }
    end
  rescue Date::Error, TypeError
    head :bad_request
  end
```

`private` セクションに追記する:

```ruby
  def plans_for(member, date)
    current_user.family.plans
                .for_date(date)
                .left_joins(:plan_participants)
                .where(plan_participants: { user_id: member.id, status: %i[joined pending] })
                .includes(:participants, :plan_participants)
                .ordered_by_time
                .distinct
  end
```

- [ ] **Step 4: パネル partial を実装する**

`app/views/weekly_dashboard/_cell_panel.html.slim`:

```slim
.side-panel-overlay[
  data-controller="side-panel"
  data-side-panel-target="overlay"
  data-action="click->side-panel#closeBackground"
  style="display: block; position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 9999;"
]
  .side-panel-backdrop.opacity-0[data-side-panel-target="backdrop"]
  .side-panel.translate-x-full[data-side-panel-target="panel"]
    .side-panel-content
      .side-panel-header
        h3.text-lg.font-semibold.text-gray-900
          = "#{date.strftime('%-m/%-d')} #{member.display_name}"
        button.btn.btn-sm.btn-circle.btn-ghost[data-action="click->side-panel#close"]
          i.fas.fa-times

      .side-panel-body
        - if plans.any?
          .space-y-2
            - plans.each do |plan|
              = render 'weekly_dashboard/cell_plan', plan: plan
        - else
          p.text-sm.text-gray-400 予定はありません

      .side-panel-footer
        button.btn.btn-primary[
          data-controller="side-panel-opener"
          data-action="click->side-panel-opener#openWeeklyPlanForm"
          data-date=date.to_s
          data-user-id=member.id
        ]
          i.fas.fa-plus.mr-1
          | 予定を追加
```

`app/views/weekly_dashboard/_cell_plan.html.slim`:

```slim
.bg-blue-50.border-l-4.border-blue-400.p-2.rounded-r-lg
  button.text-left.font-medium.text-gray-800.hover:underline.w-full[
    data-controller="side-panel-opener"
    data-action="click->side-panel-opener#openPlanEdit"
    data-plan-id=plan.id
  ]
    - if plan.start_time.present?
      span.text-xs.text-gray-500.mr-1 = plan.start_time.strftime('%H:%M')
    = plan.title
```

- [ ] **Step 5: Stimulus に cell / plan form 起動を実装する**

`app/javascript/controllers/side_panel_opener_controller.ts` の `openMonthlyList()` の後に追記する:

```typescript
  openWeeklyCell(): void {
    const el = this.element as HTMLElement
    const userId = el.dataset.userId
    const date = el.dataset.date
    this.openSidePanel(`/weekly/cell?user_id=${userId}&date=${date}`)
  }

  openWeeklyPlanForm(): void {
    const el = this.element as HTMLElement
    const date = el.dataset.date
    const userId = el.dataset.userId
    this.openSidePanel(`/plans/new?date=${date}&scope=family&participant_ids[]=${userId}`)
  }
```

- [ ] **Step 6: `PlansController#new` で参加者プリセットを受け付ける**

`app/controllers/plans_controller.rb` の `new` 内にある `@plan.participant_ids = [current_user.id] if my_scope?` を次のブロックに置き換える（例外ハンドラ側の同じ行も同様に置き換える）:

```ruby
    if params[:participant_ids].present?
      @plan.participant_ids = Array(params[:participant_ids]).reject(&:blank?)
    elsif my_scope?
      @plan.participant_ids = [current_user.id]
    end
```

- [ ] **Step 7: テストを実行して成功を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/requests/weekly_dashboard_spec.rb spec/requests/calendar/plans_spec.rb`
Expected: PASS。

- [ ] **Step 8: Lint とコミット**

```bash
docker compose run --rm --no-deps app bundle exec rubocop -A app/controllers/weekly_dashboard_controller.rb app/controllers/plans_controller.rb spec/requests/weekly_dashboard_spec.rb spec/requests/calendar/plans_spec.rb config/routes.rb
git add config/routes.rb app/controllers/weekly_dashboard_controller.rb app/views/weekly_dashboard/_cell_panel.html.slim app/views/weekly_dashboard/_cell_plan.html.slim app/javascript/controllers/side_panel_opener_controller.ts app/controllers/plans_controller.rb spec/requests/weekly_dashboard_spec.rb spec/requests/calendar/plans_spec.rb
git commit -m "feat: add weekly dashboard cell detail panel"
```

---

### Task 4: 日ごとの家族メモの編集

メモ行のセルをタップして、その日の家族メモを編集・保存できるようにする。

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/weekly_dashboard_controller.rb`
- Create: `app/views/weekly_dashboard/_memo_form.html.slim`
- Modify: `app/javascript/controllers/side_panel_opener_controller.ts`
- Modify: `spec/requests/weekly_dashboard_spec.rb`（memo の examples を追記）

**Interfaces:**
- Consumes: `DayMemo`（Task 1）、`weekly_memo_path`、`_memo_cell`（Task 2）。
- Produces: `GET /weekly/memo?date=`（フォームを `#side-panel` に表示）、`PATCH /weekly/memo`（`date`, `body` で upsert し `#weekly-memo-<date>` を replace）。Stimulus `openMemoForm()`。

- [ ] **Step 1: 失敗するリクエストスペックを書く**

`spec/requests/weekly_dashboard_spec.rb` の `describe 'GET /weekly/cell'` ブロックの後に追記する:

```ruby
  describe 'day memo' do
    let(:date) { week_start }
    let(:turbo_headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

    describe 'GET /weekly/memo' do
      it 'renders the memo form in the side panel' do
        get weekly_memo_path(date: date.to_s), headers: turbo_headers
        expect(response).to have_http_status(:success)
        expect(response.body).to include('side-panel')
        expect(response.body).to include('家族メモ')
      end

      it 'returns 400 for an invalid date' do
        get weekly_memo_path(date: 'not-a-date'), headers: turbo_headers
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe 'PATCH /weekly/memo' do
      it 'creates a memo for the family on that date' do
        patch weekly_memo_path, params: { date: date.to_s, body: '牛乳買う' }, headers: turbo_headers
        expect(response).to have_http_status(:success)
        expect(family.day_memos.find_by(date: date).body).to eq('牛乳買う')
      end

      it 'updates an existing memo' do
        create(:day_memo, family: family, date: date, body: '旧メモ')
        patch weekly_memo_path, params: { date: date.to_s, body: '新メモ' }, headers: turbo_headers
        expect(family.day_memos.find_by(date: date).body).to eq('新メモ')
      end

      it 'replaces the memo cell in the response' do
        patch weekly_memo_path, params: { date: date.to_s, body: '牛乳買う' }, headers: turbo_headers
        expect(response.body).to include("weekly-memo-#{date}")
      end

      it 'rejects a body longer than 1000 characters' do
        patch weekly_memo_path, params: { date: date.to_s, body: 'あ' * 1001 }, headers: turbo_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(family.day_memos.find_by(date: date)).to be_nil
      end
    end

    it 'shows the memo body on the weekly grid' do
      create(:day_memo, family: family, date: date, body: '懇談会')
      get weekly_dashboard_path
      expect(response.body).to include('懇談会')
    end
  end
```

- [ ] **Step 2: テストを実行して失敗を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/requests/weekly_dashboard_spec.rb`
Expected: FAIL（`weekly_memo_path` 未定義）。

- [ ] **Step 3: ルートとコントローラを実装する**

`config/routes.rb` の `weekly/cell` ルートの後に追記する:

```ruby
  get 'weekly/memo', to: 'weekly_dashboard#edit_memo', as: :weekly_memo
  patch 'weekly/memo', to: 'weekly_dashboard#update_memo'
```

`app/controllers/weekly_dashboard_controller.rb` の `cell` の後に追記する:

```ruby
  def edit_memo
    @date = Date.parse(params[:date].to_s)
    @memo = current_user.family.day_memos.find_or_initialize_by(date: @date)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update('side-panel',
                                                 partial: 'weekly_dashboard/memo_form',
                                                 locals: { memo: @memo })
      end
      format.html { redirect_to weekly_dashboard_path }
    end
  rescue Date::Error, TypeError
    head :bad_request
  end

  def update_memo
    @date = Date.parse(params[:date].to_s)
    @memo = current_user.family.day_memos.find_or_initialize_by(date: @date)

    if @memo.update(body: params[:body].to_s)
      render turbo_stream: [
        turbo_stream.replace("weekly-memo-#{@date}", partial: 'weekly_dashboard/memo_cell',
                                                      locals: { date: @date, memo: @memo }),
        turbo_stream.append('side-panel', "<div data-controller='side-panel-closer'></div>".html_safe)
      ]
    else
      render turbo_stream: turbo_stream.update('side-panel',
                                               partial: 'weekly_dashboard/memo_form',
                                               locals: { memo: @memo }),
             status: :unprocessable_content
    end
  rescue Date::Error, TypeError
    head :bad_request
  end
```

- [ ] **Step 4: メモフォーム partial を実装する**

`app/views/weekly_dashboard/_memo_form.html.slim`:

```slim
.side-panel-overlay[
  data-controller="side-panel"
  data-side-panel-target="overlay"
  data-action="click->side-panel#closeBackground"
  style="display: block; position: fixed; top: 0; left: 0; right: 0; bottom: 0; z-index: 9999;"
]
  .side-panel-backdrop.opacity-0[data-side-panel-target="backdrop"]
  .side-panel.translate-x-full[data-side-panel-target="panel"]
    .side-panel-content
      = form_with url: weekly_memo_path, method: :patch, id: 'day-memo-form' do |f|
        .side-panel-header
          h3.text-lg.font-semibold.text-gray-900 = "#{memo.date.strftime('%-m/%-d')} の家族メモ"
          button.btn.btn-sm.btn-circle.btn-ghost[type="button" data-action="click->side-panel#close"]
            i.fas.fa-times

        .side-panel-body
          = hidden_field_tag :date, memo.date

          .form-control
            = f.text_area :body, value: memo.body, rows: 6, class: 'textarea w-full', placeholder: '家族への連絡メモ'
            - if memo.errors[:body].any?
              .text-error.text-sm.mt-1 = memo.errors[:body].join(', ')

        .side-panel-footer
          button.btn.btn-ghost[type="button" data-action="click->side-panel#close"] キャンセル
          = f.submit '保存', class: 'btn btn-primary'
```

- [ ] **Step 5: Stimulus に memo 起動を実装する**

`app/javascript/controllers/side_panel_opener_controller.ts` の `openWeeklyPlanForm()` の後に追記する:

```typescript
  openMemoForm(): void {
    const date = (this.element as HTMLElement).dataset.date
    this.openSidePanel(`/weekly/memo?date=${date}`)
  }
```

- [ ] **Step 6: テストを実行して成功を確認する**

Run: `docker compose run --rm --no-deps app bundle exec rspec spec/requests/weekly_dashboard_spec.rb`
Expected: PASS（全 examples）。

- [ ] **Step 7: Lint とコミット**

```bash
docker compose run --rm --no-deps app bundle exec rubocop -A app/controllers/weekly_dashboard_controller.rb spec/requests/weekly_dashboard_spec.rb config/routes.rb
git add config/routes.rb app/controllers/weekly_dashboard_controller.rb app/views/weekly_dashboard/_memo_form.html.slim app/javascript/controllers/side_panel_opener_controller.ts spec/requests/weekly_dashboard_spec.rb
git commit -m "feat: add editable daily family memo to weekly dashboard"
```

---

### Task 5: 統合確認

**Files:** なし（検証のみ）

- [ ] **Step 1: 全テストとLintを実行する**

Run: `docker compose run --rm --no-deps app bundle exec rspec`
Expected: すべて PASS。

Run: `docker compose run --rm --no-deps app bundle exec rubocop`
Expected: 新規 offense なし。

- [ ] **Step 2: ブラウザで手動確認する**

`/usr/bin/chromium` + puppeteer-core を使い、`http://localhost:1984/weekly` で:
- 月〜日のグリッドが表示され、メンバー行に予定が出る
- セルをタップ → サイドパネルに予定一覧と「予定を追加」が出る
- メモ行をタップ → メモを保存し、グリッドのメモセルに反映される

スクリーンショットを撮って確認する。

---

## 付録: 変更ファイル一覧

**新規**
- `app/models/day_memo.rb`
- `app/controllers/weekly_dashboard_controller.rb`
- `app/views/weekly_dashboard/show.html.slim`
- `app/views/weekly_dashboard/_grid_cell.html.slim`
- `app/views/weekly_dashboard/_memo_cell.html.slim`
- `app/views/weekly_dashboard/_cell_panel.html.slim`
- `app/views/weekly_dashboard/_cell_plan.html.slim`
- `app/views/weekly_dashboard/_memo_form.html.slim`
- `spec/factories/day_memos.rb`
- `spec/models/calendar/day_memo_spec.rb`
- `spec/requests/weekly_dashboard_spec.rb`

**変更**
- `db/Schemafile`（`day_memos`）
- `app/models/family.rb`（`has_many :day_memos`）
- `config/routes.rb`（`weekly`, `weekly/cell`, `weekly/memo`）
- `app/controllers/application_controller.rb`（`weekly_scope?`）
- `app/controllers/plans_controller.rb`（`new` の participant プリセット）
- `app/javascript/controllers/side_panel_opener_controller.ts`（起動メソッド3つ）
- `app/views/shared/_bottom_nav.html.slim`, `app/views/shared/_sidebar.html.slim`
- `spec/requests/calendar/plans_spec.rb`（`GET /plans/new` の prefill example を追記）

## メモ（実装中に判断）

- スマホは既存 `#side-panel` をそのまま使う（右からスライドし、モバイルでは全幅）。spec にあった「ボトムシート」は専用実装を避けるため既存パネルで代替する。UI が受け入れられない場合のみボトムシート化を別タスクにする。
- `labeled` な学校時限番号（紙の〇数字）は今回スコープ外。必要になったらメモ本文に含める運用から始める。
