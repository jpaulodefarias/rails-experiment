require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = false
  config.active_support.deprecation = :log
  config.log_level = ENV.fetch("LOG_LEVEL", "debug").to_sym
  config.log_formatter = JsonLogFormatter.new
end
