class Student < ApplicationRecord
  # Direct ownership (teacher_id on students)
  belongs_to :teacher, class_name: "User", foreign_key: :teacher_id, optional: true

  has_many :roster_students, dependent: :destroy
  has_many :rosters, through: :roster_students

  # ✅ Teachers the student is connected to through rosters
  # Requires: Roster belongs_to :teacher (class_name: "User")
  has_many :roster_teachers, -> { distinct }, through: :rosters, source: :teacher

  has_many :attendances, dependent: :destroy
  has_many :lesson_plan_occurrences, through: :attendances

  validates :first_name, :last_name, presence: true
end
