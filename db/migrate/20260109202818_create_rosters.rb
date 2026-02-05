class CreateRosters < ActiveRecord::Migration[8.1]
  def change
    create_table :rosters do |t|
      t.references :teacher, null: false, foreign_key: { to_table: :users }
      t.string :name

      t.timestamps
    end
  end
end
