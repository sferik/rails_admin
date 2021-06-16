require 'active_record'
require 'rails_admin/adapters/active_record/abstract_object'
require 'rails_admin/adapters/active_record/association'
require 'rails_admin/adapters/active_record/property'

module RailsAdmin
  module Adapters
    module ActiveRecord
      DISABLED_COLUMN_TYPES = [:tsvector, :blob, :binary, :spatial, :hstore, :geometry].freeze

      def new(params = {})
        AbstractObject.new(model.new(params))
      end

      def get(id)
        return unless object = model.where(primary_key => id).first
        AbstractObject.new object
      end

      def scoped
        model.all
      end

      def first(options = {}, scope = nil)
        all(options, scope).first
      end

      def all(options = {}, scope = nil)
        scope ||= scoped
        scope = scope.includes(options[:include]) if options[:include]
        scope = scope.limit(options[:limit]) if options[:limit]
        scope = scope.where(primary_key => options[:bulk_ids]) if options[:bulk_ids]
        scope = query_scope(scope, options[:query]) if options[:query]
        scope = filter_scope(scope, options[:filters]) if options[:filters]
        if options[:page] && options[:per]
          scope = scope.send(Kaminari.config.page_method_name, options[:page]).per(options[:per])
        end
        scope = scope.reorder("#{options[:sort]} #{options[:sort_reverse] ? 'asc' : 'desc'}") if options[:sort]
        scope
      end

      def count(options = {}, scope = nil)
        all(options.merge(limit: false, page: false), scope).count(:all)
      end

      def destroy(objects)
        Array.wrap(objects).each(&:destroy)
      end

      def associations
        model.reflect_on_all_associations.collect do |association|
          Association.new(association, model)
        end
      end

      def properties
        columns = model.columns.reject do |c|
          c.type.blank? ||
            DISABLED_COLUMN_TYPES.include?(c.type.to_sym) ||
            c.try(:array)
        end
        columns.collect do |property|
          Property.new(property, model)
        end
      end

      def base_class
        model.base_class
      end

      delegate :primary_key, :table_name, to: :model, prefix: false

      def encoding
        adapter =
          if ::ActiveRecord::Base.respond_to?(:connection_db_config)
            ::ActiveRecord::Base.connection_db_config.configuration_hash[:adapter]
          else
            ::ActiveRecord::Base.connection_config[:adapter]
          end
        case adapter
        when 'postgresql'
          ::ActiveRecord::Base.connection.select_one("SELECT ''::text AS str;").values.first.encoding
        when 'mysql2'
          ::ActiveRecord::Base.connection.raw_connection.encoding
        when 'oracle_enhanced'
          ::ActiveRecord::Base.connection.select_one("SELECT dummy FROM DUAL").values.first.encoding
        else
          ::ActiveRecord::Base.connection.select_one("SELECT '' AS str;").values.first.encoding
        end
      end

      def embedded?
        false
      end

      def cyclic?
        false
      end

      def adapter_supports_joins?
        true
      end

      class WhereBuilder
        def initialize(scope)
          @statements = []
          @values = []
          @tables = []
          @scope = scope
        end

        def add(field, value, operator)
          field.searchable_columns.flatten.each do |column_infos|
            statement, value1, value2 = StatementBuilder.new(column_infos[:column], column_infos[:type], value, operator, @scope.connection.adapter_name).to_statement
            @statements << statement if statement.present?
            @values << value1 unless value1.nil?
            @values << value2 unless value2.nil?
            table, column = column_infos[:column].split('.')
            @tables.push(table) if column
          end
        end

        def build
          scope = @scope.where(@statements.join(' OR '), *@values)
          scope = scope.references(*@tables.uniq) if @tables.any?
          scope
        end
      end

      def query_scope(scope, query, fields = config.list.fields.select(&:queryable?))
        if config.list.search_by
          scope.send(config.list.search_by, query)
        else
          wb = WhereBuilder.new(scope)
          fields.each do |field|
            value = parse_field_value(field, query)
            wb.add(field, value, field.search_operator)
          end
          # OR all query statements
          wb.build
        end
      end

      # filters example => {"string_field"=>{"0055"=>{"o"=>"like", "v"=>"test_value"}}, ...}
      # "0055" is the filter index, no use here. o is the operator, v the value
      def filter_scope(scope, filters, fields = config.list.fields.select(&:filterable?))
        filters.each_pair do |field_name, filters_dump|
          filters_dump.each do |_, filter_dump|
            wb = WhereBuilder.new(scope)
            field = fields.detect { |f| f.name.to_s == field_name }
            value = parse_field_value(field, filter_dump[:v])

            wb.add(field, value, (filter_dump[:o] || RailsAdmin::Config.default_search_operator))
            # AND current filter statements to other filter statements
            scope = wb.build
          end
        end
        scope
      end

      def build_statement(column, type, value, operator)
        StatementBuilder.new(column, type, value, operator, model.connection.adapter_name).to_statement
      end

      class StatementBuilder < RailsAdmin::AbstractModel::StatementBuilder
        def initialize(column, type, value, operator, adapter_name)
          super column, type, value, operator
          @adapter_name = adapter_name
        end

      protected

        def unary_operators
          case @type
          when :boolean
            boolean_unary_operators
          when :integer, :decimal, :float
            numeric_unary_operators
          else
            generic_unary_operators
          end
        end

      private

        def generic_unary_operators
          {
            '_blank' => ["(#{@column} IS NULL OR #{@column} = '')"],
            '_present' => ["(#{@column} IS NOT NULL AND #{@column} != '')"],
            '_null' => ["(#{@column} IS NULL)"],
            '_not_null' => ["(#{@column} IS NOT NULL)"],
            '_empty' => ["(#{@column} = '')"],
            '_not_empty' => ["(#{@column} != '')"],
          }
        end

        def boolean_unary_operators
          generic_unary_operators.merge(
            '_blank' => ["(#{@column} IS NULL)"],
            '_empty' => ["(#{@column} IS NULL)"],
            '_present' => ["(#{@column} IS NOT NULL)"],
            '_not_empty' => ["(#{@column} IS NOT NULL)"],
          )
        end
        alias_method :numeric_unary_operators, :boolean_unary_operators

        def range_filter(min, max)
          if min && max
            ["(#{@column} BETWEEN ? AND ?)", min, max]
          elsif min
            ["(#{@column} >= ?)", min]
          elsif max
            ["(#{@column} <= ?)", max]
          end
        end

        def build_statement_for_type
          case @type
          when :boolean                   then build_statement_for_boolean
          when :integer, :decimal, :float then build_statement_for_integer_decimal_or_float
          when :string, :text             then build_statement_for_string_or_text
          when :enum                      then build_statement_for_enum
          when :belongs_to_association    then build_statement_for_belongs_to_association
          when :uuid                      then build_statement_for_uuid
          when :fulltext_indexed          then build_statement_for_fulltext_indexed
          end
        end

        def build_statement_for_boolean
          return ["(#{@column} IS NULL OR #{@column} = ?)", false] if %w(false f 0).include?(@value)
          return ["(#{@column} = ?)", true] if %w(true t 1).include?(@value)
        end

        def column_for_value(value)
          ["(#{@column} = ?)", value]
        end

        def build_statement_for_belongs_to_association
          return if @value.blank?
          ["(#{@column} = ?)", @value.to_i] if @value.to_i.to_s == @value
        end

        def build_statement_for_string_or_text
          return if @value.blank?

          return ["(#{@column} = ?)", @value] if ['is', '='].include?(@operator)

          unless ['postgresql', 'postgis'].include? ar_adapter
            @value = @value.mb_chars.downcase
          end

          @value = begin
            case @operator
            when 'default', 'like'
              "%#{@value}%"
            when 'starts_with'
              "#{@value}%"
            when 'ends_with'
              "%#{@value}"
            else
              return
            end
          end

          if ['postgresql', 'postgis'].include? ar_adapter
            ["(#{@column} ILIKE ?)", @value]
          else
            ["(LOWER(#{@column}) LIKE ?)", @value]
          end
        end

        def build_statement_for_enum
          return if @value.blank?
          ["(#{@column} IN (?))", Array.wrap(@value)]
        end

        def build_statement_for_uuid
          if @value.to_s =~ /\A[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}\z/
            column_for_value(@value)
          end
        end

        def build_statement_for_fulltext_indexed
          return if @value.blank?

          table_name, column_name = @column.split('.')
          model = table_name.classify.constantize
          index_exists = model.connection.index_exists?(table_name, column_name, type: :fulltext)

          # Use MATCH conditions only for MySQL queries that would normally use LIKE conditions if a fulltext index exists
          if %w[mysql mysql2].include?(ar_adapter) && %w[default like].include?(@operator) && index_exists
            ["(MATCH (#{@column}) AGAINST (? IN BOOLEAN MODE))", @value]
          else
            build_statement_for_string_or_text
          end
        end

        def ar_adapter
          @adapter_name.downcase
        end
      end
    end
  end
end
