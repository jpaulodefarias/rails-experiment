class UserEvent < ApplicationRecord
  scope :pending, -> { where(published_at: nil) }

  validates :event_id, :user_id, :action, :payload, presence: true
  validates :event_id, uniqueness: true
  validates :action, inclusion: { in: %w[created updated deleted] }
end
