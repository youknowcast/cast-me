source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby file: '.ruby-version'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 8.0'

# Use Puma as the app server
gem 'puma', '~> 6'
# Asset pipeline - Propshaft is simpler and supports modern CSS
gem 'propshaft'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
# gem 'webpacker', '~> 5.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
gem 'image_processing', '~> 1.2'

gem 'devise'

gem 'ridgepole'

gem 'stimulus-rails'
gem 'turbo-rails'

gem 'kaminari'
gem 'ransack'

gem 'slim-rails'
gem 'tailwindcss-rails', '~> 2.7.9'

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
  gem 'byebug', platforms: %i[mri mingw x64_mingw]

  gem 'dotenv-rails'
  gem 'factory_bot_rails'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 4.1.0'
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem 'listen', '~> 3.3'
  gem 'rack-mini-profiler', '~> 2.0'
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
  gem 'selenium-webdriver'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'shoulda-matchers'
  gem 'webdrivers', '~> 5.3.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'jsbundling-rails', '~> 1.0'

# Push notifications
gem 'onesignal', '~> 2.2'
