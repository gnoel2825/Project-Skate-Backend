class LessonPlanOccurrencesController < ApplicationController
  before_action :require_teacher
  before_action :no_store, only: [:by_date]

  # GET /lesson_plans_by_date?date=YYYY-MM-DD
 # app/controllers/lesson_plan_occurrences_controller.rb
def by_date
  date = Date.parse(params[:date])

  rosters = member_rosters_relation.includes(:roster_schedules, :roster_meetings, :teachers)

  # only blocks that could apply on this weekday
  weekly_blocks = rosters.flat_map(&:roster_schedules).select { |b| b.weekday == date.wday }
  meetings      = rosters.flat_map(&:roster_meetings).select { |m| m.taught_on == date }

  # limit the initial SQL pull to teachers in those rosters (+ me) for performance
  teacher_ids = rosters.flat_map { |r| [r.teacher_id] + r.teachers.map(&:id) }.uniq
  teacher_ids << current_user.id
  teacher_ids.uniq!

  occs = LessonPlanOccurrence
           .includes(lesson_plan: [:skills])
           .joins(:lesson_plan)
           .where(taught_on: date)
           .where.not(starts_at: nil, ends_at: nil)
           .where(lesson_plans: { teacher_id: teacher_ids })
           .order(:starts_at)

  visible = occs.select do |occ|
    # always show my own
    occ.lesson_plan.teacher_id == current_user.id ||
      overlaps_any_weekly_block_for_date?(occ, weekly_blocks, date) ||
      overlaps_any_meeting?(occ, meetings)
  end

  render json: visible.map { |occ|
    occ.as_json(only: [:id, :taught_on, :location]).merge(
      starts_at: occ.starts_at&.strftime("%H:%M"),
      ends_at: occ.ends_at&.strftime("%H:%M"),
      lesson_plan: occ.lesson_plan.as_json(
        only: [:id, :title, :description, :teacher_id],
        include: { skills: { only: [:id, :name, :level] } }
      )
    )
  }
end


  # POST /lesson_plans/:lesson_plan_id/lesson_plan_occurrences
  def create
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    return render json: { errors: ["Not authorized"] }, status: :unauthorized if lesson_plan.teacher_id != current_user.id

    occ = lesson_plan.lesson_plan_occurrences.new(occurrence_params)

    # If times come in as "HH:MM", normalize to anchored datetime
    occ.starts_at = normalize_time_param(occ.starts_at)
    occ.ends_at   = normalize_time_param(occ.ends_at)

    if occ.save
      render json: occ.as_json(only: [:id, :taught_on, :location]).merge(
  starts_at: occ.starts_at&.strftime("%H:%M"),
  ends_at: occ.ends_at&.strftime("%H:%M")
), status: :created
    else
      render json: { errors: occ.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /lesson_plans/:lesson_plan_id/lesson_plan_occurrences/:id
  def update
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    return render json: { errors: ["Not authorized"] }, status: :unauthorized if lesson_plan.teacher_id != current_user.id

    occ = lesson_plan.lesson_plan_occurrences.find(params[:id])

    attrs = occurrence_params.to_h
    attrs[:starts_at] = normalize_time_param(attrs[:starts_at])
    attrs[:ends_at]   = normalize_time_param(attrs[:ends_at])

    if occ.update(attrs)
      render json: occ, status: :ok
    else
      render json: { errors: occ.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /lesson_plans/:lesson_plan_id/lesson_plan_occurrences/:id
  def destroy
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    return render json: { errors: ["Not authorized"] }, status: :unauthorized if lesson_plan.teacher_id != current_user.id

    occ = lesson_plan.lesson_plan_occurrences.find(params[:id])
    occ.destroy
    head :no_content
  end

  private

def member_rosters_relation
  owned_ids  = Roster.where(teacher_id: current_user.id).select(:id)
  taught_ids = RosterTeacher.where(teacher_id: current_user.id).select(:roster_id)
  Roster.where(id: owned_ids).or(Roster.where(id: taught_ids))
end

def overlaps_any_weekly_block_for_date?(occ, weekly_blocks, date)
  o_start = combine_date_and_time(date, occ.starts_at)
  o_end   = combine_date_and_time(date, occ.ends_at)
  return false if o_start.blank? || o_end.blank?

  weekly_blocks.any? do |blk|
    b_start = combine_date_and_time(date, blk.starts_at)
    b_end   = combine_date_and_time(date, blk.ends_at)
    overlaps?(b_start, b_end, o_start, o_end)
  end
end

def overlaps_any_meeting?(occ, meetings)
  o_start = combine_date_and_time(occ.taught_on, occ.starts_at)
  o_end   = combine_date_and_time(occ.taught_on, occ.ends_at)
  return false if o_start.blank? || o_end.blank?

  meetings.any? do |m|
    m_start = combine_date_and_time(m.taught_on, m.starts_at)
    m_end   = combine_date_and_time(m.taught_on, m.ends_at)
    overlaps?(m_start, m_end, o_start, o_end)
  end
end

def combine_date_and_time(date, time)
  return nil if date.blank? || time.blank?
  Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
end

def overlaps?(a_start, a_end, b_start, b_end)
  return false if a_start.blank? || a_end.blank? || b_start.blank? || b_end.blank?
  a_start < b_end && b_start < a_end
end


  def occurrence_params
    params.require(:lesson_plan_occurrence).permit(:taught_on, :starts_at, :ends_at, :location)
  end

  def normalize_time_param(value)
    return nil if value.blank?

    # If it’s already a Time/DateTime, keep it
    return value if value.respond_to?(:hour) && !value.is_a?(String)

    # If it's "HH:MM" or "HH:MM:SS"
    if value.is_a?(String) && value.match?(/^\d{2}:\d{2}(:\d{2})?$/)
      hh, mm, ss = value.split(":").map(&:to_i)
      return Time.zone.local(2000, 1, 1, hh, mm, ss || 0)
    end

    value
  end

    def no_store
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers.delete("ETag")
    response.headers.delete("Last-Modified")
  end

  def require_teacher
    unless current_user&.teacher?
      render json: { errors: ["This component is restricted to instructor accounts only. If you are an instructor or administrator, an admin account must manually assign that role to you in the admin panel for you to access this component."] }, status: :unauthorized
    end
  end
end
