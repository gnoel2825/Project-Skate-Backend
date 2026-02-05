class RefactorRosterScheduleTimesToTimeOnly < ActiveRecord::Migration[7.0]
  def up
    add_column :roster_schedules, :starts_time, :time
    add_column :roster_schedules, :ends_time, :time

    # Backfill from old starts_at/ends_at (whatever type they are)
    RosterSchedule.reset_column_information
    RosterSchedule.find_each do |s|
      s.starts_time = s.starts_at&.strftime("%H:%M:%S")
      s.ends_time   = s.ends_at&.strftime("%H:%M:%S")
      s.save!(validate: false)
    end

    # Swap columns
    remove_column :roster_schedules, :starts_at
    remove_column :roster_schedules, :ends_at

    rename_column :roster_schedules, :starts_time, :starts_at
    rename_column :roster_schedules, :ends_time, :ends_at
  end

  def down
    add_column :roster_schedules, :starts_dt, :datetime
    add_column :roster_schedules, :ends_dt, :datetime

    RosterSchedule.reset_column_information
    RosterSchedule.find_each do |s|
      # Anchor back to 2000-01-01 if rolling back (not ideal, but reversible)
      if s.starts_at.present?
        t = s.starts_at
        s.starts_dt = Time.zone.local(2000, 1, 1, t.hour, t.min, t.sec)
      end
      if s.ends_at.present?
        t = s.ends_at
        s.ends_dt = Time.zone.local(2000, 1, 1, t.hour, t.min, t.sec)
      end
      s.save!(validate: false)
    end

    remove_column :roster_schedules, :starts_at
    remove_column :roster_schedules, :ends_at

    rename_column :roster_schedules, :starts_dt, :starts_at
    rename_column :roster_schedules, :ends_dt, :ends_at
  end
end
