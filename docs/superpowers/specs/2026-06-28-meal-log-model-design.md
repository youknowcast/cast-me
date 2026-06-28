# 今日何食べた？ 食事記録機能 設計（モデル＋画面）

作成日: 2026-06-28

## 目的

家族で「いつ・誰が・何を食べたか」を日毎に記録・共有する機能。

- 記録は家族（family）単位で共有する。
- 「誰が」は任意（null は「家族みんな」を表す）。
- 食べ物はフリーテキストではなく**マスタ管理**する。同じものを繰り返し食べるため。
- 1回の食事は基本1品だが、複数品目を紐づけられる。

## 想定パターン

| パターン | 記録の仕方 |
|---|---|
| ① 昼ラーメン／夜カレー（家族みんな） | 食事1件につき食べ物1件 |
| ② 子は給食・親はラーメン（同じ昼でも人で違う） | 「誰が」で分けて食事を別レコードに |
| ③ 晩に3種のカレーをみんなで | 食事1件に食べ物が複数 |

「誰が」は**食事(meal)単位**で持つ。品目ごとに人を変える（例: 父はキーマ・母はバターチキン）は仕様過多として採用しない。

## モデル構成（3テーブル）

`meal`（食事の記録: いつ・誰が） ⇄ `meal_food`（中間） ⇄ `food`（食べ物マスタ）の多対多。

### 1. `Food` — 食べ物マスタ

既存 `RegularTask` と同型。

| カラム | 型 | 制約 |
|---|---|---|
| `family_id` | bigint | not null |
| `name` | string(255) | not null |
| `active` | boolean | not null, default true |

- `active`: false＝非表示。**削除は行わず、選択肢から外すためのフラグ**。過去の記録（`meal_foods`）は参照を保ったまま残る。
- バリデーション: `name` presence / max 255 / `uniqueness: { scope: :family_id }`
- 関連: `belongs_to :family` / `has_many :meal_foods, dependent: :destroy` / `has_many :meals, through: :meal_foods`
- scope: `for_family` / `active`（`where(active: true)`、登録フォームのチップ選択用）
- インデックス: `[family_id, name]` UNIQUE / `[family_id, active]`（選択用の絞り込み）

### 2. `Meal` — 食事の記録（いつ・誰が）

| カラム | 型 | 制約 |
|---|---|---|
| `family_id` | bigint | not null |
| `user_id` | bigint | null 可（誰が。null=家族みんな） |
| `date` | date | not null |
| `meal_type` | integer | not null（0:朝 / 1:昼 / 2:夕 / 3:間食） |

- バリデーション: `date` presence / `meal_type` presence + `inclusion: { in: 0..3 }`
- 関連: `belongs_to :family` / `belongs_to :user, optional: true` / `has_many :meal_foods, dependent: :destroy` / `has_many :foods, through: :meal_foods`
- scope: `for_date` / `for_family` / `for_user`（tasks 準拠）
- `meal_type_text`（朝/昼/夕/間食）を `task.priority_text` の case 文方式で実装（既存コードに揃える）
- インデックス: `[family_id, date]` / `[user_id, date]` / `[date, meal_type]`

### 3. `MealFood` — 食事↔食べ物の中間

| カラム | 型 | 制約 |
|---|---|---|
| `meal_id` | bigint | not null |
| `food_id` | bigint | not null |

- バリデーション: `food_id` `uniqueness: { scope: :meal_id }`（同一食事への同一品目の二重登録を防止）
- 関連: `belongs_to :meal` / `belongs_to :food`
- インデックス: `[meal_id, food_id]` UNIQUE / `[food_id]`

## 既存モデルへの追加

- `Family`: `has_many :foods, dependent: :destroy` / `has_many :meals, dependent: :destroy`
- `User`: `has_many :meals, dependent: :nullify`（ユーザ削除時、記録は残し「誰が」を外す）

## パターン別の表現

- ① 昼: `Meal(昼, user=null)` + `MealFood(→ラーメン)` ／ 夜も同様
- ② 昼: `Meal(昼, user=子, →給食)` と `Meal(昼, user=親, →ラーメン)` の2件
- ③ 晩: `Meal(夕, user=null)` + `MealFood`×3（キーマ/バターチキン/野菜）

## 設計判断（YAGNI）

- **専用の使用回数カウントテーブルは作らない。** 「よく食べるもの」サジェストは `meal_foods` の `food_id` 件数で導出する（`[food_id]` インデックスを用意）。
- **写真・栄養情報・メモは初版では持たない。** 必要になった時点で追加する。
- **品目ごとの「誰が」は持たない。**「誰が」は食事単位。
- **食べ物マスタは削除しない。** 整理は `active` フラグで非表示にする（選択肢から外すのみ）。過去の記録を壊さないため。

