require "uri"

class User < ApplicationRecord
  before_validation :normalize_fields
  after_create { record_event("created") }
  after_update :record_updated_event, if: :user_details_changed?
  after_destroy { record_event("deleted") }

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }

  def public_attributes
    as_json(only: %i[id name email created_at updated_at])
  end

  private

  def normalize_fields
    self.name = name.strip if name.is_a?(String)
    self.email = email.strip.downcase if email.is_a?(String)
  end

  def record_event(action)
    event_id = SecureRandom.uuid
    UserEvent.create!(event_id: event_id, user_id: id, action: action, payload: event_payload(action, event_id))
  end

  def record_updated_event
    record_event("updated")
  end

  def user_details_changed?
    saved_changes.except("updated_at").present?
  end

  def event_payload(action, event_id)
    {
      eventId: event_id,
      action: action,
      occurredAt: Time.current.iso8601(3),
      user: public_attributes
    }
  end
end
