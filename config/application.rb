require_relative "boot"

require "rails/all"
require_relative "../app/middleware/request_log_middleware"
require_relative "../app/lib/json_log_formatter"

Bundler.require(*Rails.groups)

module RailsExperiment
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.logger = ActiveSupport::Logger.new($stdout)
    config.logger.formatter = JsonLogFormatter.new
    config.middleware.use RequestLogMiddleware
  end
end
