class AddSectionNotesToLessonPlans < ActiveRecord::Migration[7.0]
  def change
    add_column :lesson_plans, :warmup_notes, :text
    add_column :lesson_plans, :main_notes, :text
    add_column :lesson_plans, :cooldown_notes, :text
  end
end
