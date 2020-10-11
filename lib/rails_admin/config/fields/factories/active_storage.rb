require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/types/file_upload'

RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  if defined?(::ActiveStorage) && properties.try(:association?) && (match = /\A(.+)_attachments?\Z/.match properties.name) && properties.klass.to_s == 'ActiveStorage::Attachment'
    name = match[1]
    field = RailsAdmin::Config::Fields::Types.load(
      properties.type == :has_many ? :multiple_active_storage : :active_storage,
    ).new(parent, name, properties)
    fields << field
    associations =
      if properties.type == :has_many
        ["#{name}_attachments".to_sym, "#{name}_blobs".to_sym]
      else
        ["#{name}_attachment".to_sym, "#{name}_blob".to_sym]
      end
    children_fields = associations.map do |child_name|
      next unless child_association = parent.abstract_model.associations.detect { |p| p.name.to_sym == child_name }

      child_field = fields.detect { |f| f.name == child_name } || RailsAdmin::Config::Fields.default_factory.call(parent, child_association, fields)
      child_field.hide unless field == child_field
      child_field.filterable(false) unless field == child_field
      child_field.name
    end.flatten.compact
    field.children_fields(children_fields)
    true
  else
    false
  end
end
