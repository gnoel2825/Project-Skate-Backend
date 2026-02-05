# app/controllers/lesson_plans_controller.rb
class LessonPlansController < ApplicationController
  before_action :require_teacher
  before_action :set_lesson_plan, only: [:show, :update, :destroy, :add_skills, :remove_skill]
  before_action :no_store, only: [:index]

  # POST /lesson_plans
  def create
    lesson_plan = current_user.lesson_plans.new(lesson_plan_params)

    if lesson_plan.save
      render json: lesson_plan, status: :created
    else
      render json: { errors: lesson_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /lesson_plans
  def index
    # If called with roster_id, return OCCURRENCES that match the roster schedules/meetings
    if params[:roster_id].present?
      roster = member_rosters_relation
          .includes(:roster_schedules, :roster_meetings, :teachers)
          .find(params[:roster_id])

      teacher_ids = ([roster.teacher_id] + roster.teachers.pluck(:id)).uniq
      weekly_blocks = roster.roster_schedules.to_a
      meetings      = roster.roster_meetings.to_a

      occs = LessonPlanOccurrence
               .includes(lesson_plan: :skills)
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

      render json: by_id.values.as_json(
        only: [:id, :taught_on, :starts_at, :ends_at, :location],
        include: {
          lesson_plan: {
            only: [:id, :title, :description, :teacher_id],
            include: { skills: { only: [:id, :name, :level] } }
          }
        }
      )
      return
    end

    # Default: return LESSON PLANS owned by current user
    # Default: return lesson plans visible to current user (roster-shared + mine)

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

      lp.as_json(only: [:id, :title, :description, :teacher_id, :created_at, :updated_at]).merge(
        skills: lp.skills.as_json(only: [:id, :name]),
        warmup_skills: lp.warmup_skills.as_json(only: [:id, :name]),
        cooldown_skills: lp.cooldown_skills.as_json(only: [:id, :name]),
        next_scheduled_at: next_dt
      )
    }
  end

  # GET /lesson_plans/:id
  def show
    unless can_read_lesson_plan?(@lesson_plan)
      return render json: { errors: ["Not authorized"] }, status: :unauthorized
    end

    lesson_plan = LessonPlan
                    .includes(:skills, :warmup_skills, :cooldown_skills, :lesson_plan_occurrences)
                    .find(@lesson_plan.id)

    render json: lesson_plan.as_json(
  only: [
    :id,
    :title,
    :description,
    :created_at,
    :updated_at,
    :warmup_notes,
    :main_notes,
    :cooldown_notes
  ]
).merge(
  skills: lesson_plan.skills.as_json(only: [:id, :name, :level]),
  warmup_skills: lesson_plan.warmup_skills.as_json(only: [:id, :name, :level]),
  cooldown_skills: lesson_plan.cooldown_skills.as_json(only: [:id, :name, :level]),
  lesson_plan_occurrences: lesson_plan.lesson_plan_occurrences
    .order(:taught_on, :starts_at)
    .map { |occ|
      occ.as_json(only: [:id, :taught_on, :location]).merge(
        starts_at: occ.starts_at&.strftime("%H:%M"),
        ends_at: occ.ends_at&.strftime("%H:%M")
      )
    }
)
  end

  # PATCH /lesson_plans/:id
  def update
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

    if @lesson_plan.update(lesson_plan_params)
      render json: @lesson_plan, status: :ok
    else
      render json: { errors: @lesson_plan.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /lesson_plans/:id
  def destroy
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

    @lesson_plan.destroy
    head :no_content
  end

  # POST /lesson_plans/:id/add_skills
  def add_skills
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

    skill_ids = Array(params[:skill_ids]).map(&:to_i).uniq
    role = normalize_role(params[:role])

    created = 0

    skill_ids.each_with_index do |skill_id, idx|
      begin
        lps = LessonPlanSkill.find_or_initialize_by(
          lesson_plan_id: @lesson_plan.id,
          skill_id: skill_id,
          role: role
        )

        if lps.new_record?
          lps.position = idx + 1
          lps.save!
          created += 1
        end
      rescue ActiveRecord::RecordNotUnique
        next
      end
    end

    render json: { ok: true, created: created }, status: :ok
  end

  # DELETE /lesson_plans/:id/remove_skill/:skill_id?role=warmup
  def remove_skill
    return render json: { errors: ["Not authorized"] }, status: :unauthorized unless owns_lesson_plan?(@lesson_plan)

    role = normalize_role(params[:role])

    lps = LessonPlanSkill.find_by(
      lesson_plan_id: @lesson_plan.id,
      skill_id: params[:skill_id],
      role: role
    )

    return render json: { errors: ["Skill not found in #{role}"] }, status: :not_found unless lps

    lps.destroy
    head :no_content
  end

  private

def lesson_plan_params
  params.require(:lesson_plan).permit(:title, :description,
  :warmup_notes, :main_notes, :cooldown_notes)
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
  render json: { errors: ["Not authorized"] }, status: :unauthorized
end

def set_lesson_plan
  @lesson_plan = LessonPlan.find(params[:id])
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

  teacher_ids   = rosters.flat_map { |r| [r.teacher_id] + r.teachers.map(&:id) }.uniq
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

    # occ.taught_on.wday: 0=Sun..6=Sat
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
