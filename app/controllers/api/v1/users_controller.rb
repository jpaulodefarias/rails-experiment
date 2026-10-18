module Api
  module V1
    class UsersController < ApplicationController
      wrap_parameters false

      def index
        render json: User.order(:id).map { |user| user_json(user) }
      end

      def show
        render json: user_json(User.find(params[:id]))
      end

      def create
        user = User.new(user_params)
        if user.save
          render json: user_json(user), status: :created, location: api_v1_user_path(user)
        else
          render_validation_errors(user)
        end
      end

      def update
        user = User.find(params[:id])
        if user.update(user_params)
          render json: user_json(user)
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

      def user_json(user)
        user.as_json(only: %i[id name email created_at updated_at])
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
