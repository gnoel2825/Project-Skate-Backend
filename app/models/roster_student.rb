class RosterStudent < ApplicationRecord
  belongs_to :roster
  belongs_to :student

  validates :student_id, uniqueness: { scope: :roster_id }
end
