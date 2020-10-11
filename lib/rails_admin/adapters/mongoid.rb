require 'mongoid'
require 'rails_admin/config/sections/list'
require 'rails_admin/adapters/mongoid/abstract_object'
require 'rails_admin/adapters/mongoid/association'
require 'rails_admin/adapters/mongoid/property'
require 'rails_admin/adapters/mongoid/bson'

module RailsAdmin
  module Adapters
    module Mongoid
      DISABLED_COLUMN_TYPES = %w[Range Moped::BSON::Binary BSON::Binary Mongoid::Geospatial::Point].freeze

      def parse_object_id(value)
        Bson.parse_object_id(value)
      end

      def new(params = {})
        AbstractObject.new(model.new(params))
      end

      def get(id)
        AbstractObject.new(model.find(id))
      rescue StandardError => e
        raise e if %w[
          Mongoid::Errors::DocumentNotFound
          Mongoid::Errors::InvalidFind
          Moped::Errors::InvalidObjectId
          BSON::InvalidObjectId
        ].exclude?(e.class.to_s)
      end

      def scoped
        model.scoped
      end

      def first(options = {}, scope = nil)
        all(options, scope).first
      end

      def all(options = {}, scope = nil)
        scope ||= scoped
        scope = scope.includes(*options[:include]) if options[:include]
        scope = scope.limit(options[:limit]) if options[:limit]
        scope = scope.any_in(_id: options[:bulk_ids]) if options[:bulk_ids]
        scope = query_scope(scope, options[:query]) if options[:query]
        scope = filter_scope(scope, options[:filters]) if options[:filters]
        scope = scope.send(Kaminari.config.page_method_name, options[:page]).per(options[:per]) if options[:page] && options[:per]
        scope = sort_by(options, scope) if options[:sort]
        scope
      rescue NoMethodError => e
        if e.message =~ /page/
          e = e.exception <<-EOM.gsub(/^\s{12}/, '')
            #{e.message}
            If you don't have kaminari-mongoid installed, add `gem 'kaminari-mongoid'` to your Gemfile.
          EOM
        end
        raise e
      end

      def count(options = {}, scope = nil)
        all(options.merge(limit: false, page: false), scope).count
      end

      def destroy(objects)
        Array.wrap(objects).each(&:destroy)
      end

      def primary_key
        '_id'
      end

      def associations
        model.relations.values.collect do |association|
          Association.new(association, model)
        end
      end

      def properties
        fields = model.fields.reject { |_name, field| DISABLED_COLUMN_TYPES.include?(field.type.to_s) }
        fields.collect { |_name, field| Property.new(field, model) }
      end

      def base_class
        klass = model
        klass = klass.superclass while klass.hereditary?
        klass
      end

      def table_name
        model.collection_name.to_s
      end

      def encoding
        Encoding::UTF_8
      end

      def embedded?
        associations.detect { |a| a.macro == :embedded_in }
      end

      def cyclic?
        model.cyclic?
      end

      def adapter_supports_joins?
        false
      end

    private

      def build_statement(column, type, value, operator)
        StatementBuilder.new(column, type, value, operator).to_statement
      end

      def make_field_conditions(field, value, operator)
        conditions_per_collection = {}
        field.searchable_columns.each do |column_infos|
          collection_name, column_name = parse_collection_name(column_infos[:column])
          statement = build_statement(column_name, column_infos[:type], value, operator)
          next unless statement

          conditions_per_collection[collection_name] ||= []
          conditions_per_collection[collection_name] << statement
        end
        conditions_per_collection
      end

      def query_scope(scope, query, fields = config.list.fields.select(&:queryable?))
        if config.list.search_by
          scope.send(config.list.search_by, query)
        else
          statements = []

          fields.each do |field|
            value = parse_field_value(field, query)
            conditions_per_collection = make_field_conditions(field, value, field.search_operator)
            statements.concat make_condition_for_current_collection(field, conditions_per_collection)
          end

          scope.where(statements.any? ? {'$or' => statements} : {})
        end
      end

      # filters example => {"string_field"=>{"0055"=>{"o"=>"like", "v"=>"test_value"}}, ...}
      # "0055" is the filter index, no use here. o is the operator, v the value
      def filter_scope(scope, filters, fields = config.list.fields.select(&:filterable?))
        statements = []

        filters.each_pair do |field_name, filters_dump|
          filters_dump.each do |_, filter_dump|
            field = fields.detect { |f| f.name.to_s == field_name }
            next unless field

            value = parse_field_value(field, filter_dump[:v])
            conditions_per_collection = make_field_conditions(field, value, (filter_dump[:o] || 'default'))
            field_statements = make_condition_for_current_collection(field, conditions_per_collection)
            if field_statements.many?
              statements << {'$or' => field_statements}
            elsif field_statements.any?
              statements << field_statements.first
            end
          end
        end

        scope.where(statements.any? ? {'$and' => statements} : {})
      end

      def parse_collection_name(column)
        collection_name, column_name = column.split('.')
        if associations.detect { |a| a.name == collection_name.to_sym }.try(:embeds?)
          [table_name, column]
        else
          [collection_name, column_name]
        end
      end

      def make_condition_for_current_collection(target_field, conditions_per_collection)
        result = []
        conditions_per_collection.each do |collection_name, conditions|
          if collection_name == table_name
            # conditions referring current model column are passed directly
            result.concat conditions
          else
            # otherwise, collect ids of documents that satisfy search condition
            result.concat perform_search_on_associated_collection(target_field.name, conditions)
          end
        end
        result
      end

      def perform_search_on_associated_collection(field_name, conditions)
        target_association = associations.detect { |a| a.name == field_name }
        return [] unless target_association

        model = target_association.klass
        case target_association.type
        when :belongs_to, :has_and_belongs_to_many
          [{target_association.foreign_key.to_s => {'$in' => model.where('$or' => conditions).all.collect { |r| r.send(target_association.primary_key) }}}]
        when :has_many
          [{target_association.primary_key.to_s => {'$in' => model.where('$or' => conditions).all.collect { |r| r.send(target_association.foreign_key) }}}]
        end
      end

      def sort_by(options, scope)
        return scope unless options[:sort]

        case options[:sort]
        when String
          field_name, collection_name = options[:sort].split('.').reverse
          raise('sorting by associated model column is not supported in Non-Relational databases') if collection_name && collection_name != table_name
        when Symbol
          field_name = options[:sort].to_s
        end
        if options[:sort_reverse]
          scope.asc field_name
        else
          scope.desc field_name
        end
      end

      class StatementBuilder < RailsAdmin::AbstractModel::StatementBuilder
      protected

        def unary_operators
          {
            '_blank' => {@column => {'$in' => [nil, '']}},
            '_present' => {@column => {'$nin' => [nil, '']}},
            '_null' => {@column => nil},
            '_not_null' => {@column => {'$ne' => nil}},
            '_empty' => {@column => ''},
            '_not_empty' => {@column => {'$ne' => ''}},
          }
        end

      private

        def build_statement_for_type
          case @type
          when :boolean                   then build_statement_for_boolean
          when :integer, :decimal, :float then build_statement_for_integer_decimal_or_float
          when :string, :text             then build_statement_for_string_or_text
          when :enum                      then build_statement_for_enum
          when :belongs_to_association, :bson_object_id then build_statement_for_belongs_to_association_or_bson_object_id
          end
        end

        def build_statement_for_boolean
          return {@column => false} if %w[false f 0].include?(@value)
          return {@column => true} if %w[true t 1].include?(@value)
        end

        def column_for_value(value)
          {@column => value}
        end

        def build_statement_for_string_or_text
          return if @value.blank?

          @value = begin
            case @operator
            when 'default', 'like'
              Regexp.compile(Regexp.escape(@value), Regexp::IGNORECASE)
            when 'starts_with'
              Regexp.compile("^#{Regexp.escape(@value)}", Regexp::IGNORECASE)
            when 'ends_with'
              Regexp.compile("#{Regexp.escape(@value)}$", Regexp::IGNORECASE)
            when 'is', '='
              @value.to_s
            else
              return
            end
          end
          {@column => @value}
        end

        def build_statement_for_enum
          return if @value.blank?

          {@column => {'$in' => Array.wrap(@value)}}
        end

        def build_statement_for_belongs_to_association_or_bson_object_id
          {@column => @value} if @value
        end

        def range_filter(min, max)
          if min && max
            {@column => {'$gte' => min, '$lte' => max}}
          elsif min
            {@column => {'$gte' => min}}
          elsif max
            {@column => {'$lte' => max}}
          end
        end
      end
    end
  end
end
