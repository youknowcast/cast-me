# 月間食事一覧画面 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 家族が今月(および任意の月)に何を食べたかを日別に俯瞰できる画面を追加する (GitHub issue #80)

**Architecture:** 既存の `WeeklySummariesController` と同じパターンで、認証必須のシンプルな controller + Slim view 1枚を追加する。データは `Meal`(`foods` を includes)を月範囲で1クエリ取得し `group_by(&:date)`。月送りはプレーンな GET リンクで JS 不要。導線は家族カレンダーのヘッダーに置く。

**Tech Stack:** Rails 7 / Slim / Tailwind CSS + DaisyUI / RSpec (request spec) / FactoryBot

**Spec:** `docs/superpowers/specs/2026-08-08-monthly-meal-summary-design.md`

## Global Constraints

- View は必ず **Slim**(`.erb` 禁止)。スタイルは Tailwind + DaisyUI
- コード変更後は必ず `bundle exec rubocop -A` を実行し、新規 offense が無いことを確認する
- テスト実行はコンテナ内: `docker compose exec app bundle exec rspec <path>`(`spec/rails_helper.rb` が RAILS_ENV=test を強制するので通常はそのままで良い。Devise の "Could not find a valid mapping" / 403 / 422 が出たら env を疑う)
- スキーマ変更なし(既存の meals / foods / meal_foods テーブルのみ使用)
- inline JavaScript 禁止(この機能では JS 自体不要)

---

### Task 1: ルーティング + MonthlyMealSummariesController + 画面

**Files:**
- Modify: `config/routes.rb`(`resource :weekly_summary, only: [:show]` の直後、51行目付近)
- Create: `app/controllers/monthly_meal_summaries_controller.rb`
- Create: `app/views/monthly_meal_summaries/show.html.slim`
- Test: `spec/requests/monthly_meal_summary/monthly_meal_summaries_spec.rb`

**Interfaces:**
- Consumes: `Meal`(`.ordered_by_meal_type` scope, `#meal_type_text`)、`Food#name`、`current_user.family`
- Produces: ルート `monthly_meal_summary_path(month: 'YYYY-MM')`(GET, Task 2 がカレンダー画面からリンクする)

- [ ] **Step 1: 失敗する request spec を書く**

`spec/requests/monthly_meal_summary/monthly_meal_summaries_spec.rb` を作成:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MonthlyMealSummaries', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  def create_meal_with_food(family:, date:, food_name:, meal_type: 0)
    meal = create(:meal, family: family, date: date, meal_type: meal_type)
    food = create(:food, family: family, name: food_name)
    create(:meal_food, meal: meal, food: food)
    meal
  end

  describe 'GET /monthly_meal_summary' do
    context 'when not signed in' do
      it 'redirects to sign in' do
        get monthly_meal_summary_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when signed in' do
      before { sign_in user }

      it 'shows current month meals by default' do
        create_meal_with_food(family: family, date: Date.current.beginning_of_month, food_name: '納豆')

        get monthly_meal_summary_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('納豆')
        expect(response.body).to include(Date.current.strftime('%Y年%m月'))
      end

      it 'shows only meals of the specified month' do
        create_meal_with_food(family: family, date: Date.new(2026, 7, 10), food_name: 'カレー')
        create_meal_with_food(family: family, date: Date.new(2026, 8, 10), food_name: 'うどん')

        get monthly_meal_summary_path(month: '2026-07')

        expect(response.body).to include('カレー')
        expect(response.body).not_to include('うどん')
        expect(response.body).to include('2026年07月')
      end

      it 'does not show meals of other families' do
        other_family = create(:family)
        create_meal_with_food(family: other_family, date: Date.current.beginning_of_month, food_name: '他家族の食事')

        get monthly_meal_summary_path

        expect(response.body).not_to include('他家族の食事')
      end

      it 'falls back to current month for an invalid month param' do
        get monthly_meal_summary_path(month: 'invalid')

        expect(response).to have_http_status(:success)
        expect(response.body).to include(Date.current.strftime('%Y年%m月'))
      end

      it 'shows meal type labels' do
        create_meal_with_food(family: family, date: Date.current.beginning_of_month, food_name: 'ごはん', meal_type: 0)

        get monthly_meal_summary_path

        expect(response.body).to include('朝')
      end
    end
  end
end
```

- [ ] **Step 2: spec を実行して失敗を確認する**

Run: `docker compose exec app bundle exec rspec spec/requests/monthly_meal_summary/monthly_meal_summaries_spec.rb`
Expected: FAIL — `undefined method 'monthly_meal_summary_path'`(ルート未定義)

- [ ] **Step 3: ルートを追加する**

`config/routes.rb` の週次サマリ定義の直後に追加:

```ruby
  # 週次サマリ
  resource :weekly_summary, only: [:show]

  # 月間食事一覧
  resource :monthly_meal_summary, only: [:show]
```

- [ ] **Step 4: コントローラを実装する**

`app/controllers/monthly_meal_summaries_controller.rb` を作成:

```ruby
# frozen_string_literal: true

class MonthlyMealSummariesController < ApplicationController
  before_action :authenticate_user!

  def show
    base = parse_month(params[:month])
    @month_start = base.beginning_of_month
    @month_end = base.end_of_month
    @prev_month = (base - 1.month).strftime('%Y-%m')
    @next_month = (base + 1.month).strftime('%Y-%m')
    @meals_by_date = current_user.family.meals
                                 .where(date: @month_start..@month_end)
                                 .includes(:foods)
                                 .ordered_by_meal_type
                                 .group_by(&:date)
  end

  private

  def parse_month(value)
    Date.strptime(value.to_s, '%Y-%m')
  rescue ArgumentError, TypeError
    Date.current
  end
