class Roster < ApplicationRecord
  belongs_to :teacher, class_name: "User", optional: true

  has_many :roster_teachers, dependent: :destroy
  has_many :teachers, through: :roster_teachers, source: :teacher

  scope :accessible_by, ->(user) do
    return none unless user

    left_outer_joins(:roster_teachers)
      .where("rosters.teacher_id = :uid OR roster_teachers.teacher_id = :uid", uid: user.id)
      .distinct
  end

  has_many :roster_students, dependent: :destroy
  has_many :students, through: :roster_students

  has_many :roster_meetings, dependent: :destroy
  has_many :roster_schedules, dependent: :destroy

  has_many :roster_teachers, dependent: :destroy
  has_many :teachers, through: :roster_teachers, source: :teacher

  has_many :lesson_plan_occurrences

end
