class CreateRosterStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_students do |t|
      t.references :roster, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true

      t.timestamps
    end
  end
end
