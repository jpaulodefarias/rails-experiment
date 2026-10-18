require "json"
require "logger"
require "time"

class JsonLogFormatter < Logger::Formatter
  def call(severity, time, _progname, message)
    attributes = message.is_a?(Hash) ? message : { message: message.to_s }
    payload = { timestamp: time.utc.iso8601(3), severity: severity }.merge(attributes).to_json
    "#{payload}\n"
  end
end
