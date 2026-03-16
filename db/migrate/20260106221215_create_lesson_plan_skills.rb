class CreateLessonPlanSkills < ActiveRecord::Migration[7.0]
  def change
    create_table :lesson_plan_skills do |t|
      t.references :lesson_plan, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true
      t.integer :position
      t.text :notes
      t.timestamps
    end

    add_index :lesson_plan_skills, [ :lesson_plan_id, :skill_id ], unique: true
    add_index :lesson_plan_skills, [ :lesson_plan_id, :position ]
  end
end
