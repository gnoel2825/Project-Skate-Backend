class AddTeacherIdToStudents < ActiveRecord::Migration[7.1]
  def up
    # If teacher_id already exists, don't try to add it again
    unless column_exists?(:students, :teacher_id)
      add_reference :students, :teacher, null: true, foreign_key: { to_table: :users }, index: true
    end

    # If the column exists but FK/index don't, ensure they're present
    unless foreign_key_exists?(:students, :users, column: :teacher_id)
      add_foreign_key :students, :users, column: :teacher_id
    end

    unless index_exists?(:students, :teacher_id)
      add_index :students, :teacher_id
    end
  end

  def down
    remove_foreign_key :students, column: :teacher_id if foreign_key_exists?(:students, :users, column: :teacher_id)
    remove_index :students, :teacher_id if index_exists?(:students, :teacher_id)

    # Only remove the column if you *really* want to roll it back
    remove_column :students, :teacher_id if column_exists?(:students, :teacher_id)
  end
end
