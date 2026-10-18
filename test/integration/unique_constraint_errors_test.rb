require "test_helper"

class UniqueConstraintErrorsTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    UserEvent.delete_all
    User.delete_all
  end

  teardown do
    UserEvent.delete_all
    User.delete_all
  end

  test "maps only the email index to an email conflict" do
    user = User.create!(name: "Ana", email: "ana@example.com")
    timestamp = Time.current
    duplicate_email = lambda do |_attributes|
      User.insert_all!([{ name: "Other", email: user.email, created_at: timestamp, updated_at: timestamp }])
    end

    with_user_creation(duplicate_email) do
      post "/api/v1/users", params: { user: { name: "Other", email: user.email } }, as: :json
      assert_response :conflict
      assert_equal "EMAIL_ALREADY_EXISTS", response.parsed_body.fetch("code")
    end

    event = UserEvent.last
    duplicate_event = lambda do |_attributes|
      attributes = {
        event_id: event.event_id, user_id: user.id, action: event.action, payload: event.payload,
        created_at: timestamp, updated_at: timestamp
      }
      UserEvent.insert_all!([attributes])
    end

    with_user_creation(duplicate_event) do
      post "/api/v1/users", params: { user: { name: "Other", email: "other@example.com" } }, as: :json
      assert_response :internal_server_error
      assert_equal "INTERNAL_ERROR", response.parsed_body.fetch("code")
    end
  end

  private

  def with_user_creation(replacement)
    original = User.method(:new)
    User.define_singleton_method(:new, replacement)
    yield
  ensure
    User.define_singleton_method(:new, original) if original
  end
end
