class RosterTeacher < ApplicationRecord
  belongs_to :roster
  belongs_to :teacher, class_name: "User"

  validates :teacher_id, uniqueness: { scope: :roster_id }
end
