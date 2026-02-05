class AddRoleToLessonPlanSkills < ActiveRecord::Migration[7.1]
  def up
    add_column :lesson_plan_skills, :role, :string
    execute "UPDATE lesson_plan_skills SET role = 'main' WHERE role IS NULL"
    change_column_null :lesson_plan_skills, :role, false
    add_index :lesson_plan_skills, [:lesson_plan_id, :skill_id, :role], unique: true
  end

  def down
    remove_index :lesson_plan_skills, column: [:lesson_plan_id, :skill_id, :role]
    remove_column :lesson_plan_skills, :role
  end
end
