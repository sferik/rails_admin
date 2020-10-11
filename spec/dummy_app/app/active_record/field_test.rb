class FieldTest < ActiveRecord::Base
  has_many :nested_field_tests, dependent: :destroy, inverse_of: :field_test
  accepts_nested_attributes_for :nested_field_tests, allow_destroy: true

  has_one :comment, as: :commentable
  accepts_nested_attributes_for :comment, allow_destroy: true

  has_attached_file :paperclip_asset, styles: {thumb: '100x100>'}
  attr_accessor :delete_paperclip_asset
  before_validation { self.paperclip_asset = nil if delete_paperclip_asset == '1' }

  ActiveRecord::Base.extend Dragonfly::Model
  ActiveRecord::Base.extend Dragonfly::Model::Validations
  dragonfly_accessor :dragonfly_asset

  mount_uploader :carrierwave_asset, CarrierwaveUploader
  mount_uploaders :carrierwave_assets, CarrierwaveUploader
  serialize :carrierwave_assets, JSON

  if defined?(ActiveStorage)
    has_one_attached :active_storage_asset
    attr_accessor :remove_active_storage_asset
    after_save { active_storage_asset.purge if remove_active_storage_asset == '1' }

    has_many_attached :active_storage_assets
    attr_accessor :remove_active_storage_assets
    after_save do
      Array(remove_active_storage_assets).each { |id| active_storage_assets.find_by_id(id).try(:purge) }
    end
  end

  include ShrineUploader.attachment(:shrine_asset)
  include ShrineVersioningUploader.attachment(:shrine_versioning_asset)

  has_rich_text :action_text_field if defined?(ActionText)

  enum string_enum_field: {S: 's', M: 'm', L: 'l'}
  enum integer_enum_field: %i[small medium large]

  validates :string_field, exclusion: {in: ['Invalid']} # to test file upload caching
end
