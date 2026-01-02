# frozen_string_literal: true

require 'onesignal'

OneSignal.configure do |config|
  config.app_key = ENV.fetch('ONESIGNAL_API_KEY', nil)
end
