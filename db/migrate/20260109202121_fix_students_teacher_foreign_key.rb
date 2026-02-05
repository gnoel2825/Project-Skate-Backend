class FixStudentsTeacherForeignKey < ActiveRecord::Migration[8.1]
  def change
    # remove the wrong FK (teacher_id -> teachers)
    remove_foreign_key :students, :teachers if foreign_key_exists?(:students, :teachers)

    # add the correct FK (teacher_id -> users)
    add_foreign_key :students, :users, column: :teacher_id
  end
end
