class CreateAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :attendances do |t|
      t.references :lesson_plan_occurrence, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.string :status, null: false, default: "present"
      t.text :note

      t.timestamps
    end

    add_index :attendances, [:lesson_plan_occurrence_id, :student_id], unique: true
  end
end