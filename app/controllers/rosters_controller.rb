class RostersController < ApplicationController
  before_action :require_teacher
  before_action :set_roster, only: [
  :show, :update, :destroy,
  :add_student, :remove_student,
  :add_teacher, :remove_teacher,
  :scheduled_lessons, :upcoming_scheduled_lessons
]


 # GET /rosters
 def index
  return render json: { error: "Not authorized" }, status: :unauthorized unless current_user&.teacher?

  rosters = Roster.accessible_by(current_user).order(created_at: :desc)
  render json: rosters, include: [ :teacher, :teachers, :students, :roster_schedules ]
end

  # GET /rosters/:id
  def show
  render json: @roster.as_json(
    only: [ :id, :name ],
    include: {
      teacher: { only: [ :id, :first_name, :last_name, :email, :icon_100_url, :updated_at ] },
      teachers: { only: [ :id, :first_name, :last_name, :email, :icon_100_url, :updated_at ] },
      students: { only: [ :id, :first_name, :last_name, :email ] },
      roster_meetings: { only: [ :id, :taught_on, :starts_at, :ends_at, :location ] }
    }
  )
end


# GET /rosters_by_date?date=YYYY-MM-DD
def by_date
  date = Date.parse(params[:date])
  weekday = date.wday

  rosters = Roster.accessible_by(current_user)
  .joins(:roster_schedules)
  .where(roster_schedules: { weekday: weekday })
  .includes(:students, :roster_schedules)
  .distinct
  .order(:name)

  render json: rosters.map { |r|
    r.as_json(only: [ :id, :name ]).merge(
      students: r.students.as_json(only: [ :id ]),
      roster_schedules: r.roster_schedules.map { |s|
        s.as_json(only: [ :id, :weekday, :location ]).merge(
          starts_at: s.starts_at&.strftime("%H:%M"),
          ends_at:   s.ends_at&.strftime("%H:%M")
        )
      }
    )
  }
