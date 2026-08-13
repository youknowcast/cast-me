# frozen_string_literal: true

require 'onesignal'

OneSignal.configure do |config|
  # onesignal 5.x で設定名が app_key -> rest_api_key に変更された
  # (Authorization: Key "<REST API Key>" として送信される)
  config.rest_api_key = ENV.fetch('ONESIGNAL_API_KEY', nil)
end
