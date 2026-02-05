class ApplicationController < ActionController::Base
  before_action :require_login
  helper_method :current_user
  before_action :no_store_json

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

    auth_header = request.headers["Authorization"].to_s

    if auth_header.start_with?("Bearer ")
      token = auth_header.split(" ", 2).last
      @current_user = User.find_by(auth_token: token)
    else
      @current_user = nil
    end

    @current_user
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
