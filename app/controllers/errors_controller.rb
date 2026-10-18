class ErrorsController < ApplicationController
  def not_found
    render_error(code: "NOT_FOUND", message: "Route was not found", status: :not_found)
  end
end
