# OneSignal Push通知 実装ガイド（Rails + Devise）

## 概要

OneSignal を使用して Rails アプリケーションに Web Push 通知を実装するためのガイドです。

## 前提条件

- Rails 7.x
- Devise で認証済み
- HTTPS 環境（必須）
- iOS 16.4以上（PWA での Push 通知の場合）

---

## 1. OneSignal セットアップ

### 1.1 アカウント作成

1. [OneSignal Dashboard](https://onesignal.com/) でアカウント作成
2. 新しいアプリを作成
3. Platform で **Web** を選択
4. Site URL を設定（例: `https://example.com`）

### 1.2 取得する認証情報

| キー | 用途 |
|------|------|
| App ID | フロントエンド・バックエンド両方で使用 |
| REST API Key | バックエンドからの通知送信に使用 |

### 1.3 重要な設定

- **Settings → Keys & IDs → Identity Verification**: **OFF** にする
  - ON の場合、サーバーサイドでハッシュ生成が必要になる

---

## 2. バックエンド実装

### 2.1 Gemfile

```ruby
gem 'onesignal', '~> 2.2'
```

### 2.2 Initializer

```ruby
# config/initializers/onesignal.rb
require 'onesignal'

OneSignal.configure do |config|
  config.app_key = ENV['ONESIGNAL_API_KEY']
end
```

### 2.3 User モデル

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # OneSignal 用の external_id を生成
  # 数字のみの ID は OneSignal によってブロックされるため、プレフィックスを付ける
  # @see https://documentation.onesignal.com/docs/en/users#restricted-ids
  class << self
    def onesignal_external_id(id)
      "user_#{id}"
    end
  end

  def onesignal_external_id
    self.class.onesignal_external_id(id)
  end
end
```

> ⚠️ **重要**: `"1"`, `"123"` のような数字のみの ID は OneSignal によってブロックされます。必ずプレフィックスを付けてください。

### 2.4 通知送信サービス

```ruby
# app/services/push_notification_service.rb
class PushNotificationService
  class << self
    def send_to_users(user_ids:, title:, message:, url: nil)
      return if ENV['ONESIGNAL_APP_ID'].blank? || ENV['ONESIGNAL_API_KEY'].blank?

      external_ids = user_ids.map { |id| User.onesignal_external_id(id) }

      api_instance = OneSignal::DefaultApi.new

      notification = OneSignal::Notification.new(
        app_id: ENV['ONESIGNAL_APP_ID'],
        include_aliases: { 'external_id' => external_ids },
        target_channel: 'push',
        headings: { 'en' => title, 'ja' => title },
        contents: { 'en' => message, 'ja' => message }
      )

      notification.url = url if url.present?

      begin
        result = api_instance.create_notification(notification)
        Rails.logger.info("OneSignal notification sent: #{result.id}")
        result
      rescue OneSignal::ApiError => e
        Rails.logger.error("OneSignal API error: #{e.message}")
        nil
      end
    end
  end
end
```

---

## 3. フロントエンド実装

### 3.1 Service Worker

```javascript
// public/OneSignalSDKWorker.js
importScripts("https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js");
```

### 3.2 レイアウトへの SDK 追加

```slim
/ app/views/layouts/application.html.slim
doctype html
html
  head
    / ... 他のタグ ...

    / OneSignal Push Notifications SDK
    - if ENV['ONESIGNAL_APP_ID'].present?
      script src="https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js" defer=true
      javascript:
        window.OneSignalDeferred = window.OneSignalDeferred || [];
        OneSignalDeferred.push(async function(OneSignal) {
          await OneSignal.init({
            appId: "#{ENV['ONESIGNAL_APP_ID']}",
            allowLocalhostAsSecureOrigin: #{Rails.env.development?}
          });
        });
      - if user_signed_in?
        javascript:
          OneSignalDeferred.push(async function(OneSignal) {
            try {
              await OneSignal.login('#{current_user.onesignal_external_id}');
            } catch (error) {
              console.error('OneSignal login error:', error);
            }
          });
```

---

## 4. 環境変数

```bash
ONESIGNAL_APP_ID=your_app_id
ONESIGNAL_API_KEY=your_rest_api_key
```

---

## 5. 使用例

### コントローラーから通知送信

```ruby
class CommentsController < ApplicationController
  def create
    @comment = @post.comments.create!(comment_params.merge(user: current_user))

    # 投稿者に通知（自分自身を除外）
    if @post.user_id != current_user.id
      PushNotificationService.send_to_users(
        user_ids: [@post.user_id],
        title: "新しいコメント",
        message: "#{current_user.name}さんがコメントしました",
        url: post_url(@post)
      )
    end
  end
end
```

---

## 6. デバッグ方法

### 6.1 登録状況の確認（Rails Console）

```ruby
require 'net/http'
require 'json'

external_id = "user_1"
uri = URI("https://api.onesignal.com/apps/#{ENV['ONESIGNAL_APP_ID']}/users/by/external_id/#{external_id}")
request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Basic #{ENV['ONESIGNAL_API_KEY']}"

response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  http.request(request)
end

puts JSON.pretty_generate(JSON.parse(response.body))
```

### 6.2 確認すべきポイント

| 項目 | 正常値 |
|------|--------|
| `subscriptions[].enabled` | `true` |
| `subscriptions[].token` | 空でないこと |
| `identity.external_id` | `"user_1"` 形式 |

### 6.3 ブラウザ Console での確認

```javascript
// 購読状態
OneSignal.User.PushSubscription.optedIn  // true

// External ID
OneSignal.User.externalId  // "user_1"

// OneSignal ID
OneSignal.User.onesignalId  // UUID
```

---

## 7. トラブルシューティング

### "All included players are not subscribed"

**原因**: 対象ユーザーが通知を許可していない、または購読が無効

**対策**:
1. ブラウザ/PWA のサイトデータを完全にクリア
2. 再度通知を許可
3. Users API で `enabled: true` を確認

### "external_id is blocked"

**原因**: `"1"` のような数字のみの ID を使用

**対策**: `"user_1"` のようにプレフィックスを付ける

### iOS PWA で通知が届かない

**要件**:
- iOS 16.4 以上
- ホーム画面に追加（PWA として）
- PWA から開いた状態で通知許可

---

## 8. 制限事項

- Web Push は HTTPS 必須（localhost は例外）
- iOS Safari では PWA としてホーム画面に追加が必要
- ブラウザごとに通知許可が必要
- OneSignal の無料プランは Web Push 無制限、モバイルは制限あり
