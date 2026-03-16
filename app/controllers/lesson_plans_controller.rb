# app/controllers/lesson_plans_controller.rb
class LessonPlansController < ApplicationController
  before_action :require_teacher
  before_action :set_lesson_plan, only: [ :show, :update, :destroy, :duplicate, :add_skills, :remove_skill ]
  before_action :no_store, only: [ :index ]

  # POST /lesson_plans
  def create
    lesson_plan = current_user.lesson_plans.new(lesson_plan_params)

    if lesson_plan.save
      render json: serialized_lesson_plan(lesson_plan), status: :created
    else
      render json: { errors: lesson_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /lesson_plans
  def index
    if params[:roster_id].present?
      roster = member_rosters_relation
        .includes(:roster_schedules, :roster_meetings, :teachers)
        .find(params[:roster_id])

      teacher_ids = ([ roster.teacher_id ] + roster.teachers.pluck(:id)).uniq
      weekly_blocks = roster.roster_schedules.to_a
      meetings = roster.roster_meetings.to_a

      occs = LessonPlanOccurrence
        .includes(lesson_plan: [ :skills, :warmup_skills, :cooldown_skills ])
        .joins(:lesson_plan)
        .where(lesson_plans: { teacher_id: teacher_ids })
        .order(:taught_on, :starts_at)

      weekly_matches = occs.select { |occ| overlaps_any_weekly_block?(occ, weekly_blocks) }

      meeting_matches = occs.select do |occ|
        next false if occ.taught_on.blank? || occ.starts_at.blank? || occ.ends_at.blank?

        meetings.any? do |m|
          next false unless m.taught_on == occ.taught_on

          m_start = combine_date_and_time(m.taught_on, m.starts_at)
          m_end   = combine_date_and_time(m.taught_on, m.ends_at)
          o_start = combine_date_and_time(occ.taught_on, occ.starts_at)
          o_end   = combine_date_and_time(occ.taught_on, occ.ends_at)

          overlaps?(m_start, m_end, o_start, o_end)
        end
      end

      by_id = {}
      (weekly_matches + meeting_matches).each { |o| by_id[o.id] = o }

      render json: by_id.values.map { |occ|
        {
          id: occ.id,
          taught_on: occ.taught_on,
          starts_at: occ.starts_at&.strftime("%H:%M"),
          ends_at: occ.ends_at&.strftime("%H:%M"),
          location: occ.location,
          lesson_plan: {
            id: occ.lesson_plan.id,
            title: occ.lesson_plan.title,
            description: occ.lesson_plan.description,
            teacher_id: occ.lesson_plan.teacher_id,
            skills: occ.lesson_plan.skills.as_json(only: [ :id, :name, :level ]),
            warmup_skills: occ.lesson_plan.warmup_skills.as_json(only: [ :id, :name, :level ]),
            cooldown_skills: occ.lesson_plan.cooldown_skills.as_json(only: [ :id, :name, :level ])
          }
        }
      }
      return
    end

    shared_ids = shared_lesson_plan_ids_for_member_rosters

    lesson_plans = LessonPlan
      .where(teacher_id: current_user.id)
      .or(LessonPlan.where(id: shared_ids))
      .distinct
      .includes(:skills, :warmup_skills, :cooldown_skills, :lesson_plan_occurrences)
      .order(created_at: :desc)

    now = Time.current

    render json: lesson_plans.map { |lp|
      next_dt = lp.lesson_plan_occurrences
        .map { |occ| occurrence_start_datetime_from_taught_on(occ) }
        .compact
        .select { |dt| dt >= now }
        .min

      {
        id: lp.id,
        title: lp.title,
        description: lp.description,
        teacher_id: lp.teacher_id,
        created_at: lp.created_at,
        updated_at: lp.updated_at,
        skills: lp.skills.as_json(only: [ :id, :name, :level ]),
        warmup_skills: lp.warmup_skills.as_json(only: [ :id, :name, :level ]),
        cooldown_skills: lp.cooldown_skills.as_json(only: [ :id, :name, :level ]),
        next_scheduled_at: next_dt
      }
    }
  end

  # GET /lesson_plans/:id
  def show
    unless can_read_lesson_plan?(@lesson_plan)
      return render json: { errors: [ "Not authorized" ] }, status: :unauthorized
    end

    lesson_plan = LessonPlan
      .includes(:skills, :warmup_skills, :cooldown_skills, :lesson_plan_occurrences)
      .find(@lesson_plan.id)

    render json: serialized_lesson_plan(lesson_plan)
  end

  # POST /lesson_plans/:id/duplicate
  def duplicate
    original = LessonPlan
      .includes(:lesson_plan_skills, :lesson_plan_occurrences)
      .find(params[:id])

    unless can_read_lesson_plan?(original)
      return render json: { errors: [ "Not authorized" ] }, status: :unauthorized
    end

    duplicate = current_user.lesson_plans.new(
      title: "#{original.title} Duplicate",
      description: original.description,
      warmup_notes: original.warmup_notes,
      main_notes: original.main_notes,
      cooldown_notes: original.cooldown_notes
    )

    LessonPlan.transaction do
      duplicate.save!

      original.lesson_plan_skills.order(:position, :id).each do |lps|
        LessonPlanSkill.create!(
          lesson_plan_id: duplicate.id,
          skill_id: lps.skill_id,
          role: lps.role,
          position: lps.position
        )
      end

      original.lesson_plan_occurrences.order(:taught_on, :starts_at).each do |occ|
        duplicate.lesson_plan_occurrences.create!(
          taught_on: occ.taught_on,
          starts_at: occ.starts_at,
          ends_at: occ.ends_at,
          location: occ.location
        )
      end
    end

    render json: serialized_lesson_plan(duplicate.reload), status: :created
rescue ActiveRecord::RecordInvalid => e
  render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
end

  # PATCH /lesson_plans/:id
  def update
    return render json: { errors: [ "Not authorized" ] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

    LessonPlan.transaction do
     base_attrs = lesson_plan_params.except(:ordered_skills_by_role)
    unless @lesson_plan.update(base_attrs)
        return render json: { errors: @lesson_plan.errors.full_messages }, status: :unprocessable_entity
    end

      if params.dig(:lesson_plan, :ordered_skills_by_role).present?
        sync_ordered_skills!
      end
    end

    render json: serialized_lesson_plan(@lesson_plan.reload), status: :ok
 rescue ActiveRecord::RecordInvalid => e
  render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
end

  # DELETE /lesson_plans/:id
  def destroy
    return render json: { errors: [ "Not authorized" ] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

    @lesson_plan.destroy
    head :no_content
  end

# POST /lesson_plans/:id/add_skills
def add_skills
  return render json: { errors: [ "Not authorized" ] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

  role = normalize_role(params[:role])
  skill_ids = Array(params[:skill_ids]).map(&:to_i).uniq

  created = 0
  next_position = @lesson_plan.lesson_plan_skills.where(role: role).maximum(:position).to_i + 1

  skill_ids.each do |skill_id|
    begin
      lps = LessonPlanSkill.find_or_initialize_by(
        lesson_plan_id: @lesson_plan.id,
        skill_id: skill_id,
        role: role
      )

      if lps.new_record?
        lps.position = next_position
        lps.save!
        next_position += 1
        created += 1
      end
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end

  render json: serialized_lesson_plan(@lesson_plan.reload), status: :ok
end

  # DELETE /lesson_plans/:id/remove_skill/:skill_id
  def remove_skill
  return render json: { errors: [ "Not authorized" ] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

  role = normalize_role(params[:role])

  lps = @lesson_plan.lesson_plan_skills.find_by(
    skill_id: params[:skill_id],
    role: role
  )

  return render json: { errors: [ "Skill not found" ] }, status: :not_found unless lps

  removed_role = lps.role
  removed_position = lps.position

  lps.destroy!

  @lesson_plan.lesson_plan_skills
    .where(role: removed_role)
    .where("position > ?", removed_position)
    .order(:position, :id)
    .each do |row|
      row.update!(position: row.position - 1)
    end

  render json: serialized_lesson_plan(@lesson_plan.reload), status: :ok
end

  private

  def lesson_plan_params
  params.require(:lesson_plan).permit(
    :title,
    :description,
    :warmup_notes,
    :main_notes,
    :cooldown_notes,
    ordered_skills_by_role: {
      main: [ :skill_id, :role, :position ],
      warmup: [ :skill_id, :role, :position ],
      cooldown: [ :skill_id, :role, :position ]
    }
  )
end

def accessible_lesson_plans
  return LessonPlan.all if current_user&.admin?
  LessonPlan.where(teacher_id: current_user.id)
end

def sync_ordered_skills!
  ordered = params.require(:lesson_plan).fetch(:ordered_skills_by_role, {})

  normalized_rows = []

  LessonPlanSkill::ROLES.each do |role|
    rows = ordered[role] || ordered[role.to_sym] || []

    rows.each_with_index do |row, index|
      skill_id = row[:skill_id] || row["skill_id"]
      next if skill_id.blank?

      normalized_rows << {
        role: role,
        skill_id: skill_id.to_i,
        position: index
      }
    end
  end

  # Keep only the first appearance of each skill_id across all sections.
  # This matches your UI expectation: one skill belongs to one section at a time.
  normalized_rows = normalized_rows.uniq { |row| row[:skill_id] }

  keep_skill_ids = normalized_rows.map { |row| row[:skill_id] }

  # Remove anything no longer present
  @lesson_plan.lesson_plan_skills.where.not(skill_id: keep_skill_ids).destroy_all

  # Index existing rows by skill_id so moves across roles update instead of conflict
  existing_by_skill_id = @lesson_plan.lesson_plan_skills.index_by(&:skill_id)

  normalized_rows.each do |row|
    join = existing_by_skill_id[row[:skill_id]] || @lesson_plan.lesson_plan_skills.new(skill_id: row[:skill_id])
    join.role = row[:role]
    join.position = row[:position]
    join.save!
  end
end

  def serialized_lesson_plan(lp)
    {
      id: lp.id,
      title: lp.title,
      description: lp.description,
      created_at: lp.created_at,
      updated_at: lp.updated_at,
      warmup_notes: lp.warmup_notes,
      main_notes: lp.main_notes,
      cooldown_notes: lp.cooldown_notes,
      skills: lp.skills.as_json(only: [ :id, :name, :level ]),
      warmup_skills: lp.warmup_skills.as_json(only: [ :id, :name, :level ]),
      cooldown_skills: lp.cooldown_skills.as_json(only: [ :id, :name, :level ]),
      lesson_plan_occurrences: lp.lesson_plan_occurrences
        .order(:taught_on, :starts_at)
        .map do |occ|
          {
            id: occ.id,
            taught_on: occ.taught_on,
            starts_at: occ.starts_at&.strftime("%H:%M"),
            ends_at: occ.ends_at&.strftime("%H:%M"),
            location: occ.location
          }
        end
    }
  end

  def no_store
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    response.headers.delete("ETag")
    response.headers.delete("Last-Modified")
  end

  def require_teacher
    return if current_user&.teacher?
    render json: { errors: [ "Not authorized" ] }, status: :unauthorized
  end

  def set_lesson_plan
    @lesson_plan = accessible_lesson_plans.find(params[:id])
  end

  def owns_lesson_plan?(lesson_plan)
    lesson_plan.teacher_id == current_user.id
  end

  def can_read_lesson_plan?(lesson_plan)
    return true if owns_lesson_plan?(lesson_plan)
    shared_lesson_plan_ids_for_member_rosters.include?(lesson_plan.id)
  end

  def member_rosters_relation
    owned_ids  = Roster.where(teacher_id: current_user.id).select(:id)
    taught_ids = RosterTeacher.where(teacher_id: current_user.id).select(:roster_id)
    Roster.where(id: owned_ids).or(Roster.where(id: taught_ids))
  end

  def shared_lesson_plan_ids_for_member_rosters
    rosters = member_rosters_relation.includes(:roster_schedules, :roster_meetings, :teachers)
    return [] if rosters.blank?

    teacher_ids   = rosters.flat_map { |r| [ r.teacher_id ] + r.teachers.map(&:id) }.uniq
    weekly_blocks = rosters.flat_map(&:roster_schedules)
    meetings      = rosters.flat_map(&:roster_meetings)

    occs = LessonPlanOccurrence
      .includes(:lesson_plan)
      .joins(:lesson_plan)
      .where(lesson_plans: { teacher_id: teacher_ids })
      .where.not(taught_on: nil, starts_at: nil, ends_at: nil)
      .order(:taught_on, :starts_at)

    occs.select { |occ|
      overlaps_any_weekly_block?(occ, weekly_blocks) || overlaps_any_meeting?(occ, meetings)
    }.map(&:lesson_plan_id).uniq
  end

  def overlaps_any_weekly_block?(occ, weekly_blocks)
    o_start = combine_date_and_time(occ.taught_on, occ.starts_at)
    o_end   = combine_date_and_time(occ.taught_on, occ.ends_at)
    return false if o_start.blank? || o_end.blank?

    weekly_blocks.any? do |blk|
      next false if blk.weekday.blank? || blk.starts_at.blank? || blk.ends_at.blank?
      next false unless occ.taught_on.wday == blk.weekday

      b_start = combine_date_and_time(occ.taught_on, blk.starts_at)
      b_end   = combine_date_and_time(occ.taught_on, blk.ends_at)

      overlaps?(b_start, b_end, o_start, o_end)
    end
  end

  def overlaps_any_meeting?(occ, meetings)
    o_start = combine_date_and_time(occ.taught_on, occ.starts_at)
    o_end   = combine_date_and_time(occ.taught_on, occ.ends_at)
    return false if o_start.blank? || o_end.blank?

    meetings.any? do |m|
      next false unless m.taught_on == occ.taught_on
      next false if m.starts_at.blank? || m.ends_at.blank?

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

  def normalize_role(role_param)
    role = role_param.presence || "main"
    %w[main warmup cooldown].include?(role) ? role : "main"
  end

  def occurrence_start_datetime_from_taught_on(occ)
    date = occ.taught_on
    return nil if date.blank?

    t = occ.starts_at
    return Time.zone.local(date.year, date.month, date.day, 0, 0, 0) if t.blank?

    Time.zone.local(date.year, date.month, date.day, t.hour, t.min, t.sec)
  end
end
