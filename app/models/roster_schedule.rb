class RosterSchedule < ApplicationRecord
  belongs_to :roster

  validates :weekday, inclusion: { in: 0..6 }
  validates :starts_at, :ends_at, presence: true
  validate :ends_after_starts

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?
    errors.add(:ends_at, "must be after starts_at") if ends_at <= starts_at
  end
end
