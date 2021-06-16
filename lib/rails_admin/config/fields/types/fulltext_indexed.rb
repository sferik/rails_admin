require 'rails_admin/config/fields/types/text'

module RailsAdmin
  module Config
    module Fields
      module Types
        class FulltextIndexed < Text
          RailsAdmin::Config::Fields::Types.register(self)
        end
      end
    end
  end
end
