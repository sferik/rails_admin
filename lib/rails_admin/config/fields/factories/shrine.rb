require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/types/file_upload'

RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  next false unless defined?(::Shrine)

  attachment_names = parent.abstract_model.model.ancestors.select { |m| m.is_a?(Shrine::Attachment) }.map { |a| a.instance_variable_get('@name') }
  next false if attachment_names.blank?

  attachment_name = attachment_names.detect { |a| a == properties.name.to_s.chomp('_data').to_sym }
  next false unless attachment_name

  field = RailsAdmin::Config::Fields::Types.load(:shrine).new(parent, attachment_name, properties)
  fields << field

  data_field_name = "#{attachment_name}_data".to_sym
  child_properties = parent.abstract_model.properties.detect { |p| p.name == data_field_name }
  next true unless child_properties

  children_field = fields.detect { |f| f.name == data_field_name } || RailsAdmin::Config::Fields.default_factory.call(parent, child_properties, fields)
  children_field.hide unless field == children_field
  children_field.filterable(false) unless field == children_field

  field.children_fields([data_field_name])
  true
end
