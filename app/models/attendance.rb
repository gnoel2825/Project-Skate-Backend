class Attendance < ApplicationRecord
  STATUSES = %w[present absent late excused].freeze

  belongs_to :lesson_plan_occurrence
  belongs_to :student

  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :student_id, uniqueness: { scope: :lesson_plan_occurrence_id }
end
