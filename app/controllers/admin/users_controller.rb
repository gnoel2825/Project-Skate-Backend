module Admin
  class UsersController < ApplicationController
    before_action :require_admin
    before_action :set_user, only: [:update, :destroy]

    # GET /admin/users
    def index
      users = User.order(created_at: :desc)
      render json: users.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at])
    end

    # POST /admin/users
    def create
      user = User.new(admin_user_create_params)
      user.role = params[:user][:role] if params[:user][:role].present?

      if user.save
        render json: user.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at]), status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH /admin/users/:id
    # (role changes, name/email fixes, password reset if provided)
    def update
      # Optional safety: prevent admin from removing their own admin role
      if @user.id == current_user.id && params.dig(:user, :role).present? && params.dig(:user, :role) != "admin"
        return render json: { errors: ["You can't remove your own admin role."] }, status: :unprocessable_entity
      end

      if @user.update(admin_user_update_params)
         @user.role = params[:user][:role] if params[:user][:role].present?
        render json: @user.as_json(only: [:id, :email, :first_name, :last_name, :role, :created_at]), status: :ok
      else
        render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /admin/users/:id
    def destroy
      if @user.id == current_user.id
        return render json: { errors: ["You can't delete your own account from the admin panel."] }, status: :unprocessable_entity
      end

      @user.destroy
      head :no_content
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def admin_user_create_params
      params.require(:user).permit(:email, :first_name, :last_name, :password, :password_confirmation)
    end

    def admin_user_update_params
      # allow password reset if admin wants to set a new password
      params.require(:user).permit(:email, :first_name, :last_name, :password, :password_confirmation)
    end
  end
end
