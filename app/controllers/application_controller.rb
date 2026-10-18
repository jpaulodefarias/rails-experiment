class ApplicationController < ActionController::API
  rescue_from StandardError, with: :internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordNotUnique, with: :record_not_unique
  rescue_from ActionController::BadRequest, with: :bad_request
  rescue_from ActionController::ParameterMissing, with: :bad_request
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :bad_request

  private

  def render_error(code:, message:, status:, field_errors: nil)
    payload = { code: code, message: message, traceId: request.request_id }
    payload[:fieldErrors] = field_errors if field_errors.present?
    render json: payload, status: status
  end

  def record_not_found
    render_error(code: "USER_NOT_FOUND", message: "User was not found", status: :not_found)
  end

  def record_not_unique(error)
    constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    return internal_error(error) unless constraint == "index_users_on_lower_email"

    render_error(code: "EMAIL_ALREADY_EXISTS", message: "Email is already in use", status: :conflict)
  end

  def bad_request
    render_error(code: "BAD_REQUEST", message: "Request body is invalid", status: :bad_request)
  end

  def internal_error(error)
    Rails.logger.error(
      event: "request_failed", request_id: request.request_id,
      error: error.class.name, backtrace: error.backtrace&.first(5)
    )
    render_error(code: "INTERNAL_ERROR", message: "Internal server error", status: :internal_server_error)
  end
end
