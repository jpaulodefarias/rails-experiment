Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = false
  config.action_dispatch.show_exceptions = :rescuable
  config.active_support.deprecation = :stderr
  config.log_level = :warn
  config.log_formatter = JsonLogFormatter.new
end
