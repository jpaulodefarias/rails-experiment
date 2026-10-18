require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "returns UP when database responds" do
    get "/health"
    assert_response :ok
    assert_equal({ "status" => "UP" }, response.parsed_body)
  end

  test "returns DOWN when database query fails" do
    connection = ActiveRecord::Base.connection
    connection.define_singleton_method(:select_value) { |*| raise ActiveRecord::StatementInvalid, "failure" }

    get "/health"

    assert_response :service_unavailable
    assert_equal({ "status" => "DOWN" }, response.parsed_body)
  ensure
    connection&.singleton_class&.remove_method(:select_value)
  end
end
