# 月間食事一覧画面 設計 (GitHub issue #80)

日付: 2026-08-08

## 目的

今月(および任意の月)に家族が何を食べたかを日別に俯瞰できる画面を追加する。
記録の振り返りと記録漏れの確認が目的。

## 要件

- 日別の一覧(カレンダー風の俯瞰)をメインとする
- スコープは家族全体。ユーザーフィルタは設けない
- 前月/翌月へのナビゲーションあり。デフォルトは当月
- 導線は家族カレンダー画面から

## ルーティング / コントローラ

- `config/routes.rb` に `resource :monthly_meal_summary, only: [:show]` を追加
  (既存の `resource :weekly_summary` と同パターン)
- `MonthlyMealSummariesController#show`
  - `before_action :authenticate_user!`
  - `params[:month]` は `"YYYY-MM"` 形式。パース失敗・未指定時は当月にフォールバック(例外にしない)
  - インスタンス変数:
    - `@month_start` / `@month_end` — 対象月の月初・月末
    - `@prev_month` / `@next_month` — `"YYYY-MM"` 文字列(リンク用)
    - `@meals_by_date` — 以下の1クエリを日付で group_by したもの

    ```ruby
    @meals_by_date = current_user.family.meals
      .where(date: @month_start..@month_end)
      .includes(:foods)
      .ordered_by_meal_type
      .group_by(&:date)
    ```

## 画面 (`app/views/monthly_meal_summaries/show.html.slim`)

- ヘッダー: タイトル「🍽 今月の食事」+ `‹ 前月 | 2026年8月 | 翌月 ›` のプレーンな GET リンク。JS 不要
- 本体: 月初〜月末を 1 日 = 1 カードの縦リスト
  - 日付見出し: 「8/8 (金)」形式。日曜は赤・土曜は青(既存カレンダーの配色に合わせる)
  - 各日の中は Meal ごとに 1 行: 食事タイプのバッジ(朝/昼/夕/間食)+ 食べ物名のカンマ区切り
    - 例: `朝 納豆, ごはん` / `夕 カレー`
    - 同日・同タイプに複数 Meal がある場合(個人別記録など)は行を分けて並べる
  - 記録のない日は日付のみを薄いグレーで表示(行として残し、記録漏れが視覚的にわかる)
- スタイル: Tailwind + DaisyUI。`weekly_summaries/show` と同様の `.bg-white.rounded-lg.shadow` ベース
- 画面下部または上部に家族カレンダーへ戻るリンク

## 導線

- `app/views/calendar/index.html.slim` のヘッダー部、「月間予定リスト」ボタンの隣に
  食事アイコン(`fa-utensils`)のボタンを追加し、
  `monthly_meal_summary_path(month: @date.strftime('%Y-%m'))` へリンク(表示中の月を引き継ぐ)

## エラーハンドリング

- `month` パラメータ不正時は当月表示にフォールバック
- 認証必須(未ログインはログイン画面へ)

## テスト (RSpec request spec)

- 未ログイン時はリダイレクト
- 当月がデフォルト表示される
- `month` 指定時にその月の Meal のみ表示される
- 他家族の Meal が表示されない
- 不正な `month` は当月にフォールバック

## やらないこと (YAGNI)

- 食べ物ごとの回数ランキング
- ユーザーフィルタ / 個人別集計
- CSV 出力
- Turbo Frame による部分更新(月送りはフルページ GET)
