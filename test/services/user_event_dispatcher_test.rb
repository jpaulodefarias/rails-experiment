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

  test "keeps failed deliveries pending for retry" do
    User.create!(name: "Ana", email: "ana@example.com")
    event = UserEvent.last
    publisher = Object.new
    publisher.define_singleton_method(:publish) { |_| raise "broker unavailable" }

    assert_raises(RuntimeError) { UserEventDispatcher.new(publisher: publisher).dispatch_one }
    assert_nil event.reload.published_at
  end
end
