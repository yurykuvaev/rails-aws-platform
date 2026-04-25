require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false

  # Per spec: serve static files even in production (no CDN/nginx fronting)
  config.public_file_server.enabled = true

  config.log_level = :info
  config.log_tags = [:request_id]

  # Per spec: log to STDOUT so Docker/CloudWatch can collect
  logger           = ActiveSupport::Logger.new(STDOUT)
  logger.formatter = ::Logger::Formatter.new
  config.logger    = ActiveSupport::TaggedLogging.new(logger)

  config.active_support.deprecation = :notify
  config.active_support.disallowed_deprecation = :log
  config.active_support.disallowed_deprecation_warnings = []

  # Per spec: do not force SSL (TLS terminates at the ALB)
  config.force_ssl = false

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false
end
