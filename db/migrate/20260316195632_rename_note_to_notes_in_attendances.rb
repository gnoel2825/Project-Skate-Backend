class RenameNoteToNotesInAttendances < ActiveRecord::Migration[8.1]
  def change
    rename_column :attendances, :note, :notes
  end
end
