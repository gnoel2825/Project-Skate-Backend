class FixRosterTeacherForeignKey < ActiveRecord::Migration[8.1]
  def change
    drop_table :rosters

    create_table :rosters do |t|
      t.integer :teacher_id, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :rosters, :teacher_id
    add_foreign_key :rosters, :users, column: :teacher_id
  end
end
