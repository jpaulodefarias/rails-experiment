Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym
  config.log_formatter = JsonLogFormatter.new
  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")
end
