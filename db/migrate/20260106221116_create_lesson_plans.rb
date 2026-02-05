class CreateLessonPlans < ActiveRecord::Migration[7.0]
  def change
    create_table :lesson_plans do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.timestamps
    end
  end
end
