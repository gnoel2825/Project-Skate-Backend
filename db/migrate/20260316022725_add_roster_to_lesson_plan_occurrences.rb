class AddRosterToLessonPlanOccurrences < ActiveRecord::Migration[8.1]
  def change
    add_reference :lesson_plan_occurrences, :roster, null: true, foreign_key: true
  end
end
