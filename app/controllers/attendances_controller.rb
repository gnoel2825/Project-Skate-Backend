class AttendancesController < ApplicationController
  before_action :require_teacher
  before_action :set_attendance, only: [ :update, :destroy ]

  # POST /attendances
  def create
    attendance = Attendance.new(attendance_params)

    if attendance.save
      render json: attendance.as_json(
        only: [ :id, :lesson_plan_occurrence_id, :student_id, :status, :notes ]
      ), status: :created
    else
      render json: { errors: attendance.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /attendances/:id
  def update
    if @attendance.update(attendance_params)
      render json: @attendance.as_json(
        only: [ :id, :lesson_plan_occurrence_id, :student_id, :status, :notes ]
      ), status: :ok
    else
      render json: { errors: @attendance.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /attendances/:id
  def destroy
    @attendance.destroy
    head :no_content
  end

  private

  def set_attendance
    @attendance = Attendance.find(params[:id])
  end

  def attendance_params
    params.require(:attendance).permit(
      :lesson_plan_occurrence_id,
      :student_id,
      :status,
      :notes
    )
  end

  def require_teacher
    unless current_user&.teacher? || current_user&.admin?
      render json: {
        errors: [ "Not authorized" ]
      }, status: :unauthorized
    end
  end
end
