class UserEventDispatcher
  def initialize(publisher:)
    @publisher = publisher
  end

  def dispatch_one
    UserEvent.transaction do
      event = UserEvent.pending.order(:id).lock("FOR UPDATE SKIP LOCKED").first
      if event
        @publisher.publish(event)
        event.update!(published_at: Time.current)
        true
      else
        false
      end
    end
  end

  def run
    loop do
      sleep 1 unless dispatch_one
    rescue StandardError => e
      Rails.logger.error(event: "user_event_delivery_failed", error: e.class.name)
      sleep 5
    end
  end
end
