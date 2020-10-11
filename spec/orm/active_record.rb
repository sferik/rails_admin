require 'rails_admin/extensions/history/history'
require 'rails_admin/adapters/active_record'

DatabaseCleaner.strategy = :transaction

ActiveRecord::Base.connection.data_sources.each do |table|
  ActiveRecord::Base.connection.drop_table(table)
end

def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
  old_stream.close
end

silence_stream(STDOUT) do
  if ActiveRecord::Migrator.respond_to? :migrate
    ActiveRecord::Migrator.migrate File.expand_path('../dummy_app/db/migrate', __dir__)
  else
    ActiveRecord::MigrationContext.new(
      *([File.expand_path('../dummy_app/db/migrate', __dir__)] +
          (ActiveRecord::MigrationContext.instance_method(:initialize).arity == 2 ? [ActiveRecord::SchemaMigration] : [])),
    ).migrate
  end
end

class Tableless < ActiveRecord::Base
  class <<self
    def load_schema
      # do nothing
    end

    def columns
      @columns ||= []
    end

    def column(name, sql_type = nil, default = nil, null = true)
      define_attribute(name.to_s,
                       connection.send(:lookup_cast_type, sql_type.to_s))
      columns <<
        ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, connection.send(:lookup_cast_type, sql_type.to_s), sql_type.to_s, null)
    end

    def columns_hash
      @columns_hash ||= Hash[columns.collect { |column| [column.name, column] }]
    end

    def column_names
      @column_names ||= columns.collect(&:name)
    end

    def column_defaults
      @column_defaults ||= columns.collect { |column| [column.name, nil] }.each_with_object({}) do |e, a|
        a[e[0]] = e[1]
        a
      end
    end

    def attribute_types
      @attribute_types ||=
        Hash[columns.collect { |column| [column.name, lookup_attribute_type(column.type)] }]
    end

    def table_exists?
      true
    end

    def primary_key
      'id'
    end

  private

    def lookup_attribute_type(type)
      ActiveRecord::Type.lookup({datetime: :time}[type] || type)
    end
  end

  # Override the save method to prevent exceptions.
  def save(validate = true)
    validate ? valid? : true
  end
end

##
# Column length detection seems to be broken for PostgreSQL.
# This is a workaround..
# Refs. https://github.com/rails/rails/commit/b404613c977a5cc31c6748723e903fa5a0709c3b
#
if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    def lookup_cast_type(sql_type)
      oid = execute("SELECT #{quote(sql_type)}::regtype::oid", 'SCHEMA').first['oid'].to_i
      type_map.lookup(oid, sql_type)
    end
  end
end
