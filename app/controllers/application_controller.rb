class ApplicationController < ActionController::Base
  before_action :require_login
  helper_method :current_user
  before_action :no_store_json

  # For a separate React frontend, disabling CSRF protection is common in dev.
  # (More secure option later: use CSRF tokens properly.)
  skip_before_action :verify_authenticity_token
 

  private

  def require_login
    return if session[:user_id].present?

    render json: { error: "Not authorized" }, status: :unauthorized
  end

  def require_admin
  return if current_user&.admin?
  render json: { errors: ["Admins only"] }, status: :unauthorized
end

  def current_user
    return @current_user if defined?(@current_user)

    auth = request.headers["Authorization"].to_s
    token = auth.start_with?("Bearer ") ? auth.split(" ", 2).last : nil
    @current_user = token.present? ? User.find_by(auth_token: token) : nil
  end

    def no_store_json
    return unless request.format.json?
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers.delete("ETag")
    response.headers.delete("Last-Modified")
  end

end
