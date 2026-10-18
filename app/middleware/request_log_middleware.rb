class RequestLogMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status = 500
    status, headers, body = @app.call(env)
    [status, headers, body]
  ensure
    log_request(env, status, start)
  end

  private

  def log_request(env, status, start)
    request = ActionDispatch::Request.new(env)
    Rails.logger.info(
      event: "http_request",
      request_id: request.request_id,
      method: request.request_method,
      path: request.path,
      status: status,
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
    )
  end
end
