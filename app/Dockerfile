# syntax=docker/dockerfile:1

# ---------- Builder ----------
FROM ruby:3.2 AS builder

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock* ./

# Default builds skip dev/test groups (lean production image).
# Override in docker-compose.yml for local dev: --build-arg BUNDLE_WITHOUT=""
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="${BUNDLE_WITHOUT}"

RUN bundle install

COPY . .

# ---------- Runtime ----------
FROM ruby:3.2-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      default-mysql-client \
      libjemalloc2 \
      curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=app:app /app /app

# Strip Windows CRLF from any bin/ scripts (harmless on Linux files);
# create runtime dirs Rails expects; ensure /app itself is owned by app
# (WORKDIR created it as root before the COPY ran).
RUN find bin -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true && \
    chmod +x bin/* 2>/dev/null || true && \
    mkdir -p tmp/pids log storage && \
    chown -R app:app /app

# Must match the value used in the builder stage so bundler at runtime
# doesn't try to load gems that weren't installed.
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="${BUNDLE_WITHOUT}" \
    RAILS_LOG_TO_STDOUT=1

USER app

EXPOSE 3000

CMD ["bash", "-c", "bundle exec rails db:migrate && bundle exec puma -C config/puma.rb"]
