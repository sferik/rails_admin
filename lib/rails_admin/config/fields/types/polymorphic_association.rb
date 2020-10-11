require 'rails_admin/config/fields/types/belongs_to_association'

module RailsAdmin
  module Config
    module Fields
      module Types
        class PolymorphicAssociation < RailsAdmin::Config::Fields::Types::BelongsToAssociation
          # Register field type for the type loader
          RailsAdmin::Config::Fields::Types.register(self)

          register_instance_option :partial do
            :form_polymorphic_association
          end

          # Accessor whether association is visible or not. By default
          # association checks that any of the child models are included in
          # configuration.
          register_instance_option :visible? do
            associated_model_config.any?
          end

          register_instance_option :formatted_value do
            (o = value) && o.send(RailsAdmin.config(o).object_label_method)
          end

          register_instance_option :sortable do
            false
          end

          register_instance_option :searchable do
            false
          end

          # TODO: not supported yet
          register_instance_option :associated_collection_cache_all do
            false
          end

          # TODO: not supported yet
          register_instance_option :associated_collection_scope do
            nil
          end

          register_instance_option :allowed_methods do
            [children_fields]
          end

          register_instance_option :eager_load? do
            false
          end

          def associated_collection(type)
            return [] if type.blank?

            config = RailsAdmin.config(type)
            config.abstract_model.all.collect do |object|
              [object.send(config.object_label_method), object.id]
            end
          end

          def associated_model_config
            @associated_model_config ||= association.klass.collect { |type| RailsAdmin.config(type) }.reject(&:excluded?)
          end

          def polymorphic_type_collection
            associated_model_config.collect do |config|
              [config.label, config.abstract_model.model.name]
            end
          end

          def polymorphic_type_urls
            types = associated_model_config.collect do |config|
              [config.abstract_model.model.name, config.abstract_model.to_param]
            end
            ::Hash[*types.collect { |v| [v[0], bindings[:view].index_path(v[1])] }.flatten]
          end

          # Reader for field's value
          def value
            bindings[:object].send(association.name)
          end

          def parse_input(params)
            return if (type_value = params[association.foreign_type.to_sym]).blank?

            config = associated_model_config.find { |c| type_value == c.abstract_model.model.name }
            params[association.foreign_type.to_sym] = config.abstract_model.base_class.name if config
          end
        end
      end
    end
  end
end
