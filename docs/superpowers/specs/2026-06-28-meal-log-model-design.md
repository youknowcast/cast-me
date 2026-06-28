# 今日何食べた？ 食事記録機能 モデル設計

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

- バリデーション: `name` presence / max 255 / `uniqueness: { scope: :family_id }`
- 関連: `belongs_to :family` / `has_many :meal_foods, dependent: :restrict_with_error` / `has_many :meals, through: :meal_foods`
- scope: `for_family`
- インデックス: `[family_id, name]` UNIQUE

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

## マイグレーション

ridgepole の `db/Schemafile` に3テーブルを追記する。
