require "test_helper"

class UserEventPublisherTest < ActiveSupport::TestCase
  test "publishes the JSON snapshot with the user ID as key and waits for confirmation" do
    user = User.create!(name: "Ana", email: "ana@example.com")
    event = UserEvent.last
    produced = nil
    wait_timeout = nil
    closed = false
    handle = Object.new
    handle.define_singleton_method(:wait) { |max_wait_timeout:| wait_timeout = max_wait_timeout }
    producer = Object.new
    producer.define_singleton_method(:produce) do |**options|
      produced = options
      handle
    end
    producer.define_singleton_method(:close) { closed = true }

    publisher = UserEventPublisher.new(producer: producer, topic: "user.events.v1")
    publisher.publish(event)
    publisher.close

    assert_equal "user.events.v1", produced.fetch(:topic)
    assert_equal user.id.to_s, produced.fetch(:key)
    assert_equal event.payload, JSON.parse(produced.fetch(:payload))
    assert_equal 15, wait_timeout
    assert closed
  end

  test "propagates delivery failures to the dispatcher" do
    User.create!(name: "Ana", email: "ana@example.com")
    handle = Object.new
    handle.define_singleton_method(:wait) { |**| raise "delivery failed" }
    producer = Object.new
    producer.define_singleton_method(:produce) { |**| handle }

    assert_raises(RuntimeError) do
      UserEventPublisher.new(producer: producer).publish(UserEvent.last)
    end
  end
end
