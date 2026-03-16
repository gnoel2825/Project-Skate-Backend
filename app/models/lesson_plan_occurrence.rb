class LessonPlanOccurrence < ApplicationRecord
  belongs_to :lesson_plan
  belongs_to :roster, optional: true

  has_many :attendances, dependent: :destroy
  has_many :students, through: :attendances
end