end


  # POST /rosters
  def create
    roster = current_user.rosters.new(roster_params)

    if roster.save
      render json: roster.as_json(only: [ :id, :name ]), status: :created
    else
      render json: { errors: roster.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /rosters/:id
  def update
    if @roster.update(roster_params)
      render json: @roster.as_json(only: [ :id, :name ]), status: :ok
    else
      render json: { errors: @roster.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /rosters/:id
  def destroy
    @roster.destroy
    head :no_content
  end

  # POST /rosters/:roster_id/add_student/:student_id
  def add_student
  roster = Roster.find(params[:roster_id] || params[:id])

  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

  allowed = current_user&.admin? || teacher_ids.include?(current_user.id)
  return render(json: { error: "Not authorized" }, status: :unauthorized) unless allowed

  # optional but recommended: only allow adding students owned by any teacher on this roster
  student = Student.where(teacher_id: teacher_ids).find(params[:student_id])

  roster.students << student unless roster.students.exists?(student.id)

  render json: roster.as_json(
    only: [ :id, :name ],
    include: { students: { only: [ :id, :first_name, :last_name, :email ] } }
  )
end


  # DELETE /rosters/:roster_id/remove_student/:student_id
  def remove_student
  roster = @roster
  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

  allowed = current_user&.admin? || teacher_ids.include?(current_user.id)
  return render(json: { error: "Not authorized" }, status: :unauthorized) unless allowed

  student = Student.where(teacher_id: teacher_ids).find(params[:student_id])
  roster.students.destroy(student)

  render json: roster.reload.as_json(
    only: [ :id, :name ],
    include: { students: { only: [ :id, :first_name, :last_name, :email ] } }
  )
end


# GET /rosters/:id/scheduled_lessons
# app/controllers/rosters_controller.rb (or wherever scheduled_lessons lives)
def scheduled_lessons
  roster = @roster

  meetings = roster.roster_meetings.order(:taught_on, :starts_at)

  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

  matches = meetings.map do |m|
    m_start = combine_date_and_time(m.taught_on, m.starts_at)
    m_end   = combine_date_and_time(m.taught_on, m.ends_at)

    occs = LessonPlanOccurrence
      .joins(:lesson_plan)
      .where(lesson_plans: { teacher_id: teacher_ids })
      .where(taught_on: m.taught_on)
      .includes(:lesson_plan)
      .select do |occ|
        o_start = combine_date_and_time(occ.taught_on, occ.starts_at)
        o_end   = combine_date_and_time(occ.taught_on, occ.ends_at)
        overlaps?(m_start, m_end, o_start, o_end)
      end

    {
      meeting: {
        id: m.id,
        taught_on: m.taught_on,
        starts_at: time_hhmm(m.starts_at),
        ends_at: time_hhmm(m.ends_at),
        location: m.location
      },
      occurrences: occs.map { |occ|
        {
          id: occ.id,
          taught_on: occ.taught_on,
          starts_at: time_hhmm(occ.starts_at),
          ends_at: time_hhmm(occ.ends_at),
          location: occ.location,
          lesson_plan: { id: occ.lesson_plan.id, title: occ.lesson_plan.title }
        }
      }
    }
  end

  render json: { matches: matches }
end


  # GET /rosters/:id/upcoming_scheduled_lessons?weeks=4
  def upcoming_scheduled_lessons
    weeks = params[:weeks].to_i
    weeks = 4 if weeks <= 0
    weeks = [ [ weeks, 2 ].max, 8 ].min

    schedules = @roster.roster_schedules

    from_date = Date.current
    to_date   = from_date + weeks.weeks

    instances = build_instances(schedules, from_date, to_date)
    dates = instances.map { |i| i[:taught_on] }.uniq

    teacher_ids = ([ @roster.teacher_id ] + @roster.teachers.pluck(:id)).uniq

occs = LessonPlanOccurrence
  .includes(lesson_plan: [ :skills ])
  .joins(:lesson_plan)
  .where(taught_on: dates)
  .where(lesson_plans: { teacher_id: teacher_ids })  # ✅ was current_user.id
  .order(:taught_on, :starts_at)


    matches = instances.map do |inst|
      overlapping = occs.select do |o|
        o.taught_on == inst[:taught_on] &&
          o.starts_at.present? && o.ends_at.present? &&
          overlap?(inst[:starts_at], inst[:ends_at], o.starts_at, o.ends_at)
      end

      {
        instance: inst,
        occurrences: overlapping.as_json(
          only: [ :id, :taught_on, :starts_at, :ends_at, :location ],
          include: {
            lesson_plan: {
              only: [ :id, :title, :description, :teacher_id ],
              include: { skills: { only: [ :id, :name, :level ] } }
            }
          }
        )
      }
    end

    render json: { weeks: weeks, from: from_date, to: to_date, matches: matches }
  end

 def lesson_plans_in_week
  roster = Roster.accessible_by(current_user).includes(:roster_schedules).find(params[:id])


  week_start = Date.parse(params[:week_start])
  week_end   = week_start + 6.days
  weekly_blocks = roster.roster_schedules.to_a

  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

occs = LessonPlanOccurrence
  .includes(lesson_plan: :skills)
  .joins(:lesson_plan)
  .where(taught_on: week_start..week_end)
  .where(lesson_plans: { teacher_id: teacher_ids })  # ✅ was current_user.id
  .order(:taught_on, :starts_at)


  matches = occs.select { |occ| overlaps_any_weekly_block?(occ, weekly_blocks) }

  render json: matches.map { |occ|
    occ.as_json(only: [ :id, :taught_on, :location ]).merge(
      starts_at: occ.starts_at&.strftime("%H:%M"),
      ends_at:   occ.ends_at&.strftime("%H:%M"),
      lesson_plan: occ.lesson_plan.as_json(
        only: [ :id, :title, :description ],
        include: { skills: { only: [ :id, :name, :level ] } }
      )
    )
  }
end

# GET /rosters/:id/lesson_plans_matching_schedule
# Optional query params:
#   scope=all|future   (default future)
#   limit=200          (optional safety cap)
def lesson_plans_matching_schedule
  roster = Roster.accessible_by(current_user)
    .includes(:roster_schedules, :roster_meetings, :teachers)
    .find(params[:id])

  weekly_blocks = roster.roster_schedules.to_a
  meetings      = roster.roster_meetings.to_a

  scope = params[:scope].to_s
  only_future = (scope != "all")

  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

  occs = LessonPlanOccurrence
    .includes(lesson_plan: :skills)
    .joins(:lesson_plan)
    .where(lesson_plans: { teacher_id: teacher_ids })
    .order(:taught_on, :starts_at)

  occs = occs.where("taught_on >= ?", Date.current) if only_future

  weekly_matches = occs.select { |occ| overlaps_any_weekly_block?(occ, weekly_blocks) }

  meeting_matches = occs.select do |occ|
    next false if occ.taught_on.blank? || occ.starts_at.blank? || occ.ends_at.blank?

    meetings.any? do |m|
      next false unless m.taught_on == occ.taught_on
      next false if m.starts_at.blank? || m.ends_at.blank?

      m_start = combine_date_and_time(m.taught_on, m.starts_at)
      m_end   = combine_date_and_time(m.taught_on, m.ends_at)
      o_start = combine_date_and_time(occ.taught_on, occ.starts_at)
      o_end   = combine_date_and_time(occ.taught_on, occ.ends_at)

      overlaps?(m_start, m_end, o_start, o_end)
    end
  end

  by_id = {}
  (weekly_matches + meeting_matches).each { |o| by_id[o.id] = o }
  matches = by_id.values

  if params[:limit].present?
    matches = matches.first(params[:limit].to_i)
  end

  render json: matches.as_json(
    only: [ :id, :taught_on, :starts_at, :ends_at, :location ],
    include: {
      lesson_plan: {
        only: [ :id, :title, :description, :teacher_id ],
        include: { skills: { only: [ :id, :name, :level ] } }
      }
    }
  )
end

# app/controllers/rosters_controller.rb
def available_students
  roster = Roster.accessible_by(current_user).find(params[:id])

  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

  students =
    Student
      .where(teacher_id: teacher_ids)
      .where.not(id: roster.students.select(:id))
      .order(:last_name, :first_name)

  render json: students.as_json(only: [ :id, :first_name, :last_name, :email ])
end


def add_teacher
  teacher = User.find(params[:teacher_id])
  return render json: { errors: [ "User is not a teacher" ] }, status: :unprocessable_entity unless teacher.teacher?

  # Optional rule: only the roster owner can add/remove teachers
  # return render json: { errors: ["Not authorized"] }, status: :unauthorized unless @roster.teacher_id == current_user.id

  RosterTeacher.find_or_create_by!(roster: @roster, teacher: teacher)

  render json: @roster.reload.as_json(
    only: [ :id, :name ],
    include: {
      teacher: { only: [ :id, :first_name, :last_name, :email, :icon_100_url, :updated_at ] },
      teachers: { only: [ :id, :first_name, :last_name, :email, :icon_100_url, :updated_at ] }
    }
  )
end

def remove_teacher
  roster = Roster.find(params[:id])

  # Build the effective teacher set: owner + additional teachers
  teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq

  if teacher_ids.length <= 1
    return render json: { errors: [ "A roster must have at least one teacher." ] }, status: :unprocessable_entity
  end

  if roster.teacher_id.to_i == params[:teacher_id].to_i
    return render json: { errors: [ "Can't remove roster owner" ] }, status: :unprocessable_entity
  end

  RosterTeacher.where(roster_id: roster.id, teacher_id: params[:teacher_id]).destroy_all

  roster.reload
  render json: roster.as_json(
  only: [ :id, :name ],
  include: {
    teacher: { only: [ :id, :first_name, :last_name, :email, :icon_100_url, :updated_at ] },
    teachers: { only: [ :id, :first_name, :last_name, :email, :icon_100_url, :updated_at ] }
  }
)
end



private

# Returns a Time in your Rails Time.zone, anchored to `date`,
# using ONLY the time-of-day from `time_value`.
def combine_date_and_time(date, time_value)
  return nil if date.blank? || time_value.blank?

  t =
    case time_value
    when String
      # supports "HH:MM" or "HH:MM:SS"
      Time.zone.parse("2000-01-01 #{time_value}")
    else
      time_value.in_time_zone
    end

  Time.zone.local(date.year, date.month, date.day, t.hour, t.min, t.sec)
end

def overlaps?(a_start, a_end, b_start, b_end)
  return false if a_start.blank? || a_end.blank? || b_start.blank? || b_end.blank?
  a_start < b_end && b_start < a_end
end

# Always serialize times back as "HH:MM" (prevents timezone bugs in React)
def time_hhmm(value)
  return nil if value.blank?
  t = value.is_a?(String) ? Time.zone.parse("2000-01-01 #{value}") : value.in_time_zone
  t.strftime("%H:%M")
end



# --- helpers ---

# Build real datetime for occurrence start/end using taught_on + (time-of-day from starts_at/ends_at)
def occ_dt(occ, field)
  date = occ.taught_on
  t = occ.public_send(field)
  return nil if date.blank? || t.blank?

  Time.zone.local(date.year, date.month, date.day, t.hour, t.min, t.sec)
end

# True if occ overlaps ANY weekly block for its day-of-week
# Pull hour/min/sec from either:
# - a Time/DateTime (often anchored to 2000-01-01)
# - or a string like "09:00"
def hms(value)
  return nil if value.blank?

  if value.is_a?(String)
    # "HH:MM" or "HH:MM:SS"
    parts = value.split(":").map(&:to_i)
    hh = parts[0]
    mm = parts[1] || 0
    ss = parts[2] || 0
    return [ hh, mm, ss ] if hh
  end

  # Time / DateTime / ActiveSupport::TimeWithZone
  t = value.respond_to?(:in_time_zone) ? value.in_time_zone : value
  [ t.hour, t.min, t.sec ]
end

def dt_on(date, time_value)
  parts = hms(time_value)
  return nil if date.blank? || parts.nil?
  hh, mm, ss = parts
  Time.zone.local(date.year, date.month, date.day, hh, mm, ss)
end

def overlaps_any_weekly_block?(occ, weekly_blocks)
  return false if occ.taught_on.blank?

  # If occurrence has no times, skip
  return false if occ.starts_at.blank? || occ.ends_at.blank?

  dow = occ.taught_on.wday

  occ_start = dt_on(occ.taught_on, occ.starts_at)
  occ_end   = dt_on(occ.taught_on, occ.ends_at)
  return false if occ_start.blank? || occ_end.blank?

  weekly_blocks.any? do |b|
    next false unless b.weekday == dow

    block_start = dt_on(occ.taught_on, b.starts_at)
    block_end   = dt_on(occ.taught_on, b.ends_at)
    next false if block_start.blank? || block_end.blank?

    overlap?(block_start, block_end, occ_start, occ_end)
  end
end

def overlap?(a_start, a_end, b_start, b_end)
  a_start < b_end && a_end > b_start
end




  def set_roster
  @roster = Roster.accessible_by(current_user)
    .includes(:students, :roster_meetings, :roster_schedules, :teachers, :teacher)
    .find(params[:id] || params[:roster_id])
end

  def roster_params
    params.require(:roster).permit(:name)
  end

  def require_teacher
  return if current_user&.teacher? || current_user&.admin?
  render json: { errors: [ "Instructor accounts only." ] }, status: :unauthorized
end


  def build_instances(schedules, from_date, to_date)
    instances = []

    (from_date..to_date).each do |d|
      schedules.each do |s|
        next unless d.wday == s.weekday

        instances << {
          schedule_id: s.id,
          taught_on: d,
          starts_at: combine_date_time(d, s.starts_at),
          ends_at: combine_date_time(d, s.ends_at)
        }
      end
    end

    instances.sort_by { |i| [ i[:taught_on], i[:starts_at] ] }
  end

  def combine_date_time(date, time_value)
  dt_on(date, time_value)
end
end
