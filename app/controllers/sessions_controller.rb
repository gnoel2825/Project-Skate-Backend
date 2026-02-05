# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  include Rails.application.routes.url_helpers

  skip_before_action :require_login, only: [:create, :logged_in, :destroy]

  def create
  user = User.find_by(email: params[:user][:email])

  if user&.authenticate(params[:user][:password])
    session[:user_id] = user.id
    render json: {
      logged_in: true,
      user: user.as_json(only: [:id, :email, :first_name, :last_name, :role])
    }, status: :created
  else
    render json: { logged_in: false, errors: ["Invalid email or password"] }, status: :unauthorized
  end
end

def logged_in
  if current_user
    render json: {
      logged_in: true,
      user: current_user.as_json(only: [:id, :email, :first_name, :last_name, :role])
    }
  else
    render json: { logged_in: false }
  end
end

  def destroy
    reset_session
    render json: { ok: true }
  end

  private

  # Ensure url_for generates absolute URLs
  def default_url_options
    { host: "localhost", port: 3000, protocol: "http" }
  end

  def safe_user_with_icon(user)
    base = user.as_json(only: [:id, :email, :first_name, :last_name, :created_at, :updated_at])

    base.merge(
      icon_url: icon_url(user),
      icon_100_url: icon_100_url(user)
    )
  end

  def icon_url(user)
    return nil unless user&.icon&.attached?
    url_for(user.icon)
  end

  def icon_100_url(user)
    return nil unless user&.icon&.attached?
    variant = user.icon.variant(resize_to_fill: [100, 100]).processed
    url_for(variant)
  end
end
