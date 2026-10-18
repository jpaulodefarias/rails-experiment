require "test_helper"

class UserEventConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    UserEvent.delete_all
    User.delete_all
  end

  teardown do
    UserEvent.delete_all
    User.delete_all
  end

  test "does not publish a later event while an earlier event for the same user is locked" do
    user = User.create!(name: "Ana", email: "ana@example.com")
    first = UserEvent.last
    user.update!(name: "Bea")
    ready = Queue.new
    release = Queue.new
    locker = lock_event_in_thread(first, ready, release)

    result = ready.pop
    raise result if result.is_a?(Exception)

    delivered = []
    publisher = Object.new
    publisher.define_singleton_method(:publish) { |entry| delivered << entry.id }
    assert_not UserEventDispatcher.new(publisher: publisher).dispatch_one
    assert_empty delivered
  ensure
    release&.push(true)
    locker&.join
  end

  private

  def lock_event_in_thread(event, ready, release)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        UserEvent.find(event.id).with_lock do
          ready << true
          release.pop
        end
      end
    rescue StandardError => e
      ready << e
    end
  end
end
