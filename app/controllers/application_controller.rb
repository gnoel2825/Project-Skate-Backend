class ApplicationController < ActionController::Base
  before_action :require_login
  helper_method :current_user
  before_action :no_store_json

  # For a separate React frontend, disabling CSRF protection is common in dev.
  # (More secure option later: use CSRF tokens properly.)
  skip_before_action :verify_authenticity_token
 

  private

   def require_login
    return if current_user.present?
    render json: { error: "Not authorized" }, status: :unauthorized
  end

  def require_admin
  return if current_user&.admin?
  render json: { errors: ["Admins only"] }, status: :unauthorized
end

   def current_user
    return @current_user if defined?(@current_user)

    # 1) Bearer token auth
    auth_header = request.headers["Authorization"].to_s
    if auth_header.start_with?("Bearer ")
      token = auth_header.split(" ", 2).last
      @current_user = User.find_by(auth_token: token)
      return @current_user
    end

    # 2) Session fallback
    if session[:user_id].present?
      @current_user = User.find_by(id: session[:user_id])
      return @current_user
    end

    @current_user = nil
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
