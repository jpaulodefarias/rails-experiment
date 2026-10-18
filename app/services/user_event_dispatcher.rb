class UserEventDispatcher
  MAX_RETRY_DELAY = 300
  STALLED_ATTEMPTS = 10

  def initialize(publisher:)
    @publisher = publisher
  end

  def dispatch_one
    UserEvent.transaction do
      event = next_event
      event ? deliver(event) : false
    end
  end

  def run
    loop do
      sleep 1 unless dispatch_one
    rescue StandardError => e
      Rails.logger.error(event: "user_event_dispatcher_failed", error: e.class.name, backtrace: e.backtrace&.first(5))
      sleep 5
    end
  end

  private

  def next_event
    UserEvent.pending.ready.first_for_user.order(:id).lock("FOR UPDATE SKIP LOCKED").first
  end

  def deliver(event)
    @publisher.publish(event)
    event.update!(published_at: Time.current, next_attempt_at: nil)
    true
  rescue StandardError => e
    schedule_retry(event, e)
    true
  end

  def schedule_retry(event, error)
    attempts = event.attempts + 1
    retry_at = Time.current + [2**[attempts, 9].min, MAX_RETRY_DELAY].min
    event.update!(attempts: attempts, next_attempt_at: retry_at, last_error_class: error.class.name)
    log_delivery_failure(event, error, retry_at)
  end

  def log_delivery_failure(event, error, retry_at)
    Rails.logger.error(delivery_failure_log(event, error, retry_at))
    log_stalled_event(event)
  end

  def delivery_failure_log(event, error, retry_at)
    {
      event: "user_event_delivery_failed",
      event_id: event.event_id,
      user_id: event.user_id,
      attempts: event.attempts,
      retry_at: retry_at.iso8601,
      error: error.class.name,
      backtrace: error.backtrace&.first(5)
    }
  end

  def log_stalled_event(event)
    return unless event.attempts >= STALLED_ATTEMPTS && (event.attempts % STALLED_ATTEMPTS).zero?

    Rails.logger.error(event: "user_event_stalled", event_id: event.event_id, user_id: event.user_id,
                       attempts: event.attempts)
  end
end
