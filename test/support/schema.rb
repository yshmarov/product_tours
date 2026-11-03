# frozen_string_literal: true

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :product_tours_tours, force: true do |t|
    t.string :key, null: false
    t.string :locale, null: false
    t.string :status, null: false, default: 'draft'
    t.string :title, null: false
    t.text :video_url
    t.json :video_metadata, null: false, default: {}
    t.text :poster_url
    t.text :captions_url
    t.string :action_label
    t.text :action_url
    t.string :action_tour_key
    t.timestamps
  end
  add_index :product_tours_tours, %i[locale key], unique: true
  add_index :product_tours_tours, :status

  create_table :active_storage_blobs, force: true do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false
    t.index [:blob_id]
    t.index %i[record_type record_id name blob_id], unique: true,
                                                    name: 'index_active_storage_attachments_uniqueness'
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false
    t.index %i[blob_id variation_digest], unique: true,
                                          name: 'index_active_storage_variant_records_uniqueness'
  end

  create_table :action_text_rich_texts, force: true do |t|
    t.string :name, null: false
    t.text :body
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.timestamps
    t.index %i[record_type record_id name], unique: true,
                                            name: 'index_action_text_rich_texts_uniqueness'
  end
end
