# This migration comes from active_storage (originally 20170806125915)
class CreateActiveStorageTables < ActiveRecord::Migration[5.0]
  def change
    create_table :active_storage_blobs do |t|
      t.string   :key,        null: false
      t.string   :filename,   null: false
      t.string   :content_type
      t.text     :metadata
      if t.respond_to? :bigint
        t.bigint   :byte_size,  null: false
      else
        t.integer  :byte_size,  null: false
      end
      t.string   :checksum,   null: false
      t.datetime :created_at, null: false

      t.index [:key], unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false
      t.references :blob,     null: false

      t.datetime :created_at, null: false

      t.index %i[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness', unique: true
    end
  end
end