## マイグレーション

ridgepole の `db/Schemafile` に3テーブルを追記する。

---

# 画面設計

## 方針

既存のカレンダー日次ビューに「今日何食べた？」セクションを**統合**する（新画面・新ナビは作らない）。アプリはカレンダー中心で、ユーザは日付軸で家族の出来事を見るため、食事も同じ導線に乗せる。

## 配置

日次ビュー（`calendar/_family_daily_view` / `calendar/_my_daily_view`）の **日付ヘッダー直下・user_section 群の上**に、その日に1つだけ食事セクションを置く。機能が埋もれないよう最上部に配置する。

食事セクションは**メンバー別に割らない**（食事の「誰が」は任意で null=家族みんなのため）。中身は**食事区分（朝/昼/夕/間食）でグルーピング**し、各行に食べ物と「誰が」（アバター/名前、null は「家族」）を表示する。

```
[日付ヘッダー]
─ 🍴 今日何食べた？                      [登録]
     朝   ・パン（家族）
     昼   ・給食（子）   ・ラーメン（父）
     夕   ・キーマ/バターチキン/野菜カレー（家族）
─ user_section: 父   （予定 / タスク）
─ user_section: 母   （予定 / タスク）
─ user_section: 子   （予定 / タスク）
```

## スコープ別の表示範囲

- **family ビュー（`/calendar`）**: その日の family の食事をすべて表示。
- **my ビュー（`/calendar/my`）**: 自分が関わる分のみ＝`user_id == current_user` ＋ `user_id == null`（家族みんなで食べた分は自分も含むので表示）。

## 登録フォーム（side-panel）

tasks と同じく side-panel に turbo_stream で差し込む。セクション内の「登録」ボタンで開く。

フィールド:

| 項目 | UI | 必須 | 既定値 |
|---|---|---|---|
| 食事区分 | セグメント or select（朝/昼/夕/間食） | 必須 | なし |
| 誰が | select（家族みんな＋メンバー） | 任意 | family:家族みんな(null) / my:current_user |
| 食べ物 | チップ式の複数選択（下記） | 必須（1件以上） | なし |
| 日付 | mobile_date_field | 必須 | 選択日をプリフィル |

### 食べ物の入力（チップ式・複数選択）

- 「よく食べるもの」として既存マスタをタップ追加（tasks の `regular_task_selector` 相当）。
  - **`active: true` のマスタのみ提示**（非表示にしたものは出さない）。
  - 提示順は `meal_foods` の使用頻度上位（専用カウントテーブルは作らず件数で導出）。
- 新しい食べ物はテキスト入力＋「＋追加」でチップ化。送信時に `Food` を find_or_create（family 内 name ユニーク）。
- 選択済みは ✕ 付きチップで表示し、複数登録できる（③の3種カレーに対応）。1品なら1チップ。
- 既存マスタ一覧の取得は `regular_tasks#index` 同様の JSON エンドポイント（`foods#index`、`active` のみ）を用意する想定（Stimulus 制御）。

## 保存後の挙動

tasks の create と同様に turbo_stream で:
- 日次ビューの食事セクションを更新（再描画）
- side-panel を閉じる
- （カレンダーセルにも食事の有無を出す場合は別途検討。初版はセクション更新のみ）

## 食べ物マスタ管理画面（設定）

設定画面（`settings/show`）に「食べ物マスタの管理」セクションを追加し、`foods_path`（HTML）へリンクする（既存の「毎日のタスク管理」と同じボタン形式）。

**`foods#index`（HTML 管理画面）**:
- family の食べ物マスタ一覧（name 昇順、件数が増えるなら kaminari でページング）。表示/非表示の両方を一覧する。
- 上部に**追加フォーム**（name 入力＋追加）。family 内 name ユニーク。
- 各行に **編集（リネーム）** と **表示/非表示トグル**（`active` の切り替え）。
- **削除は提供しない。** 整理は非表示で行う。

**コントローラ**: `resources :foods`（index/create/update）。
- `index`: HTML（管理画面、全件）＋ JSON（登録フォームのチップ選択用、`active` のみ）の両対応。
- `update`: リネーム（name）と表示/非表示（active）を扱う。
- `destroy` は作らない。

## ルーティング / コントローラ（概要）

- `resources :meals`（index は日次ビューに統合のため最小限、create/update/destroy/new/edit を turbo_stream 対応）。
- `resources :foods`（index/create/update）。マスタ管理画面（HTML）＋ 選択用 JSON。
- 設定画面に食べ物マスタ管理へのリンクを追加。
- 詳細な実装手順は別途 implementation plan で詰める。
