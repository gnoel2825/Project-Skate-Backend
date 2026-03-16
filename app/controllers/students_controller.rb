class StudentsController < ApplicationController
  before_action :require_teacher

  def index
  return render json: { error: "Not authorized" }, status: :unauthorized unless current_user&.teacher?

  if params[:scope] == "mine"
    roster_ids = Roster.accessible_by(current_user).select(:id)

    roster_student_ids =
      Student.joins(:rosters)
             .where(rosters: { id: roster_ids })
             .select(:id)

    students =
      Student.where(teacher_id: current_user.id)
             .or(Student.where(id: roster_student_ids))
             .distinct
             .order(:last_name, :first_name)

    return render json: students
  end

  # keep your “All Students” behavior (whatever you want it to be)
  render json: Student.order(:last_name, :first_name)
end

  def owned
  students = current_user.owned_students.order(:last_name, :first_name)
  render json: students
end

def from_rosters
    rosters = Roster.accessible_by(current_user)

    students =
      Student
        .joins(:rosters)
        .where(rosters: { id: rosters.select(:id) })
        .distinct
        .order(:last_name, :first_name)

    render json: students.as_json(only: [ :id, :first_name, :last_name, :email, :birthday ])
  end

  def all
    students = Student.order(:last_name, :first_name)
    render json: students.as_json(only: [ :id, :first_name, :last_name, :email, :birthday ])
  end


  def show
  student =
    current_user.students
      .includes(rosters: [ :teachers, :roster_schedules, :roster_meetings ])
      .find(params[:id])

  render_student(student)
end

  def create
    student = current_user.students.new(student_params)
    if student.save
      render_student(student, status: :created)
    else
      render json: { errors: student.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    student = current_user.students
      .includes(:rosters)
      .find(params[:id])

    if student.update(student_params)
      student.reload # ensures rosters association is fresh if anything changed elsewhere
      render_student(student)
    else
      render json: { errors: student.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    student = current_user.students.find(params[:id])
    student.destroy
    head :no_content
  end

  private

  def render_student(student, status: :ok)
  render json: student.as_json(
    only: [ :id, :first_name, :last_name, :email, :birthday, :notes ],
    include: {
      rosters: {
        only: [ :id, :name ],
        include: {
          teachers: { only: [ :id, :first_name, :last_name, :email ] },

          # If you store recurring weekly times here:
          roster_schedules: {
            only: [ :id, :day_of_week, :starts_at, :ends_at, :location ]
          },

          # If you store specific dated meetings here:
          roster_meetings: {
            only: [ :id, :meeting_date, :starts_at, :ends_at, :location ]
          }
        }
      }
    }
  ), status: status
end


  def student_params
    params.require(:student).permit(:first_name, :last_name, :email, :birthday, :notes)
  end

  def require_teacher
    unless current_user&.teacher?
      render json: { errors: [ "This component is restricted to instructor accounts only. If you are an instructor or administrator, an admin account must manually assign that role to you in the admin panel for you to access this component." ] }, status: :unauthorized
    end
  end
end
