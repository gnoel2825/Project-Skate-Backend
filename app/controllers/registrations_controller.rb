class RegistrationsController < ApplicationController
  skip_before_action :require_login, only: [ :create ]

  def create
    user = User.new(user_params)

    if user.save
      user.reset_auth_token! if user.auth_token.blank?

      safe_user = user.as_json(only: [ :id, :email, :first_name, :last_name, :role ])

      render json: {
        user: safe_user,
        token: user.auth_token
      }, status: :created
    else
      render json: {
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
  params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
  end
end
