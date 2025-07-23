#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# データベースファイルが存在しない場合のみ初期化を実行
if [ ! -f /app/db/development.sqlite3 ]; then
  echo "Database file not found. Initializing database..."
  
  # データベースの作成
  bundle exec rails db:create 2>/dev/null || true

  # Ridgepoleでスキーマを適用
  echo "Applying database schema with Ridgepole..."
  bundle exec ridgepole -c config/database.yml -E ${RAILS_ENV:-development} --apply -f db/Schemafile

  # 初期データの投入（開発環境のみ）
  if [ "$RAILS_ENV" = "development" ]; then
    echo "Seeding database..."
    bundle exec rails db:seed
  fi
else
  echo "Database file exists. Skipping initialization."
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile)
exec "$@" 