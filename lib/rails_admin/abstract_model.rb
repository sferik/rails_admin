require 'rails_admin/support/datetime'

module RailsAdmin
  class AbstractModel
    cattr_accessor :all
    attr_reader :adapter, :model_name

    class << self
      def reset
        @@all = nil
      end

      def all(adapter = nil)
        @@all ||= Config.models_pool.collect { |m| new(m) }.compact
        adapter ? @@all.select { |m| m.adapter == adapter } : @@all
      end

      alias_method :old_new, :new
      def new(m)
        m = m.constantize unless m.is_a?(Class)
        (am = old_new(m)).model && am.adapter ? am : nil
      rescue LoadError, NameError
        puts "[RailsAdmin] Could not load model #{m}, assuming model is non existing. (#{$ERROR_INFO})" unless Rails.env.test?
        nil
      end

      @@polymorphic_parents = {}

      def polymorphic_parents(adapter, model_name, name)
        @@polymorphic_parents[adapter.to_sym] ||= {}.tap do |hash|
          all(adapter).each do |am|
            am.associations.select(&:as).each do |association|
              (hash[[association.klass.to_s.underscore, association.as].join('_').to_sym] ||= []) << am.model
            end
          end
        end
        @@polymorphic_parents[adapter.to_sym][[model_name.to_s.underscore, name].join('_').to_sym]
      end

      # For testing
      def reset_polymorphic_parents
        @@polymorphic_parents = {}
      end
    end

    def initialize(model_or_model_name)
      @model_name = model_or_model_name.to_s
      ancestors = model.ancestors.collect(&:to_s)
      if ancestors.include?('ActiveRecord::Base') && !model.abstract_class? && model.table_exists?
        initialize_active_record
      elsif ancestors.include?('Mongoid::Document')
        initialize_mongoid
      end
    end

    # do not store a reference to the model, does not play well with ActiveReload/Rails3.2
    def model
      @model_name.constantize
    end

    def to_s
      model.to_s
    end

    def config
      Config.model self
    end

    def to_param
      @model_name.split('::').collect(&:underscore).join('~')
    end

    def param_key
      @model_name.split('::').collect(&:underscore).join('_')
    end

    def pretty_name
      model.model_name.human
    end

    def where(conditions)
      model.where(conditions)
    end

    def each_associated_children(object)
      associations.each do |association|
        case association.type
        when :has_one
          if child = object.send(association.name)
            yield(association, [child])
          end
        when :has_many
          children = object.send(association.name)
          yield(association, Array.new(children))
        end
      end
    end

  private

    def initialize_active_record
      @adapter = :active_record
      require 'rails_admin/adapters/active_record'
      extend Adapters::ActiveRecord
    end

    def initialize_mongoid
      @adapter = :mongoid
      require 'rails_admin/adapters/mongoid'
      extend Adapters::Mongoid
    end

    def parse_field_value(field, value)
      value.is_a?(Array) ? value.map { |v| field.parse_value(v) } : field.parse_value(value)
    end

    class StatementBuilder
      def initialize(column, type, value, operator)
        @column = column
        @type = type
        @value = value
        @operator = operator
      end

      def to_statement
        return if [@operator, @value].any? { |v| v == '_discard' }

        unary_operators[@operator] || unary_operators[@value] ||
          build_statement_for_type_generic
      end

    protected

      def get_filtering_duration
        FilteringDuration.new(@operator, @value).get_duration
      end

      def build_statement_for_type_generic
        build_statement_for_type || begin
          case @type
          when :date
            build_statement_for_date
          when :datetime, :timestamp
            build_statement_for_datetime_or_timestamp
          end
        end
      end

      def build_statement_for_type
        raise('You must override build_statement_for_type in your StatementBuilder')
      end

      def build_statement_for_integer_decimal_or_float
        case @value
        when Array then
          val, range_begin, range_end = *@value.collect do |v|
            next unless [v.to_i.to_s, v.to_f.to_s].include?(v)

            @type == :integer ? v.to_i : v.to_f
          end
          case @operator
          when 'between'
            range_filter(range_begin, range_end)
          else
            column_for_value(val) if val
          end
        else
          if @value.to_i.to_s == @value || @value.to_f.to_s == @value
            @type == :integer ? column_for_value(@value.to_i) : column_for_value(@value.to_f)
          end
        end
      end

      def build_statement_for_date
        start_date, end_date = get_filtering_duration
        if start_date
          start_date = (begin
                          start_date.to_date
                        rescue StandardError
                          nil
                        end)
        end
        if end_date
          end_date = (begin
                        end_date.to_date
                      rescue StandardError
                        nil
                      end)
        end
        range_filter(start_date, end_date)
      end

      def build_statement_for_datetime_or_timestamp
        start_date, end_date = get_filtering_duration
        start_date = start_date.try(:beginning_of_day) if start_date
        end_date = end_date.try(:end_of_day) if end_date
        range_filter(start_date, end_date)
      end

      def unary_operators
        raise('You must override unary_operators in your StatementBuilder')
      end

      def range_filter(_min, _max)
        raise('You must override range_filter in your StatementBuilder')
      end

      class FilteringDuration
        def initialize(operator, value)
          @value = value
          @operator = operator
        end

        def get_duration
          case @operator
          when 'between'   then between
          when 'today'     then today
          when 'yesterday' then yesterday
          when 'this_week' then this_week
          when 'last_week' then last_week
          else default
          end
        end

        def today
          [Date.today, Date.today]
        end

        def yesterday
          [Date.yesterday, Date.yesterday]
        end

        def this_week
          [Date.today.beginning_of_week, Date.today.end_of_week]
        end

        def last_week
          [1.week.ago.to_date.beginning_of_week,
           1.week.ago.to_date.end_of_week]
        end

        def between
          [@value[1], @value[2]]
        end

        def default
          [default_date, default_date]
        end

      private

        def default_date
          Array.wrap(@value).first
        end
      end
    end
  end
end
