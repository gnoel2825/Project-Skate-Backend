class CreateRosterTeachers < ActiveRecord::Migration[7.0]
  def change
    create_table :roster_teachers do |t|
      t.references :roster, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :roster_teachers, [:roster_id, :teacher_id], unique: true
  end
end