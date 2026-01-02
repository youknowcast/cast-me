# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

Rails.logger.debug '=== テストデータを作成中 ==='

# 家族の作成
family = Family.create!(name: 'sample')

Rails.logger.debug { "✓ 家族を作成: #{family.name}" }

# ユーザーの作成
user1 = User.create!(
  login_id: 'father',
  password: 'password123',
  family: family
)

user2 = User.create!(
  login_id: 'mother',
  password: 'password123',
  family: family
)

user3 = User.create!(
  login_id: 'child1',
  password: 'password123',
  family: family
)

user4 = User.create!(
  login_id: 'child2',
  password: 'password123',
  family: family
)

Rails.logger.debug { "✓ ユーザーを作成: #{user1.login_id}, #{user2.login_id}, #{user3.login_id}, #{user4.login_id}" }

# 今日の日付
today = Time.zone.today
1.day
tomorrow = today + 1.day
next_week = today + 7.days

# 予定の作成
plans = [
  {
    family: family,
    user: user1,
    date: today,
    title: '家族会議',
    description: '週末の予定について話し合い',
    start_time: '19:00',
    end_time: '20:00'
  },
  {
    family: family,
    user: user2,
    date: today,
    title: '買い物',
    description: 'スーパーで食材を買う',
    start_time: '15:00',
    end_time: '16:30'
  },
  {
    family: family,
    user: user1,
    date: tomorrow,
    title: '病院の予約',
    description: '定期検診',
    start_time: '10:00',
    end_time: '11:00'
  },
  {
    family: family,
    user: user2,
    date: next_week,
    title: '子どもの学校行事',
    description: '運動会の準備',
    start_time: '09:00',
    end_time: '15:00'
  }
]

plans.each do |plan_attrs|
  Plan.create!(plan_attrs)
end

Rails.logger.debug { "✓ 予定を作成: #{plans.count}件" }

# タスクの作成
tasks = [
  {
    family: family,
    user: user1,
    date: today,
    title: '洗濯物を干す',
    description: '朝の洗濯物を干す',
    priority: 1,
    completed: true
  },
  {
    family: family,
    user: user1,
    date: today,
    title: 'ゴミ出し',
    description: '燃えるゴミを出す',
    priority: 2,
    completed: false
  },
  {
    family: family,
    user: user2,
    date: today,
    title: '夕食の準備',
    description: '家族の夕食を作る',
    priority: 2,
    completed: false
  },
  {
    family: family,
    user: user2,
    date: today,
    title: '掃除機をかける',
    description: 'リビングの掃除',
    priority: 1,
    completed: true
  },
  {
    family: family,
    user: user3,
    date: today,
    title: '宿題を終わらせる',
    description: '算数の宿題',
    priority: 3,
    completed: false
  },
  {
    family: family,
    user: user1,
    date: tomorrow,
    title: '車の点検',
    description: '定期点検の予約',
    priority: 2,
    completed: false
  },
  {
    family: family,
    user: user2,
    date: tomorrow,
    title: '洗濯物を畳む',
    description: '昨日干した洗濯物',
    priority: 1,
    completed: false
  },
  {
    family: family,
    user: user3,
    date: next_week,
    title: '運動会の準備',
    description: 'お弁当の準備',
    priority: 3,
    completed: false
  },
  {
    family: family,
    user: user4,
    date: today,
    title: 'ピアノの練習',
    description: '明日のレッスンの準備',
    priority: 2,
    completed: false
  },
  {
    family: family,
    user: user4,
    date: tomorrow,
    title: '図書館で本を借りる',
    description: '夏休みの読書用',
    priority: 1,
    completed: false
  }
]

tasks.each do |task_attrs|
  Task.create!(task_attrs)
end

Rails.logger.debug { "✓ タスクを作成: #{tasks.count}件" }

# 既存のMomentデータ
Moment.create([
                { description: 'hoge', file_path: 'foo/bar/baz', link: 'https://example.com/hoge' }
              ])

Rails.logger.debug '=== テストデータの作成が完了しました ==='
Rails.logger.debug 'ログイン情報:'
Rails.logger.debug '  ユーザーID: father, mother, child1, child2'
Rails.logger.debug '  パスワード: password123'
