class CreateMoments < ActiveRecord::Migration[6.1]
  def change
    create_table :moments do |t|
      t.string :link, null: false
      t.string :file_path
      t.string :description

      t.timestamps
    end
  end
end
