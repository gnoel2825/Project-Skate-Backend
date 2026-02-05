class CreateRosterMeetings < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_meetings do |t|
      t.references :roster, null: false, foreign_key: true
      t.date :taught_on
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :location

      t.timestamps
    end
  end
end
