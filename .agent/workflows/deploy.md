---
description: Kamal を使用して AWS LightSail にデプロイする手順
---

# Kamal Deploy Workflow

このワークフローは CastMe を AWS LightSail にデプロイする手順を説明します。

## 前提条件

- AWS CLI がインストール・設定済み
- Docker がインストール済み
- Kamal がインストール済み (`gem install kamal`)
- LightSail インスタンスが作成済み

## 環境変数の設定

デプロイ前に以下の環境変数を設定してください：

```bash
export AWS_ACCOUNT_ID=<your-aws-account-id>
export DEPLOY_HOST=<your-lightsail-ip>
export S3_BACKUP_BUCKET=castme-backups
```

## 初回セットアップ

### 1. AWS ECR リポジトリ作成

```bash
aws ecr create-repository --repository-name castme --region ap-northeast-1
```

### 2. LightSail インスタンスに Docker をインストール

// turbo
```bash
ssh ubuntu@$DEPLOY_HOST "curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker ubuntu"
```

### 3. S3 バックアップバケット作成

```bash
aws s3 mb s3://castme-backups --region ap-northeast-1
```

### 4. Kamal 初回セットアップ

```bash
kamal setup
```

## 通常のデプロイ

// turbo
```bash
kamal deploy
```

## ロールバック

問題が発生した場合：

```bash
kamal rollback
```

## ログ確認

```bash
kamal app logs
```

## バックアップ

### 手動バックアップ

```bash
kamal app exec "bin/backup/s3_backup.sh"
```

### crontab 設定（LightSail サーバー上）

```bash
# 1日3回バックアップ（8:00, 14:00, 20:00 JST）
0 23,5,11 * * * docker exec $(docker ps -q -f name=castme-web) bin/backup/s3_backup.sh
```

## トラブルシューティング

### コンテナの状態確認

```bash
kamal app details
```

### SSH でサーバーに接続

```bash
kamal app exec --interactive bash
```

### Rails コンソール

```bash
kamal app exec "rails console"
```
