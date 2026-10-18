module Api
  module V1
    class UsersController < ApplicationController
      wrap_parameters false
      DEFAULT_PAGE_SIZE = 50
      MAX_PAGE_SIZE = 100

      def index
        limit = pagination_param(:limit, default: DEFAULT_PAGE_SIZE, minimum: 1, maximum: MAX_PAGE_SIZE)
        after_id = pagination_param(:after_id, default: 0, minimum: 0, maximum: 9_223_372_036_854_775_807)
        render json: User.where("id > ?", after_id).order(:id).limit(limit).map(&:public_attributes)
      end

      def show
        render json: User.find(params[:id]).public_attributes
      end

      def create
        user = User.new(user_params)
        if user.save
          render json: user.public_attributes, status: :created, location: api_v1_user_path(user)
        else
          render_validation_errors(user)
        end
      end

      def update
        user = User.find(params[:id])
        if user.update(user_params)
          render json: user.public_attributes
        else
          render_validation_errors(user)
        end
      end

      def destroy
        User.find(params[:id]).destroy!
        head :no_content
      end

      def destroy_all
        User.transaction { User.find_each(&:destroy!) }
        head :no_content
      end

      private

      def user_params
        params.require(:user).permit(:name, :email)
      end

      def pagination_param(name, default:, minimum:, maximum:)
        value = params[name]
        return default if value.nil?

        raise ActionController::BadRequest unless value.is_a?(String) && value.match?(/\A\d+\z/)

        number = value.to_i
        raise ActionController::BadRequest unless number.between?(minimum, maximum)

        number
      end

      def render_validation_errors(user)
        field_errors = user.errors.group_by_attribute.transform_keys(&:to_s).transform_values do |errors|
          errors.map(&:message)
        end
        render_error(
          code: "VALIDATION_FAILED",
          message: "User is invalid",
          status: :unprocessable_entity,
          field_errors: field_errors
        )
      end
    end
  end
end
