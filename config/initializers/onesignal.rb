# frozen_string_literal: true

require 'onesignal'

OneSignal.configure do |config|
  config.app_key = ENV['ONESIGNAL_API_KEY']
end
