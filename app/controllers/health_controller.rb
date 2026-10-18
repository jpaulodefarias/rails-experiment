class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: { status: "UP" }
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(event: "health_check_failed", request_id: request.request_id, error: e.class.name)
    render json: { status: "DOWN" }, status: :service_unavailable
  end
end
