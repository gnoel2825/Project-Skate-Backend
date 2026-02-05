class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.string :name, null: false
      t.integer :level
      t.text :description
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end
    add_index :skills, :name, unique: true
  end
end
