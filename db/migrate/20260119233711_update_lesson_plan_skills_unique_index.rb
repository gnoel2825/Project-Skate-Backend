class UpdateLessonPlanSkillsUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    # remove old unique index (lesson_plan_id, skill_id)
    remove_index :lesson_plan_skills, column: [:lesson_plan_id, :skill_id]

    # add new unique index including role
    add_index :lesson_plan_skills, [:lesson_plan_id, :skill_id, :role], unique: true
  end
end
