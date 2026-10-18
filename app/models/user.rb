require "uri"

class User < ApplicationRecord
  before_validation :normalize_fields
  after_create { record_event("created") }
  after_update { record_event("updated") }
  after_destroy { record_event("deleted") }

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }

  private

  def normalize_fields
    self.name = name.strip if name.is_a?(String)
    self.email = email.strip.downcase if email.is_a?(String)
  end

  def record_event(action)
    event_id = SecureRandom.uuid
    UserEvent.create!(event_id: event_id, user_id: id, action: action, payload: event_payload(action, event_id))
  end

  def event_payload(action, event_id)
    {
      eventId: event_id,
      action: action,
      occurredAt: Time.current.iso8601(3),
      user: as_json(only: %i[id name email created_at updated_at])
    }
  end
end
