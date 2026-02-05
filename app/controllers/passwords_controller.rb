class PasswordsController < ApplicationController
  # require_login already runs from ApplicationController, so only logged-in users can reach this

  def update
    user = current_user
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless user

    unless user.authenticate(password_params[:current_password].to_s)
      return render json: { errors: ["Current password is incorrect"] }, status: :unauthorized
    end

    if user.update(password: password_params[:password], password_confirmation: password_params[:password_confirmation])
      render json: { status: "ok" }, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
