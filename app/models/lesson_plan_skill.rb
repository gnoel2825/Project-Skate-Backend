class LessonPlanSkill < ApplicationRecord
  belongs_to :lesson_plan
  belongs_to :skill

  ROLES = %w[main warmup cooldown].freeze
  validates :role, inclusion: { in: ROLES }
  validates :skill_id, uniqueness: { scope: [:lesson_plan_id, :role] }
end
