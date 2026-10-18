class UserEvent < ApplicationRecord
  scope :pending, -> { where(published_at: nil) }
  scope :ready, -> { where("next_attempt_at IS NULL OR next_attempt_at <= ?", Time.current) }
  scope :first_for_user, lambda {
    where(<<~SQL.squish)
      NOT EXISTS (
        SELECT 1 FROM user_events earlier
        WHERE earlier.user_id = user_events.user_id
          AND earlier.id < user_events.id
          AND earlier.published_at IS NULL
      )
    SQL
  }

  validates :event_id, :user_id, :action, :payload, presence: true
  validates :event_id, uniqueness: true
  validates :action, inclusion: { in: %w[created updated deleted] }
end
