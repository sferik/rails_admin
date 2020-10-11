require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/types/file_upload'

RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  extensions = %i[file_name content_type file_size updated_at fingerprint]
  model = parent.abstract_model.model
  if (properties.name.to_s =~ /^(.+)_file_name$/) && defined?(::Paperclip) && model.try(:attachment_definitions) && model.attachment_definitions.key?(attachment_name = Regexp.last_match[1].to_sym)
    field = RailsAdmin::Config::Fields::Types.load(:paperclip).new(parent, attachment_name, properties)
    children_fields = []
    extensions.each do |ext|
      children_column_name = "#{attachment_name}_#{ext}".to_sym
      next unless child_properties = parent.abstract_model.properties.detect { |p| p.name.to_s == children_column_name.to_s }

      children_field = fields.detect { |f| f.name == children_column_name } || RailsAdmin::Config::Fields.default_factory.call(parent, child_properties, fields)
      children_field.hide
      children_field.filterable(false)
      children_fields << children_field.name
    end
    field.children_fields(children_fields)
    fields << field
    true
  else
    false
  end
end
