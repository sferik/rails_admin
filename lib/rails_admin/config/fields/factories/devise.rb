require 'rails_admin/config/fields'
require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/types/password'

# Register a custom field factory for devise model
RailsAdmin::Config::Fields.register_factory do |parent, properties, fields|
  if properties.name == :encrypted_password
    extensions = %i[password_salt reset_password_token remember_token]
    fields << RailsAdmin::Config::Fields::Types.load(:password).new(parent, :password, properties)
    fields << RailsAdmin::Config::Fields::Types.load(:password).new(parent, :password_confirmation, properties)
    extensions.each do |ext|
      properties = parent.abstract_model.properties.detect { |p| ext == p.name }
      next unless properties

      unless field = fields.detect { |f| f.name == ext }
        RailsAdmin::Config::Fields.default_factory.call(parent, properties, fields)
        field = fields.last
      end
      field.hide
    end
    true
  else
    false
  end
end
