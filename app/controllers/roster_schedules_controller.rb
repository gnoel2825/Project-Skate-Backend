class RosterSchedulesController < ApplicationController
  before_action :require_teacher
  before_action :set_roster

  # GET /rosters/:roster_id/roster_schedules
  def index
    schedules = @roster.roster_schedules.order(:weekday, :starts_at)

    render json: schedules.map { |s| schedule_json(s) }
  end

  # POST /rosters/:roster_id/roster_schedules
  def create
    sched = @roster.roster_schedules.new(schedule_params)

    if sched.save
      render json: schedule_json(sched), status: :created
    else
      render json: { errors: sched.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /rosters/:roster_id/roster_schedules/:id
  def update
    sched = @roster.roster_schedules.find(params[:id])

    if sched.update(schedule_params)
      render json: schedule_json(sched), status: :ok
    else
      render json: { errors: sched.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /rosters/:roster_id/roster_schedules/:id
  def destroy
    sched = @roster.roster_schedules.find(params[:id])
    sched.destroy
    head :no_content
  end

  private

  def set_roster
    @roster = Roster.accessible_by(current_user).find(params[:roster_id])

  end

  # Accepts "HH:MM" from React <input type="time" />
  # Rails will cast it into your column type.
  def schedule_params
    params.require(:roster_schedule).permit(:weekday, :starts_at, :ends_at, :location)
  end

  # ALWAYS return time-only strings, never a "2000-01-01T...Z"
  def schedule_json(s)
    s.as_json(only: [:id, :weekday, :location]).merge(
      starts_at: s.starts_at&.strftime("%H:%M"),
      ends_at:   s.ends_at&.strftime("%H:%M")
    )
  end

  def require_teacher
    return if current_user&.teacher?
    render json: { errors: ["Teachers only"] }, status: :unauthorized
  end
end
