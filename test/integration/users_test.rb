require "test_helper"

class UsersTest < ActionDispatch::IntegrationTest
  test "creates, lists, shows, updates, and deletes a user" do
    post "/api/v1/users", params: { user: { name: " Ana ", email: " ANA@example.com " } }, as: :json
    assert_response :created
    id = response.parsed_body.fetch("id")
    assert_equal "ana@example.com", response.parsed_body.fetch("email")
    assert_match %r{/api/v1/users/#{id}\z}, response.location

    get "/api/v1/users"
    assert_response :ok
    ids = response.parsed_body.map { |user| user.fetch("id") }
    assert_equal [id], ids

    get "/api/v1/users/#{id}"
    assert_response :ok
    assert_equal "Ana", response.parsed_body.fetch("name")

    put "/api/v1/users/#{id}", params: { user: { name: "Bea" } }, as: :json
    assert_response :ok
    assert_equal "Bea", response.parsed_body.fetch("name")

    delete "/api/v1/users/#{id}"
    assert_response :no_content
    get "/api/v1/users/#{id}"
    assert_response :not_found
    assert_equal "USER_NOT_FOUND", response.parsed_body.fetch("code")
    assert response.parsed_body.fetch("traceId").present?
  end

  test "returns field errors for invalid user" do
    post "/api/v1/users", params: { user: { name: " ", email: "bad" } }, as: :json
    assert_response :unprocessable_entity
    assert_equal "VALIDATION_FAILED", response.parsed_body.fetch("code")
    assert response.parsed_body.fetch("fieldErrors").key?("email")
  end

  test "returns a bad request when user object is missing" do
    post "/api/v1/users", params: { name: "Ana" }, as: :json
    assert_response :bad_request
    assert_equal "BAD_REQUEST", response.parsed_body.fetch("code")
  end

  test "returns a not found error for an unknown route" do
    get "/unknown"
    assert_response :not_found
    assert_equal "NOT_FOUND", response.parsed_body.fetch("code")
  end

  test "rejects malformed JSON" do
    post "/api/v1/users", params: "{", headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :bad_request
    assert_equal "BAD_REQUEST", response.parsed_body.fetch("code")
  end

  test "deletes all users and accepts an empty collection" do
    User.create!(name: "Ana", email: "ana@example.com")
    User.create!(name: "Bea", email: "bea@example.com")
    2.times do
      delete "/api/v1/users"
      assert_response :no_content
    end
    assert_equal 0, User.count
    assert_equal 2, UserEvent.where(action: "deleted").count
  end
end
