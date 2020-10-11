module RailsAdmin
  module Adapters
    module Mongoid
      class Property
        STRING_TYPE_COLUMN_NAMES = %i[name title subject].freeze
        attr_reader :property, :model

        def initialize(property, model)
          @property = property
          @model = model
        end

        def name
          property.name.to_sym
        end

        def pretty_name
          property.name.to_s.tr('_', ' ').capitalize
        end

        def type
          case property.type.to_s
          when 'Array', 'Hash', 'Money'
            :serialized
          when 'BigDecimal'
            :decimal
          when 'Boolean', 'Mongoid::Boolean'
            :boolean
          when 'BSON::ObjectId', 'Moped::BSON::ObjectId'
            :bson_object_id
          when 'Date'
            :date
          when 'ActiveSupport::TimeWithZone', 'DateTime', 'Time'
            :datetime
          when 'Float'
            :float
          when 'Integer'
            :integer
          when 'Object'
            object_field_type
          when 'String'
            string_field_type
          when 'Symbol'
            :string
          else
            :string
          end
        end

        def length
          (length_validation_lookup || 255) if type == :string
        end

        def nullable?
          true
        end

        def serial?
          name == :_id
        end

        def association?
          false
        end

        def read_only?
          false
        end

      private

        def object_field_type
          association = Association.new model.relations.values.detect { |r| r.try(:foreign_key).try(:to_sym) == name }, model
          if %i[belongs_to referenced_in embedded_in].include?(association.macro)
            :bson_object_id
          else
            :string
          end
        end

        def string_field_type
          if ((length = length_validation_lookup) && length < 256) || STRING_TYPE_COLUMN_NAMES.include?(name)
            :string
          else
            :text
          end
        end

        def length_validation_lookup
          shortest = model.validators.select { |validator| validator.respond_to?(:attributes) && validator.attributes.include?(name.to_sym) && validator.kind == :length && validator.options[:maximum] }.min do |a, b|
            a.options[:maximum] <=> b.options[:maximum]
          end

          shortest && shortest.options[:maximum]
        end
      end
    end
  end
end
