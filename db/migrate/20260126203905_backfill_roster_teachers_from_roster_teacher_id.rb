class BackfillRosterTeachersFromRosterTeacherId < ActiveRecord::Migration[7.0]
  def up
    return unless column_exists?(:rosters, :teacher_id)

    Roster.reset_column_information

    Roster.find_each do |r|
      next unless r.teacher_id.present?
      RosterTeacher.find_or_create_by!(roster_id: r.id, teacher_id: r.teacher_id)
    end
  end

  def down
    # no-op
  end
end
