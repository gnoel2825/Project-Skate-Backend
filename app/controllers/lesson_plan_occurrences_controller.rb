class LessonPlanOccurrencesController < ApplicationController
  before_action :require_teacher
  before_action :no_store, only: [:by_date]

  # GET /lesson_plans_by_date?date=YYYY-MM-DD
  def by_date
    date = Date.parse(params[:date])

    rosters = member_rosters_relation.includes(
      :teachers,
      :students,
      :roster_schedules,
      :roster_meetings
    )

    weekly_blocks = rosters.flat_map(&:roster_schedules).select { |b| b.weekday == date.wday }
    meetings      = rosters.flat_map(&:roster_meetings).select { |m| m.taught_on == date }

    teacher_ids = rosters.flat_map { |r| [r.teacher_id] + r.teachers.map(&:id) }.uniq
    teacher_ids << current_user.id
    teacher_ids.uniq!

    occs = LessonPlanOccurrence
      .includes(
        :attendances,
        :roster,
        lesson_plan: [:skills, :warmup_skills, :cooldown_skills]
      )
      .joins(:lesson_plan)
      .where(taught_on: date)
      .where.not(starts_at: nil, ends_at: nil)
      .where(lesson_plans: { teacher_id: teacher_ids })
      .order(:starts_at)

    visible = occs.select do |occ|
      occ.lesson_plan.teacher_id == current_user.id ||
        overlaps_any_weekly_block_for_date?(occ, weekly_blocks, date) ||
        overlaps_any_meeting?(occ, meetings)
    end

    render json: visible.map { |occ|
      matching_rosters =
        if occ.roster.present?
          [occ.roster]
        else
          rosters.select { |roster| roster_match_for_occurrence?(occ, roster) }
        end

      {
        id: occ.id,
        taught_on: occ.taught_on,
        starts_at: occ.starts_at&.strftime("%H:%M"),
        ends_at: occ.ends_at&.strftime("%H:%M"),
        location: occ.location,
        roster_id: occ.roster_id,

        matching_rosters: matching_rosters.map { |r|
          {
            id: r.id,
            name: r.name,
            student_count: r.students.size,
            students: r.students
              .sort_by { |s| [s.last_name.to_s.downcase, s.first_name.to_s.downcase] }
              .map do |student|
                attendance_row = occ.attendances.find { |a| a.student_id == student.id }

                {
                  id: student.id,
                  first_name: student.first_name,
                  last_name: student.last_name,
                  full_name: [student.first_name, student.last_name].compact.join(" "),
                  attendance: attendance_row ? {
                    id: attendance_row.id,
                    status: attendance_row.status,
                    notes: attendance_row.notes
                  } : nil
                }
              end
          }
        },

        attendance_summary: {
          total: occ.attendances.size,
          present: occ.attendances.count { |a| a.status == "present" },
          absent: occ.attendances.count { |a| a.status == "absent" },
          late: occ.attendances.count { |a| a.status == "late" },
          excused: occ.attendances.count { |a| a.status == "excused" }
        },

        lesson_plan: {
          id: occ.lesson_plan.id,
          title: occ.lesson_plan.title,
          description: occ.lesson_plan.description,
          teacher_id: occ.lesson_plan.teacher_id,
          warmup_notes: occ.lesson_plan.warmup_notes,
          main_notes: occ.lesson_plan.main_notes,
          cooldown_notes: occ.lesson_plan.cooldown_notes,
          skills: occ.lesson_plan.skills.as_json(only: [:id, :name, :level]),
          warmup_skills: occ.lesson_plan.warmup_skills.as_json(only: [:id, :name, :level]),
          cooldown_skills: occ.lesson_plan.cooldown_skills.as_json(only: [:id, :name, :level])
        }
      }
    }
  end

  # POST /lesson_plans/:lesson_plan_id/lesson_plan_occurrences
  def create
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(lesson_plan)

    occ = lesson_plan.lesson_plan_occurrences.new(occurrence_params)
    occ.starts_at = normalize_time_param(occ.starts_at)
    occ.ends_at   = normalize_time_param(occ.ends_at)

    if occ.save
      render json: occ.as_json(only: [:id, :taught_on, :location, :roster_id]).merge(
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
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(lesson_plan)

    occ = lesson_plan.lesson_plan_occurrences.find(params[:id])

    attrs = occurrence_params.to_h
    attrs[:starts_at] = normalize_time_param(attrs[:starts_at])
    attrs[:ends_at]   = normalize_time_param(attrs[:ends_at])

    if occ.update(attrs)
      render json: occ.as_json(only: [:id, :taught_on, :location, :roster_id]).merge(
        starts_at: occ.starts_at&.strftime("%H:%M"),
        ends_at: occ.ends_at&.strftime("%H:%M")
      ), status: :ok
    else
      render json: { errors: occ.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /lesson_plans/:lesson_plan_id/lesson_plan_occurrences/:id
  def destroy
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(lesson_plan)

    occ = lesson_plan.lesson_plan_occurrences.find(params[:id])
    occ.destroy
    head :no_content
  end

  # GET /lesson_plans/:lesson_plan_id/lesson_plan_occurrences/:id/attendance
  def attendance
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    occ = lesson_plan.lesson_plan_occurrences.includes(:attendances, roster: :students).find(params[:id])

    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless can_access_occurrence?(lesson_plan, occ)

    roster = occ.roster
    students = roster ? roster.students.order(:last_name, :first_name) : []

    render json: {
      occurrence: {
        id: occ.id,
        taught_on: occ.taught_on,
        starts_at: occ.starts_at&.strftime("%H:%M"),
        ends_at: occ.ends_at&.strftime("%H:%M"),
        location: occ.location,
        roster_id: occ.roster_id
      },
      roster: roster ? {
        id: roster.id,
        name: roster.name
      } : nil,
      students: students.map { |student|
        row = occ.attendances.find { |a| a.student_id == student.id }

        {
          id: student.id,
          first_name: student.first_name,
          last_name: student.last_name,
          attendance: row ? {
            id: row.id,
            status: row.status,
            notes: row.notes
          } : nil
        }
      }
    }
  end

  # POST /lesson_plans/:lesson_plan_id/lesson_plan_occurrences/:id/save_attendance
  def save_attendance
    lesson_plan = LessonPlan.find(params[:lesson_plan_id])
    occ = lesson_plan.lesson_plan_occurrences.find(params[:id])

    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless can_access_occurrence?(lesson_plan, occ)

    rows = params[:attendance] || []

    Attendance.transaction do
      rows.each do |row|
        student_id = row[:student_id] || row["student_id"]
        status     = row[:status] || row["status"] || "present"
        notes      = row[:notes] || row["notes"] || row[:note] || row["note"]

        attendance = occ.attendances.find_or_initialize_by(student_id: student_id)
        attendance.status = status
        attendance.notes = notes
        attendance.save!
      end
    end

    render json: { ok: true }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def member_rosters_relation
    owned_ids  = Roster.where(teacher_id: current_user.id).select(:id)
    taught_ids = RosterTeacher.where(teacher_id: current_user.id).select(:roster_id)
    Roster.where(id: owned_ids).or(Roster.where(id: taught_ids))
  end

  def owns_lesson_plan?(lesson_plan)
    lesson_plan.teacher_id == current_user.id
  end

  def can_access_occurrence?(lesson_plan, occ)
    return true if owns_lesson_plan?(lesson_plan)
    return false if occ.roster.blank?

    roster_teacher_ids = [occ.roster.teacher_id] + occ.roster.teachers.pluck(:id)
    roster_teacher_ids.uniq.include?(current_user.id)
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

  def roster_match_for_occurrence?(occ, roster)
    weekly_match = roster.roster_schedules.any? do |blk|
      next false unless blk.weekday == occ.taught_on.wday
      next false if blk.starts_at.blank? || blk.ends_at.blank?
      overlaps?(
        combine_date_and_time(occ.taught_on, blk.starts_at),
        combine_date_and_time(occ.taught_on, blk.ends_at),
        combine_date_and_time(occ.taught_on, occ.starts_at),
        combine_date_and_time(occ.taught_on, occ.ends_at)
      )
    end

    meeting_match = roster.roster_meetings.any? do |m|
      next false unless m.taught_on == occ.taught_on
      next false if m.starts_at.blank? || m.ends_at.blank?
      overlaps?(
        combine_date_and_time(m.taught_on, m.starts_at),
        combine_date_and_time(m.taught_on, m.ends_at),
        combine_date_and_time(occ.taught_on, occ.starts_at),
        combine_date_and_time(occ.taught_on, occ.ends_at)
      )
    end

    weekly_match || meeting_match
  end

  def occurrence_params
    params.require(:lesson_plan_occurrence).permit(:taught_on, :starts_at, :ends_at, :location, :roster_id)
  end

  def normalize_time_param(value)
    return nil if value.blank?
    return value if value.respond_to?(:hour) && !value.is_a?(String)

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
      render json: {
        errors: [
          "This component is restricted to instructor accounts only. If you are an instructor or administrator, an admin account must manually assign that role to you in the admin panel for you to access this component."
        ]
      }, status: :unauthorized
    end
  end
end