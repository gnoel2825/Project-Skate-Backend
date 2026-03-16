class LessonPlan < ApplicationRecord
  belongs_to :teacher, class_name: "User", foreign_key: :teacher_id

  has_many :lesson_plan_skills, dependent: :destroy
  has_many :skills, through: :lesson_plan_skills

  has_many :main_lesson_plan_skills, -> { where(role: "main").order(:position, :id) },
           class_name: "LessonPlanSkill"
  has_many :warmup_lesson_plan_skills, -> { where(role: "warmup").order(:position, :id) },
           class_name: "LessonPlanSkill"
  has_many :cooldown_lesson_plan_skills, -> { where(role: "cooldown").order(:position, :id) },
           class_name: "LessonPlanSkill"

  has_many :main_skills, through: :main_lesson_plan_skills, source: :skill
  has_many :warmup_skills, through: :warmup_lesson_plan_skills, source: :skill
  has_many :cooldown_skills, through: :cooldown_lesson_plan_skills, source: :skill

  has_many :lesson_plan_occurrences, dependent: :destroy
end