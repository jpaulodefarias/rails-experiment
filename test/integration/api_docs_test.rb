require "test_helper"
require "yaml"

class ApiDocsTest < ActionDispatch::IntegrationTest
  test "serves Swagger UI and the OpenAPI specification" do
    get "/api-docs/"
    assert_redirected_to "/api-docs/index.html"
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Swagger UI"

    get "/api-docs/v1/openapi.yaml"
    assert_response :success

    document = YAML.safe_load(response.body)
    assert_equal "3.0.3", document.fetch("openapi")
    assert_equal %w[delete get post], document.fetch("paths").fetch("/api/v1/users").keys.sort
    assert_equal %w[delete get put], document.fetch("paths").fetch("/api/v1/users/{id}").keys.sort - ["parameters"]
    assert_equal "user.events.v1", document.fetch("x-kafka-events").fetch("topic")
    event_actions = document.dig("components", "schemas", "UserEvent", "properties", "action", "enum")
    assert_equal %w[created updated deleted], event_actions
  end
end
