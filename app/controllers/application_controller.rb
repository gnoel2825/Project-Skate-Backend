class ApplicationController < ActionController::Base
  before_action :require_login
  helper_method :current_user

  # For a separate React frontend, disabling CSRF protection is common in dev.
  # (More secure option later: use CSRF tokens properly.)
  skip_before_action :verify_authenticity_token

  private

  def require_login
    return if session[:user_id].present?

    render json: { error: "Not authorized" }, status: :unauthorized
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
