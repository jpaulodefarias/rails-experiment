require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes fields and requires a valid unique email" do
    user = User.create!(name: " Ana ", email: " ANA@example.com ")
    assert_equal "Ana", user.name
    assert_equal "ana@example.com", user.email

    duplicate = User.new(name: "Other", email: "ANA@EXAMPLE.COM")
    assert_not duplicate.valid?
    assert duplicate.errors[:email].present?

    invalid = User.new(name: "  ", email: "invalid")
    assert_not invalid.valid?
    assert invalid.errors[:name].present?
    assert invalid.errors[:email].present?
  end

  test "database index rejects duplicate email without model validation" do
    User.create!(name: "Ana", email: "ana@example.com")
    assert_raises(ActiveRecord::RecordNotUnique) do
      User.insert_all!([{ name: "Bia", email: "ANA@example.com", created_at: Time.current, updated_at: Time.current }])
    end
  end

  test "records a snapshot for each successful change" do
    user = User.create!(name: "Ana", email: "ana@example.com")
    user.update!(name: "Bea")
    user.destroy!

    events = UserEvent.order(:id).to_a
    assert_equal %w[created updated deleted], events.map(&:action)
    names = events.map { |event| event.payload.dig("user", "name") }
    assert_equal %w[Ana Bea Bea], names
    assert_equal [user.id], events.map { |event| event.payload.dig("user", "id") }.uniq
    payload_ids = events.map { |event| event.payload.fetch("eventId") }
    assert_equal events.map(&:event_id), payload_ids
    assert_equal [nil], events.map(&:published_at).uniq
  end

  test "does not record an event for rejected changes" do
    invalid = User.new(name: "", email: "invalid")
    assert_not invalid.save
    assert_equal 0, UserEvent.count

    user = User.create!(name: "Ana", email: "ana@example.com")
    assert_not user.update(email: "invalid")
    assert_equal %w[created], UserEvent.pluck(:action)
  end

  test "does not record an updated event when user details do not change" do
    user = User.create!(name: "Ana", email: "ana@example.com")
    user.update!(name: "Ana", email: "ANA@example.com")

    assert_equal %w[created], UserEvent.pluck(:action)
  end

  test "rolls back the event with the user change" do
    User.transaction do
      User.create!(name: "Ana", email: "ana@example.com")
      raise ActiveRecord::Rollback
    end

    assert_equal 0, User.count
    assert_equal 0, UserEvent.count
  end
end
