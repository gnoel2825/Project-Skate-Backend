class RosterMeetingsController < ApplicationController
  before_action :require_teacher
  before_action :no_store, only: [ :by_date ]

  def create
    roster = current_user.rosters.find(params[:roster_id])
    meeting = roster.roster_meetings.new(meeting_params)

    if meeting.save
      render json: meeting, status: :created
    else
      render json: { errors: meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    roster = current_user.rosters.find(params[:roster_id])
    meeting = roster.roster_meetings.find(params[:id])

    if meeting.update(meeting_params)
      render json: meeting, status: :ok
    else
      render json: { errors: meeting.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    roster = current_user.rosters.find(params[:roster_id])
    meeting = roster.roster_meetings.find(params[:id])
    meeting.destroy
    head :no_content
  end

 def by_date
  date = Date.parse(params[:date])

  roster_ids = Roster.accessible_by(current_user).select(:id)

  meetings = RosterMeeting
    .includes(roster: :students)
    .where(taught_on: date, roster_id: roster_ids)
    .order(:starts_at)

  render json: meetings.as_json(
    only: [ :id, :taught_on, :starts_at, :ends_at, :location, :notes ],
    include: {
      roster: {
        only: [ :id, :name ],
        include: {
          students: { only: [ :id, :first_name, :last_name ] }
        }
      }
    }
  )
end


  private

    def no_store
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers.delete("ETag")
    response.headers.delete("Last-Modified")
  end

  def meeting_params
    params.require(:roster_meeting).permit(:taught_on, :starts_at, :ends_at, :location, :students)
  end

  def require_teacher
    return if current_user&.teacher? || current_user&.admin?
    render json: { errors: [ "This component is restricted to instructor accounts only. If you are an instructor or administrator, an admin account must manually assign that role to you in the admin panel for you to access this component." ] }, status: :unauthorized
  end
end
