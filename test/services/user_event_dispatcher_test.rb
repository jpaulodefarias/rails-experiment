require "test_helper"

class UserEventDispatcherTest < ActiveSupport::TestCase
  test "marks the event published after the publisher confirms delivery" do
    User.create!(name: "Ana", email: "ana@example.com")
    event = UserEvent.last
    delivered = []
    publisher = Object.new
    publisher.define_singleton_method(:publish) { |entry| delivered << entry.event_id }

    dispatcher = UserEventDispatcher.new(publisher: publisher)
    assert dispatcher.dispatch_one
    assert_equal [event.event_id], delivered
    assert event.reload.published_at.present?
    assert_not dispatcher.dispatch_one
  end

  test "retries failed deliveries without blocking other users or overtaking events for one user" do
    user = User.create!(name: "Ana", email: "ana@example.com")
    first = UserEvent.last
    user.update!(name: "Bea")
    second = UserEvent.last
    User.create!(name: "Carol", email: "carol@example.com")
    other = UserEvent.last
    delivered = []
    publisher = publisher_failing_once(first, delivered)

    dispatcher = UserEventDispatcher.new(publisher: publisher)
    assert dispatcher.dispatch_one
    assert_equal 1, first.reload.attempts
    assert first.next_attempt_at.future?
    assert_equal "RuntimeError", first.last_error_class
    assert_nil first.published_at

    assert dispatcher.dispatch_one
    assert_equal [other.id], delivered
    assert_not dispatcher.dispatch_one
    assert_nil second.reload.published_at

    first.update!(next_attempt_at: 1.second.ago)
    assert dispatcher.dispatch_one
    assert dispatcher.dispatch_one
    assert_equal [other.id, first.id, second.id], delivered
  end

  test "caps retry delays at five minutes" do
    User.create!(name: "Ana", email: "ana@example.com")
    event = UserEvent.last
    event.update!(attempts: 9)
    publisher = Object.new
    publisher.define_singleton_method(:publish) { |_| raise "broker unavailable" }

    assert UserEventDispatcher.new(publisher: publisher).dispatch_one
    assert_equal 10, event.reload.attempts
    assert_in_delta 300, event.next_attempt_at - Time.current, 2
    assert_nil event.published_at
  end

  private

  def publisher_failing_once(first, delivered)
    failures = 0
    Object.new.tap do |publisher|
      publisher.define_singleton_method(:publish) do |entry|
        if entry.id == first.id && failures.zero?
          failures += 1
          raise "broker unavailable"
        end

        delivered << entry.id
      end
    end
  end
end
