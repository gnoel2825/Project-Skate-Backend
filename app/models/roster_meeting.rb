class RosterMeeting < ApplicationRecord
  belongs_to :roster

  validates :taught_on, presence: true
end
