# CastMe

家族・個人向けのカレンダー＆タスク管理アプリケーション

## 機能

- 📅 **カレンダー管理** - 個人/家族の予定を一元管理
- ✅ **タスク管理** - 優先度付きタスクの作成・完了管理
- 👨‍👩‍👧‍👦 **家族共有** - 家族メンバー間での予定・タスク共有
- 🔔 **プッシュ通知** - OneSignal連携による定時リマインダー
- 📱 **モバイル対応** - PWA対応のレスポンシブデザイン

## 技術スタック

- Ruby 3.3 / Rails 7.0
- SQLite
- Hotwire (Turbo + Stimulus)
- Tailwind CSS + DaisyUI
- Kamal 2 (デプロイ)

## セットアップ

```bash
# 依存関係のインストール
bundle install
yarn install

# Docker Composeで起動
docker compose up

# ブラウザでアクセス
open http://localhost:1984
```

## 開発

```bash
# テスト実行
bundle exec rspec

# Lintチェック
bundle exec rubocop -A
```

詳細な開発ガイドラインは [AGENTS.md](./AGENTS.md) を参照してください。

## ライセンス

MIT License - 詳細は [LICENSE](./LICENSE) を参照
