class RegistrationsController < ApplicationController
  skip_before_action :require_login, only: [:create]

  def create
    user = User.new(user_params)

    if user.save
      session[:user_id] = user.id
      render json: {
        logged_in: true,
        user: user.as_json(only: [:id, :email, :created_at, :updated_at])
      }, status: :created
    else
      render json: {
        logged_in: false,
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
