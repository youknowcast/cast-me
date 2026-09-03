source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby file: '.tool-versions'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 8.1'

# Use Puma as the app server
gem 'puma', '~> 8.0'
# Asset pipeline - Propshaft is simpler and supports modern CSS
gem 'propshaft'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
# gem 'webpacker', '~> 5.0'
# gem 'turbolinks' # Removed: superseded by turbo-rails, and no longer referenced anywhere
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# gem 'image_processing' # Removed: Active Storage の variant は未使用で、
# アバターのリサイズは SettingsController が sips / convert を直接呼んでいる

gem 'devise'

gem 'ridgepole'

gem 'stimulus-rails'
gem 'turbo-rails'

gem 'kaminari'
gem 'slim-rails'
gem 'tailwindcss-rails', '~> 4.6'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.4', require: false

# gem 'redis-rails' # Removed: not in use

# Ruby 3.3 では以下は標準ライブラリに含まれているため明示的な指定は不要
# gem 'base64'
# gem 'bigdecimal'
# gem 'fiddle'
# gem 'logger'
# gem 'mutex_m'
# gem 'observer'
# gem 'ostruct'
# gem 'rdoc'

# PostgreSQLのgemをコメントアウトまたは削除
# gem "pg"

# SQLiteのgemを追加
gem 'sqlite3'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: %i[mri windows]

  gem 'dotenv-rails'
  gem 'factory_bot_rails'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'listen', '~> 3.3'
  gem 'rack-mini-profiler', '~> 4.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # gem 'annotate' # Temporarily disabled: incompatible with Rails 8 (activerecord < 8.0)
  # gem 'spring' # Removed: not needed in Rails 8

  # Code linting
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :test do
  gem 'rspec-rails'
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara', '>= 3.26'
  # Driver binaries are resolved by Selenium Manager (built into selenium-webdriver >= 4.11),
  # so the webdrivers gem is no longer needed — it also pinned selenium-webdriver < 4.11.
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

gem 'jsbundling-rails', '~> 1.0'

# Push notifications
gem 'onesignal', '~> 5.11'