end
```

- [ ] **Step 5: view を実装する**

`app/views/monthly_meal_summaries/show.html.slim` を作成:

```slim
.container.mx-auto.px-4.py-8
  .flex.justify-between.items-center.mb-6
    h1.text-3xl.font-bold.text-gray-800 🍽 今月の食事
    = link_to calendar_path(date: @month_start), class: 'btn btn-ghost btn-sm' do
      i.fas.fa-calendar-days.mr-1
      | カレンダーへ

  .flex.justify-center.items-center.gap-4.mb-6
    = link_to monthly_meal_summary_path(month: @prev_month), class: 'btn btn-ghost btn-sm' do
      i.fas.fa-chevron-left.mr-1
      | 前月
    span.text-lg.font-semibold = @month_start.strftime('%Y年%m月')
    = link_to monthly_meal_summary_path(month: @next_month), class: 'btn btn-ghost btn-sm' do
      | 翌月
      i.fas.fa-chevron-right.ml-1

  .space-y-2
    - (@month_start..@month_end).each do |date|
      - meals = @meals_by_date[date] || []
      - wday_class = date.sunday? ? 'text-red-500' : (date.saturday? ? 'text-blue-500' : 'text-gray-700')
      .bg-white.rounded-lg.shadow.p-3 class=(meals.empty? ? 'opacity-50' : '')
        .flex.items-start.gap-3
          .w-16.shrink-0 class=wday_class
            span.font-semibold = date.strftime('%-m/%-d')
            span.text-xs.ml-1 = %w[日 月 火 水 木 金 土][date.wday]
          - if meals.any?
            .flex-1.space-y-1
              - meals.each do |meal|
                .flex.items-center.gap-2
                  span.badge.badge-outline.badge-sm.shrink-0 = meal.meal_type_text
                  span.text-sm = meal.foods.map(&:name).join(', ')
          - else
            span.text-sm.text-gray-400 記録なし
```

- [ ] **Step 6: spec を実行して成功を確認する**

Run: `docker compose exec app bundle exec rspec spec/requests/monthly_meal_summary/monthly_meal_summaries_spec.rb`
Expected: PASS (6 examples, 0 failures)

- [ ] **Step 7: rubocop を実行する**

Run: `docker compose exec app bundle exec rubocop -A`
Expected: no offenses(自動修正が入った場合は差分を確認)

- [ ] **Step 8: コミット**

```bash
git add config/routes.rb app/controllers/monthly_meal_summaries_controller.rb app/views/monthly_meal_summaries/show.html.slim spec/requests/monthly_meal_summary/monthly_meal_summaries_spec.rb
git commit -m "feat: 月間食事一覧画面を追加 (#80)"
```

---

### Task 2: 家族カレンダーからの導線

**Files:**
- Modify: `app/views/calendar/index.html.slim`(ヘッダー部、「月間予定リスト」ボタンの直後、20〜26行目付近)
- Test: `spec/requests/calendar/calendar_spec.rb`(既存の `describe 'GET /index'` に example 追加)

**Interfaces:**
- Consumes: Task 1 の `monthly_meal_summary_path(month: 'YYYY-MM')`、カレンダー画面の `@date`(表示中の月)

- [ ] **Step 1: 失敗する spec を書く**

`spec/requests/calendar/calendar_spec.rb` の `describe 'GET /index'` ブロック内に追加:

```ruby
    it 'links to the monthly meal summary for the displayed month' do
      get '/calendar', params: { date: '2026-08-15' }
      expect(response.body).to include(monthly_meal_summary_path(month: '2026-08'))
    end
```

- [ ] **Step 2: spec を実行して失敗を確認する**

Run: `docker compose exec app bundle exec rspec spec/requests/calendar/calendar_spec.rb`
Expected: FAIL — 追加した example のみ失敗(リンク未実装)。他の example が落ちる場合は手を止めて原因を確認する

- [ ] **Step 3: カレンダー画面にリンクを追加する**

`app/views/calendar/index.html.slim` の「月間予定リスト」ボタン(`data-action="click->side-panel-opener#openMonthlyList"` のブロック)の直後に追加:

```slim
    = link_to monthly_meal_summary_path(month: @date.strftime('%Y-%m')), class: 'btn btn-ghost btn-circle ml-2', title: '月間食事一覧' do
      i.fas.fa-utensils.text-xl
```

(インデントは隣の `button.btn.btn-ghost.btn-circle` と同じ深さに合わせる)

- [ ] **Step 4: spec を実行して成功を確認する**

Run: `docker compose exec app bundle exec rspec spec/requests/calendar/calendar_spec.rb`
Expected: PASS(既存 example も含め全て成功)

- [ ] **Step 5: 全体テスト + rubocop**

Run: `docker compose exec app bundle exec rspec && docker compose exec app bundle exec rubocop -A`
Expected: 全 spec PASS / no offenses

- [ ] **Step 6: コミット**

```bash
git add app/views/calendar/index.html.slim spec/requests/calendar/calendar_spec.rb
git commit -m "feat: 家族カレンダーに月間食事一覧への導線を追加 (#80)"
```

---

## 動作確認(実装完了後)

- http://localhost:1984/calendar を開き、ヘッダーのフォーク&ナイフアイコンから月間食事一覧に遷移できること
- 前月/翌月リンクで月が切り替わること
- 記録のない日が薄いグレーで表示されること
- モバイル幅(375px 程度)で食べ物名が折り返して読めること
