class UsersController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]

  def show; end

  def index
    users = User.all

    if params[:role].present?
      # supports /users?role=teacher
      users = users.where(role: params[:role])
    end

    render json: users.as_json(only: [
      :id, :email, :first_name, :last_name, :role, :updated_at, :icon_100_url
    ])
  end

  def new
    @user = User.new
  end

  def create
    @user = User.create(user_params)
    if @user.valid?
      session[:user_id] = @user.id
      redirect_to @user
    else
      flash[:error] = "Error - please try to create an account again."
      redirect_to new_user_path
    end
  end

  # PATCH /profile (via routes.rb -> users#update)
  def update
    user = current_user
    return render json: { errors: [ "Not authorized" ] }, status: :unauthorized unless user

    # normalize email if present
    if params.dig(:user, :email)
      user.email = user.email.to_s.strip.downcase
    end

    if user.update(profile_params)
      safe_user = user.as_json(only: [ :id, :email, :first_name, :last_name, :created_at, :updated_at, :role ]).merge(
        icon_url: icon_url(user),
        icon_100_url: icon_100_url(user)
      )

      render json: { user: safe_user }, status: :ok
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    user = current_user
    return render json: { errors: [ "Not authorized" ] }, status: :unauthorized unless user

    user.destroy!
    reset_session

    render json: { ok: true }, status: :ok
  end

  private

  def profile_params
    params.require(:user).permit(:first_name, :last_name, :email, :icon)
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name)
  end

  def icon_url(user)
    return nil unless user.icon.attached?
    Rails.application.routes.url_helpers.rails_blob_url(
      user.icon,
      host: "localhost",
      port: 3000
    )
  end

  def icon_100_url(user)
    return nil unless user.icon.attached?

    variant = user.icon.variant(resize_to_fill: [ 100, 100 ]).processed
    Rails.application.routes.url_helpers.rails_representation_url(
      variant,
      host: "localhost",
      port: 3000
    )
  end
end
