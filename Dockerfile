FROM rubylang/ruby:3.3.5-focal

ENV LANG ja_JP.UTF-8

RUN apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential git curl libmysqlclient-dev && \
  apt-get clean && \
  rm -rf /var/cache/apt/archives/* && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
  truncate -s 0 /var/log/*log

ENV GEM_HOME /bundle
ENV BUNDLE_PATH ${GEM_HOME}
ENV BUNDLE_APP_CONFIG ${BUNDLE_PATH}
ENV BUNDLE_BIN ${BUNDLE_PATH}/bin
ENV PATH: /app/bin:$BUNDLE_BIN:$PATH

# Run only `bundle install` first for caching
RUN mkdir -p /app
COPY Gemfile Gemfile.lock .ruby-version /app/
WORKDIR /app
RUN bundle config set jobs 4 && bundle install

COPY . /app

CMD ["bin/rails", "s"]