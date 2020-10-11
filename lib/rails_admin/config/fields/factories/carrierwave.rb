require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/types/file_upload'

RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  model = parent.abstract_model.model
  if defined?(::CarrierWave) && model.is_a?(CarrierWave::Mount) && model.uploaders.include?(attachment_name = properties.name.to_s.chomp('_file_name').to_sym)
    columns = [model.uploader_options[attachment_name][:mount_on] || attachment_name, "#{attachment_name}_content_type".to_sym, "#{attachment_name}_file_size".to_sym]
    field = RailsAdmin::Config::Fields::Types.load(
      %i[serialized json].include?(properties.type) ? :multiple_carrierwave : :carrierwave,
    ).new(parent, attachment_name, properties)
    fields << field
    children_fields = []
    columns.each do |children_column_name|
      next unless child_properties = parent.abstract_model.properties.detect { |p| p.name.to_s == children_column_name.to_s }

      children_field = fields.detect { |f| f.name == children_column_name } || RailsAdmin::Config::Fields.default_factory.call(parent, child_properties, fields)
      children_field.hide unless field == children_field
      children_field.filterable(false) unless field == children_field
      children_fields << children_field.name
    end
    field.children_fields(children_fields)
    true
  else
    false
  end
end
