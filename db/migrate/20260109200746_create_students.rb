class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.references :teacher, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.date :birthday
      t.text :notes

      t.timestamps
    end
  end
end
