# CastMe

家族・個人向けのカレンダー＆タスク管理アプリケーション

## 機能

- 📅 **カレンダー管理** - 個人/家族の予定を一元管理
- ✅ **タスク管理** - 優先度付きタスクの作成・完了管理
- 👨‍👩‍👧‍👦 **家族共有** - 家族メンバー間での予定・タスク共有
- 🔔 **プッシュ通知** - OneSignal連携による定時リマインダー
- 📱 **モバイル対応** - PWA対応のレスポンシブデザイン

## 技術スタック

- Ruby 4.0 / Rails 8.1
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

### リリースノート

利用者向けの変更は [`RELEASE_NOTES.md`](./RELEASE_NOTES.md) に追記します。見出しは `## YYYY-MM-DD 見出し`、内容は `- ` の箇条書きで、新しい日付を上に書きます。書式の詳細はファイル冒頭のコメントを参照してください。依存更新などの開発者向け変更は載せません。

詳細な開発ガイドラインは [AGENTS.md](./AGENTS.md) を参照してください。

## ライセンス

MIT License - 詳細は [LICENSE](./LICENSE) を参照
