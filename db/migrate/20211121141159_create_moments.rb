class CreateMoments < ActiveRecord::Migration[6.1]
  def change
    create_table :moments do |t|
      t.string :link
      t.string :file_path

      t.timestamps
    end
  end
end
