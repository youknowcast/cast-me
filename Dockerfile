# syntax=docker/dockerfile:1
# Cache bust: 20241228-v2
ARG RUBY_VERSION=4.0.6
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
    xz-utils \
    pkg-config \
    libffi-dev \
    libyaml-dev \
    libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Node from the official tarball so the version matches .tool-versions
# (Debian's `nodejs` package lags several major versions behind).
#
# apt から tarball に変えたことでパッケージ署名による真正性チェックが無くなるため、
# 期待する SHA-256 を Dockerfile に固定してレビュー対象にする。
# NODE_VERSION を上げるときは以下のハッシュも更新すること:
#   curl -fsSL https://nodejs.org/dist/v<VERSION>/SHASUMS256.txt | grep 'linux-\(x64\|arm64\).tar.xz$'
ARG NODE_VERSION=24.19.0
ARG NODE_SHA256_x64=14b342e71204f811bde6153be8e04b62aef63c236fef92b55f9c83154b409647
ARG NODE_SHA256_arm64=01443c1e1a29e531ccad5a46fefa6df490d2189c49f7955904aecdbb0fe86fdc
ARG TARGETARCH=amd64
RUN case "$TARGETARCH" in \
      amd64) NODE_ARCH=x64; NODE_SHA256="$NODE_SHA256_x64" ;; \
      arm64) NODE_ARCH=arm64; NODE_SHA256="$NODE_SHA256_arm64" ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac && \
    NODE_TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" && \
    curl -fsSL -o "/tmp/${NODE_TARBALL}" \
      "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}" && \
    echo "${NODE_SHA256}  /tmp/${NODE_TARBALL}" | sha256sum -c - && \
    tar -xJf "/tmp/${NODE_TARBALL}" -C /usr/local --strip-components=1 --no-same-owner && \
    rm -f "/tmp/${NODE_TARBALL}" && \
    npm install -g yarn

# Install gems
COPY Gemfile Gemfile.lock .tool-versions ./
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
    sqlite3 \
    libyaml-0-2 \
    libffi8 \
    curl \
    gosu && \
    rm -rf /var/lib/apt/lists/*

# Copy built artifacts
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Create non-root user
RUN useradd rails --create-home --shell /bin/bash && \
    mkdir -p db data storage log tmp/pids tmp/cache tmp/sockets && \
    chown -R rails:rails db data storage log tmp

EXPOSE 3000

ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]