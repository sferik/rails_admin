require 'rails_admin/config/proxyable'
require 'rails_admin/config/configurable'
require 'rails_admin/config/hideable'
require 'rails_admin/config/groupable'
require 'rails_admin/config/inspectable'

module RailsAdmin
  module Config
    module Fields
      class Base # rubocop:disable Metrics/ClassLength
        include RailsAdmin::Config::Proxyable
        include RailsAdmin::Config::Configurable
        include RailsAdmin::Config::Hideable
        include RailsAdmin::Config::Groupable
        include RailsAdmin::Config::Inspectable

        attr_reader :name, :properties, :abstract_model
        attr_accessor :defined, :order, :section
        attr_reader :parent, :root

        NAMED_INSTANCE_VARIABLES = %i[
          @parent @root @section @children_fields_registered
          @associated_model_config @group
        ].freeze

        def initialize(parent, name, properties)
          @parent = parent
          @root = parent.root

          @abstract_model = parent.abstract_model
          @defined = false
          @name = name.to_sym
          @order = 0
          @properties = properties
          @section = parent
        end

        register_instance_option :css_class do
          "#{name}_field"
        end

        def type_css_class
          "#{type}_type"
        end

        def virtual?
          properties.blank?
        end

        register_instance_option :column_width do
          nil
        end

        register_instance_option :sortable do
          !virtual? || children_fields.first || false
        end

        register_instance_option :searchable do
          !virtual? || children_fields.first || false
        end

        register_instance_option :queryable? do
          !virtual?
        end

        register_instance_option :filterable? do
          !!searchable
        end

        register_instance_option :search_operator do
          @search_operator ||= RailsAdmin::Config.default_search_operator
        end

        # serials and dates are reversed in list, which is more natural (last modified items first).
        register_instance_option :sort_reverse? do
          false
        end

        # list of columns I should search for that field [{ column: 'table_name.column', type: field.type }, {..}]
        register_instance_option :searchable_columns do
          @searchable_columns ||= begin
            case searchable
            when true
              [{column: "#{abstract_model.table_name}.#{name}", type: type}]
            when false
              []
            when :all # valid only for associations
              table_name = associated_model_config.abstract_model.table_name
              associated_model_config.list.fields.collect { |f| {column: "#{table_name}.#{f.name}", type: f.type} }
            else
              [searchable].flatten.collect do |f|
                if f.is_a?(String) && f.include?('.')                            #  table_name.column
                  table_name, column = f.split '.'
                  type = nil
                elsif f.is_a?(Hash)                                              #  <Model|table_name> => <attribute|column>
                  am = f.keys.first.is_a?(Class) && AbstractModel.new(f.keys.first)
                  table_name = am && am.table_name || f.keys.first
                  column = f.values.first
                  property = am && am.properties.detect { |p| p.name == f.values.first.to_sym }
                  type = property && property.type
                else                                                             #  <attribute|column>
                  am = (association? ? associated_model_config.abstract_model : abstract_model)
                  table_name = am.table_name
                  column = f
                  property = am.properties.detect { |p| p.name == f.to_sym }
                  type = property && property.type
                end
                {column: "#{table_name}.#{column}", type: (type || :string)}
              end
            end
          end
        end

        register_instance_option :formatted_value do
          value
        end

        # output for pretty printing (show, list)
        register_instance_option :pretty_value do
          formatted_value.presence || ' - '
        end

        # output for printing in export view (developers beware: no bindings[:view] and no data!)
        register_instance_option :export_value do
          pretty_value
        end

        # Accessor for field's help text displayed below input field.
        register_instance_option :help do
          (@help ||= {})[::I18n.locale] ||= generic_field_help
        end

        register_instance_option :html_attributes do
          {
            required: required?,
          }
        end

        register_instance_option :default_value do
          nil
        end

        # Accessor for field's label.
        #
        # @see RailsAdmin::AbstractModel.properties
        register_instance_option :label do
          (@label ||= {})[::I18n.locale] ||= abstract_model.model.human_attribute_name name
        end

        register_instance_option :hint do
          (@hint ||= '')
        end

        # Accessor for field's maximum length per database.
        #
        # @see RailsAdmin::AbstractModel.properties
        register_instance_option :length do
          @length ||= properties && properties.length
        end

        # Accessor for field's length restrictions per validations
        #
        register_instance_option :valid_length do
          @valid_length ||= abstract_model.model.validators_on(name).detect { |v| v.kind == :length }.try(&:options) || {}
        end

        register_instance_option :partial do
          :form_field
        end

        # Accessor for whether this is field is mandatory.
        #
        # @see RailsAdmin::AbstractModel.properties
        register_instance_option :required? do
          context = begin
            if bindings && bindings[:object]
              bindings[:object].persisted? ? :update : :create
            else
              :nil
            end
          end
          (@required ||= {})[context] ||= !!([name] + children_fields).uniq.detect do |column_name|
            abstract_model.model.validators_on(column_name).detect do |v|
              !(v.options[:allow_nil] || v.options[:allow_blank]) &&
                %i[presence numericality attachment_presence].include?(v.kind) &&
                (v.options[:on] == context || v.options[:on].blank?) &&
                (v.options[:if].blank? && v.options[:unless].blank?)
            end
          end
        end

        # Accessor for whether this is a serial field (aka. primary key, identifier).
        #
        # @see RailsAdmin::AbstractModel.properties
        register_instance_option :serial? do
          properties && properties.serial?
        end

        register_instance_option :view_helper do
          :text_field
        end

        register_instance_option :read_only? do
          !editable?
        end

        # init status in the view
        register_instance_option :active? do
          false
        end

        register_instance_option :visible? do
          returned = true
          (RailsAdmin.config.default_hidden_fields || {}).each do |section, fields|
            next unless self.section.is_a?("RailsAdmin::Config::Sections::#{section.to_s.camelize}".constantize)

            returned = false if fields.include?(name)
          end
          returned
        end

        # columns mapped (belongs_to, paperclip, etc.). First one is used for searching/sorting by default
        register_instance_option :children_fields do
          []
        end

        register_instance_option :render do
          bindings[:view].render partial: "rails_admin/main/#{partial}", locals: {field: self, form: bindings[:form]}
        end

        def editable?
          !(@properties && @properties.read_only?)
        end

        # Is this an association
        def association?
          is_a?(RailsAdmin::Config::Fields::Association)
        end

        # Reader for validation errors of the bound object
        def errors
          ([name] + children_fields).uniq.collect do |column_name|
            bindings[:object].errors[column_name]
          end.uniq.flatten
        end

        # Reader whether field is optional.
        #
        # @see RailsAdmin::Config::Fields::Base.register_instance_option :required?
        def optional?
          !required?
        end

        # Inverse accessor whether this field is required.
        #
        # @see RailsAdmin::Config::Fields::Base.register_instance_option :required?
        def optional(state = nil, &block)
          if !state.nil? || block
            required state.nil? ? proc { instance_eval(&block) == false } : state == false
          else
            optional?
          end
        end

        # Writer to make field optional.
        #
        # @see RailsAdmin::Config::Fields::Base.optional
        def optional=(state)
          optional(state)
        end

        # Reader for field's type
        def type
          @type ||= self.class.name.to_s.demodulize.underscore.to_sym
        end

        # Reader for field's value
        def value
          bindings[:object].safe_send(name)
        rescue NoMethodError => e
          raise e.exception <<-EOM.gsub(/^\s{10}/, '')
          #{e.message}
          If you want to use a RailsAdmin virtual field(= a field without corresponding instance method),
          you should declare 'formatted_value' in the field definition.
            field :#{name} do
              formatted_value{ bindings[:object].call_some_method }
            end
          EOM
        end

        # Reader for nested attributes
        register_instance_option :nested_form do
          false
        end

        # Allowed methods for the field in forms
        register_instance_option :allowed_methods do
          [method_name]
        end

        def generic_help
          (required? ? I18n.translate('admin.form.required') : I18n.translate('admin.form.optional')) + '. '
        end

        def generic_field_help
          model = abstract_model.model_name.underscore
          model_lookup = "admin.help.#{model}.#{name}".to_sym
          translated = I18n.translate(model_lookup, help: generic_help, default: [generic_help])
          (translated.is_a?(Hash) ? translated.to_a.first[1] : translated).html_safe
        end

        def parse_value(value)
          value
        end

        def parse_input(_params)
          # overriden
        end

        def inverse_of
          nil
        end

        def method_name
          name
        end

        def form_default_value
          (default_value if bindings[:object].new_record? && value.nil?)
        end

        def form_value
          form_default_value.nil? ? formatted_value : form_default_value
        end
      end
    end
  end
end
