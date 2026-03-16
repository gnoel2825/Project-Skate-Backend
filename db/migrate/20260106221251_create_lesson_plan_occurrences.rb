class CreateLessonPlanOccurrences < ActiveRecord::Migration[7.0]
  def change
    create_table :lesson_plan_occurrences do |t|
      t.references :lesson_plan, null: false, foreign_key: true
      t.date :taught_on, null: false
      t.time :starts_at
      t.time :ends_at
      t.string :location
      t.timestamps
    end

    add_index :lesson_plan_occurrences, :taught_on
    add_index :lesson_plan_occurrences, [ :lesson_plan_id, :taught_on ]
  end
end
