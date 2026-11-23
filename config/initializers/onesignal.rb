# frozen_string_literal: true

require 'onesignal'

OneSignal.configure do |config|
  # onesignal 5.x で設定名が app_key -> rest_api_key に変更された
  # (Authorization: Key "<REST API Key>" として送信される)
  config.rest_api_key = ENV.fetch('ONESIGNAL_API_KEY', nil)
  # 既定は 0 (タイムアウトなし)。ディスパッチャは常駐スレッド1本なので、
  # 1回のハングで全リマインダが止まらないよう秒単位で上限を設ける。
  config.timeout = 10
end
