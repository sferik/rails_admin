require 'rails_admin/config'
require 'rails_admin/config/fields/base'

module RailsAdmin
  module Config
    module Fields
      class Association < RailsAdmin::Config::Fields::Base
        def self.inherited(klass)
          super(klass)
        end

        # Reader for the association information hash
        def association
          @properties
        end

        register_instance_option :pretty_value do
          v = bindings[:view]
          [value].flatten.select(&:present?).collect do |associated|
            amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config # perf optimization for non-polymorphic associations
            am = amc.abstract_model
            wording = associated.send(amc.object_label_method)
            can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
            can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : ERB::Util.html_escape(wording)
          end.to_sentence.html_safe
        end

        # Accessor whether association is visible or not. By default
        # association checks whether the child model is excluded in
        # configuration or not.
        register_instance_option :visible? do
          @visible ||= !associated_model_config.excluded?
        end

        # use the association name as a key, not the association key anymore!
        register_instance_option :label do
          (@label ||= {})[::I18n.locale] ||= abstract_model.model.human_attribute_name association.name
        end

        # scope for possible associable records
        register_instance_option :associated_collection_scope do
          # bindings[:object] & bindings[:controller] available
          associated_collection_scope_limit = (associated_collection_cache_all ? nil : 30)
          proc do |scope|
            scope.limit(associated_collection_scope_limit)
          end
        end

        # inverse relationship
        register_instance_option :inverse_of do
          association.inverse_of
        end

        # preload entire associated collection (per associated_collection_scope) on load
        # Be sure to set limit in associated_collection_scope if set is large
        register_instance_option :associated_collection_cache_all do
          @associated_collection_cache_all ||= (associated_model_config.abstract_model.count < associated_model_limit)
        end

        # determines whether association's elements can be removed
        register_instance_option :removable? do
          association.foreign_key_nullable?
        end

        register_instance_option :eager_load? do
          !!searchable
        end

        # Reader for the association's child model's configuration
        def associated_model_config
          @associated_model_config ||= RailsAdmin.config(association.klass)
        end

        # Reader for the association's child model object's label method
        def associated_object_label_method
          @associated_object_label_method ||= associated_model_config.object_label_method
        end

        # Reader for associated primary key
        def associated_primary_key
          @associated_primary_key ||= association.primary_key
        end

        # Reader for the association's key
        def foreign_key
          association.foreign_key
        end

        # Reader whether this is a polymorphic association
        def polymorphic?
          association.polymorphic?
        end

        def ref_ids_method
          association.ref_ids_method
        end

        # Reader for nested attributes
        register_instance_option :nested_form do
          association.nested_options
        end

        # Reader for the association's value unformatted
        def value
          bindings[:object].send(association.name)
        end

        # has many?
        def multiple?
          true
        end

        def virtual?
          true
        end

        def associated_model_limit
          RailsAdmin.config.default_associated_collection_limit
        end
      end
    end
  end
end
