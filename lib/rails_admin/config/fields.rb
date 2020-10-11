module RailsAdmin
  module Config
    module Fields
      # Default field factory loads fields based on their property type or
      # association type.
      #
      # @see RailsAdmin::Config::Fields.registry
      mattr_reader :default_factory
      @@default_factory = proc do |parent, properties, fields|
        # If it's an association
        if properties.association?
          association = parent.abstract_model.associations.detect { |a| a.name.to_s == properties.name.to_s }
          field = RailsAdmin::Config::Fields::Types.load("#{association.polymorphic? ? :polymorphic : properties.type}_association").new(parent, properties.name, association)
        else
          field = RailsAdmin::Config::Fields::Types.load(properties.type).new(parent, properties.name, properties)
        end
        fields << field
        field
      end

      # Registry of field factories.
      #
      # Field factory is an anonymous function that recieves the parent object,
      # an array of field properties and an array of fields already instantiated.
      #
      # If the factory returns true then that property will not be run through
      # the rest of the registered factories. If it returns false then the
      # arguments will be passed to the next factory.
      #
      # By default a basic factory is registered which loads fields by their
      # database column type. Also a password factory is registered which
      # loads fields if their name is password. Third default factory is a
      # devise specific factory which loads fields for devise user models.
      #
      # @see RailsAdmin::Config::Fields.register_factory
      # @see rails_admin/config/fields/factories/password.rb
      # @see rails_admin/config/fields/factories/devise.rb
      @@registry = [@@default_factory]

      # Build an array of fields by the provided parent object's abstract_model's
      # property and association information. Each property and association is
      # passed to the registered field factories which will populate the fields
      # array that will be returned.
      #
      # @see RailsAdmin::Config::Fields.registry
      def self.factory(parent)
        fields = []
        # Load fields for all properties (columns)

        parent.abstract_model.properties.each do |properties|
          # Unless a previous factory has already loaded current field as well
          next if fields.detect { |f| f.name == properties.name }

          # Loop through factories until one returns true
          @@registry.detect { |factory| factory.call(parent, properties, fields) }
        end
        # Load fields for all associations (relations)
        parent.abstract_model.associations.reject { |a| a.type == :belongs_to }.each do |association| # :belongs_to are created by factory for belongs_to fields
          # Unless a previous factory has already loaded current field as well
          next if fields.detect { |f| f.name == association.name }

          # Loop through factories until one returns true
          @@registry.detect { |factory| factory.call(parent, association, fields) }
        end
        fields
      end

      # Register a field factory to be included in the factory stack.
      #
      # Factories are invoked lifo (last in first out).
      #
      # @see RailsAdmin::Config::Fields.registry
      def self.register_factory(&block)
        @@registry.unshift(block)
      end
    end
  end
end

require 'rails_admin/config/fields/types'
require 'rails_admin/config/fields/factories/password'
require 'rails_admin/config/fields/factories/enum'
require 'rails_admin/config/fields/factories/devise'
require 'rails_admin/config/fields/factories/paperclip'
require 'rails_admin/config/fields/factories/dragonfly'
require 'rails_admin/config/fields/factories/carrierwave'
require 'rails_admin/config/fields/factories/active_storage'
require 'rails_admin/config/fields/factories/shrine'
require 'rails_admin/config/fields/factories/action_text'
require 'rails_admin/config/fields/factories/association'
