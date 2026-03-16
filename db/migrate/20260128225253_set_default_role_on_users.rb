class SetDefaultRoleOnUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :role, from: "student", to: "none"
  end
end
