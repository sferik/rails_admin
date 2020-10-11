class CreateVersions < ActiveRecord::Migration[5.0]
  def change
    create_table :versions do |t|
      t.string :item_type, null: false
      t.integer :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.text :object
      t.datetime :created_at
    end
    add_index :versions, %i[item_type item_id]
  end
end
