require 'active_support/core_ext/string/inflections'
require 'rails_admin/config/sections/base'
require 'rails_admin/config/sections/edit'
require 'rails_admin/config/sections/update'
require 'rails_admin/config/sections/create'
require 'rails_admin/config/sections/nested'
require 'rails_admin/config/sections/modal'
require 'rails_admin/config/sections/list'
require 'rails_admin/config/sections/export'
require 'rails_admin/config/sections/show'

module RailsAdmin
  module Config
    # Sections describe different views in the RailsAdmin engine. Configurable sections are
    # list and navigation.
    #
    # Each section's class object can store generic configuration about that section (such as the
    # number of visible tabs in the main navigation), while the instances (accessed via model
    # configuration objects) store model specific configuration (such as the visibility of the
    # model).
    module Sections
      def self.included(klass)
        # Register accessors for all the sections in this namespace
        constants.each do |name|
          section = RailsAdmin::Config::Sections.const_get(name)
          name = name.to_s.underscore.to_sym
          klass.send(:define_method, name) do |&block|
            @sections ||= {}
            @sections[name] = section.new(self) unless @sections[name]
            @sections[name].instance_eval(&block) if block
            @sections[name]
          end
        end
      end
    end
  end
end
