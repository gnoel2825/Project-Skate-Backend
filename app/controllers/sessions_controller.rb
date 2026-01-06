class SessionsController < ApplicationController
  include CurrentUserConcern

  # If you have a require_login in ApplicationController, allow these:
  skip_before_action :require_login, only: [:create, :logged_in]

  # POST /sessions
  def create
  email = session_params[:email].to_s.strip.downcase
  password = session_params[:password].to_s

  Rails.logger.info("LOGIN DEBUG email=#{email.inspect} password_len=#{password.length}")
  user = User.find_by(email: email)
  Rails.logger.info("LOGIN DEBUG user_found=#{user.present?} user_id=#{user&.id}")
  Rails.logger.info("LOGIN DEBUG digest_present=#{user&.password_digest.present?}")
  Rails.logger.info("LOGIN DEBUG auth_result=#{user&.authenticate(password).present?}")

  if user&.authenticate(password)
    session[:user_id] = user.id
    render json: { logged_in: true, user: user }, status: :ok
  else
    render json: { logged_in: false, errors: ["Invalid email or password"] }, status: :unauthorized
  end
end


  # GET /logged_in
  def logged_in
    if @current_user
      render json: { logged_in: true, user: @current_user }, status: :ok
    else
      render json: { logged_in: false }, status: :ok
    end
  end

  # DELETE /logout  (or DELETE /sessions)
  def destroy
    reset_session
    render json: { logged_out: true }, status: :ok
  end

  private

  # Supports BOTH:
  # { "user": { "email": "...", "password": "..." } }
  # and { "email": "...", "password": "..." }
  def session_params
    if params[:user].present?
      params.require(:user).permit(:email, :password)
    else
      params.permit(:email, :password)
    end
  end
end


