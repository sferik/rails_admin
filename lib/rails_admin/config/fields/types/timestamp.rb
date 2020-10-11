require 'rails_admin/config/fields/types/datetime'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Timestamp < RailsAdmin::Config::Fields::Types::Datetime
          # Register field type for the type loader
          RailsAdmin::Config::Fields::Types.register(self)

          @format = :long
          @i18n_scope = %i[time formats]
          @js_plugin_options = {}
        end
      end
    end
  end
end
