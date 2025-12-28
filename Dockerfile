# syntax=docker/dockerfile:1
# Cache bust: 20241228-v2
ARG RUBY_VERSION=3.3.7
FROM ruby:$RUBY_VERSION AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LANG="ja_JP.UTF-8"

# Build stage
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    curl \
    pkg-config \
    libffi-dev \
    libyaml-dev \
    libsqlite3-dev \
    nodejs \
    npm && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

# Install gems
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install JS dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && \
    rm -rf node_modules tmp/cache

# Production stage
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    libsqlite3-0 \
    libyaml-0-2 \
    libffi8 \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Copy built artifacts
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Create non-root user
RUN useradd rails --create-home --shell /bin/bash && \
    mkdir -p db storage log tmp/pids tmp/cache tmp/sockets && \
    chown -R rails:rails db storage log tmp

USER rails:rails

EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]