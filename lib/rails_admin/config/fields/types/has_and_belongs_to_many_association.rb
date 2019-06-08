require 'rails_admin/config/fields/types/has_many_association'

module RailsAdmin
  module Config
    module Fields
      module Types
        class HasAndBelongsToManyAssociation < RailsAdmin::Config::Fields::Types::HasManyAssociation
          # Register field type for the type loader
          RailsAdmin::Config::Fields::Types.register(self)
          def method_name
            nested_form ? "#{name}_attributes".to_sym : ref_ids_method
          end
        end
      end
    end
  end
end
