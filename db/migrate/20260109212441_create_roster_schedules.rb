class CreateRosterSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_schedules do |t|
      t.references :roster, null: false, foreign_key: true
      t.integer :weekday
      t.time :starts_at
      t.time :ends_at
      t.string :location

      t.timestamps
    end
  end
end
