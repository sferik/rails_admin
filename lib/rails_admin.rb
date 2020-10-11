require 'rails_admin/engine'
require 'rails_admin/abstract_model'
require 'rails_admin/config'
require 'rails_admin/extension'
require 'rails_admin/extensions/cancancan'
require 'rails_admin/extensions/pundit'
require 'rails_admin/extensions/paper_trail'
require 'rails_admin/extensions/history'
require 'rails_admin/support/csv_converter'
require 'rails_admin/support/hash_helper'
require 'yaml'

module RailsAdmin
  # Setup RailsAdmin
  #
  # Given the first argument is a model class, a model class name
  # or an abstract model object proxies to model configuration method.
  #
  # If only a block is passed it is stored to initializer stack to be evaluated
  # on first request in production mode and on each request in development. If
  # initialization has already occured (in other words RailsAdmin.setup has
  # been called) the block will be added to stack and evaluated at once.
  #
  # Otherwise returns RailsAdmin::Config class.
  #
  # @see RailsAdmin::Config
  def self.config(entity = nil, &block)
    if entity
      RailsAdmin::Config.model(entity, &block)
    elsif block_given?
      block.call(RailsAdmin::Config)
    else
      RailsAdmin::Config
    end
  end

  # Backwards-compatible with safe_yaml/load when SafeYAML isn't available.
  # Evaluates available YAML loaders at boot and creates appropriate method,
  # so no conditionals are required at runtime.
  begin
    require 'safe_yaml/load'
    def self.yaml_load(yaml)
      SafeYAML.load(yaml)
    end
  rescue LoadError
    raise LoadError.new "Safe-loading of YAML is not available. Please install 'safe_yaml' or install Psych 2.0+" unless YAML.respond_to?(:safe_load)

    def self.yaml_load(yaml) # rubocop:disable Lint/DuplicateMethods
      YAML.safe_load(yaml)
    end
  end

  def self.yaml_dump(object)
    YAML.dump(object)
  end
end

require 'rails_admin/bootstrap-sass' unless defined? Bootstrap
