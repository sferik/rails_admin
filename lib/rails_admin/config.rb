require 'rails_admin/config/lazy_model'
require 'rails_admin/config/sections/list'
require 'active_support/core_ext/module/attribute_accessors'

module RailsAdmin
  module Config
    # RailsAdmin is setup to try and authenticate with warden
    # If warden is found, then it will try to authenticate
    #
    # This is valid for custom warden setups, and also devise
    # If you're using the admin setup for devise, you should set RailsAdmin to use the admin
    #
    # @see RailsAdmin::Config.authenticate_with
    # @see RailsAdmin::Config.authorize_with
    DEFAULT_AUTHENTICATION = proc {}

    DEFAULT_AUTHORIZE = proc {}

    DEFAULT_AUDIT = proc {}

    DEFAULT_CURRENT_USER = proc {}

    class << self
      # Application title, can be an array of two elements
      attr_accessor :main_app_name

      # Configuration option to specify which models you want to exclude.
      attr_accessor :excluded_models

      # Configuration option to specify a whitelist of models you want to RailsAdmin to work with.
      # The excluded_models list applies against the whitelist as well and further reduces the models
      # RailsAdmin will use.
      # If included_models is left empty ([]), then RailsAdmin will automatically use all the models
      # in your application (less any excluded_models you may have specified).
      attr_accessor :included_models

      # Fields to be hidden in show, create and update views
      attr_accessor :default_hidden_fields

      # Default items per page value used if a model level option has not
      # been configured
      attr_accessor :default_items_per_page

      # Default association limit
      attr_accessor :default_associated_collection_limit

      attr_reader :default_search_operator

      # Configuration option to specify which method names will be searched for
      # to be used as a label for object records. This defaults to [:name, :title]
      attr_accessor :label_methods

      # hide blank fields in show view if true
      attr_accessor :compact_show_view

      # Tell browsers whether to use the native HTML5 validations (novalidate form option).
      attr_accessor :browser_validations

      # Set the max width of columns in list view before a new set is created
      attr_accessor :total_columns_width

      # Enable horizontal-scrolling table in list view, ignore total_columns_width
      attr_accessor :sidescroll

      # Enable Collapsible Scroll Bar to make long sidebar menu manageable
      attr_accessor :collapsible_sidebar

      # set parent controller
      attr_accessor :parent_controller

      # set settings for `protect_from_forgery` method
      # By default, it raises exception upon invalid CSRF tokens
      attr_accessor :forgery_protection_settings

      # Stores model configuration objects in a hash identified by model's class
      # name.
      #
      # @see RailsAdmin.config
      attr_reader :registry

      # show Gravatar in Navigation bar
      attr_accessor :show_gravatar

      # accepts a hash of static links to be shown below the main navigation
      attr_accessor :navigation_static_links
      attr_accessor :navigation_static_label

      # Setup authentication to be run as a before filter
      # This is run inside the controller instance so you can setup any authentication you need to
      #
      # By default, the authentication will run via warden if available
      # and will run the default.
      #
      # If you use devise, this will authenticate the same as _authenticate_user!_
      #
      # @example Devise admin
      #   RailsAdmin.config do |config|
      #     config.authenticate_with do
      #       authenticate_admin!
      #     end
      #   end
      #
      # @example Custom Warden
      #   RailsAdmin.config do |config|
      #     config.authenticate_with do
      #       warden.authenticate! scope: :paranoid
      #     end
      #   end
      #
      # @see RailsAdmin::Config::DEFAULT_AUTHENTICATION
      def authenticate_with(&blk)
        @authenticate = blk if blk
        @authenticate || DEFAULT_AUTHENTICATION
      end

      # Setup auditing/history/versioning provider that observe objects lifecycle
      def audit_with(*args, &block)
        extension = args.shift
        if extension
          klass = RailsAdmin::AUDITING_ADAPTERS[extension]
          klass.setup if klass.respond_to? :setup
          @audit = proc do
            @auditing_adapter = klass.new(*([self] + args).compact)
          end
        elsif block
          @audit = block
        end
        @audit || DEFAULT_AUDIT
      end

      # Setup authorization to be run as a before filter
      # This is run inside the controller instance so you can setup any authorization you need to.
      #
      # By default, there is no authorization.
      #
      # @example Custom
      #   RailsAdmin.config do |config|
      #     config.authorize_with do
      #       redirect_to root_path unless warden.user.is_admin?
      #     end
      #   end
      #
      # To use an authorization adapter, pass the name of the adapter. For example,
      # to use with CanCanCan[https://github.com/CanCanCommunity/cancancan/], pass it like this.
      #
      # @example CanCanCan
      #   RailsAdmin.config do |config|
      #     config.authorize_with :cancancan
      #   end
      #
      # See the wiki[https://github.com/sferik/rails_admin/wiki] for more on authorization.
      #
      # @see RailsAdmin::Config::DEFAULT_AUTHORIZE
      def authorize_with(*args, &block)
        extension = args.shift
        if extension
          klass = RailsAdmin::AUTHORIZATION_ADAPTERS[extension]
          klass.setup if klass.respond_to? :setup
          @authorize = proc do
            @authorization_adapter = klass.new(*([self] + args).compact)
          end
        elsif block
          @authorize = block
        end
        @authorize || DEFAULT_AUTHORIZE
      end

      # Setup configuration using an extension-provided ConfigurationAdapter
      #
      # @example Custom configuration for role-based setup.
      #   RailsAdmin.config do |config|
      #     config.configure_with(:custom) do |config|
      #       config.models = ['User', 'Comment']
      #       config.roles  = {
      #         'Admin' => :all,
      #         'User'  => ['User']
      #       }
      #     end
      #   end
      def configure_with(extension)
        configuration = RailsAdmin::CONFIGURATION_ADAPTERS[extension].new
        yield(configuration) if block_given?
      end

      # Setup a different method to determine the current user or admin logged in.
      # This is run inside the controller instance and made available as a helper.
      #
      # By default, _request.env["warden"].user_ or _current_user_ will be used.
      #
      # @example Custom
      #   RailsAdmin.config do |config|
      #     config.current_user_method do
      #       current_admin
      #     end
      #   end
      #
      # @see RailsAdmin::Config::DEFAULT_CURRENT_USER
      def current_user_method(&block)
        @current_user = block if block
        @current_user || DEFAULT_CURRENT_USER
      end

      def default_search_operator=(operator)
        if %w(default like starts_with ends_with is =).include? operator
          @default_search_operator = operator
        else
          raise(ArgumentError.new("Search operator '#{operator}' not supported"))
        end
      end

      # pool of all found model names from the whole application
      def models_pool
        (viable_models - excluded_models.collect(&:to_s)).uniq.sort
      end

      # Loads a model configuration instance from the registry or registers
      # a new one if one is yet to be added.
      #
      # First argument can be an instance of requested model, its class object,
      # its class name as a string or symbol or a RailsAdmin::AbstractModel
      # instance.
      #
      # If a block is given it is evaluated in the context of configuration instance.
      #
      # Returns given model's configuration
      #
      # @see RailsAdmin::Config.registry
      def model(entity, &block)
        key = begin
          if entity.is_a?(RailsAdmin::AbstractModel)
            entity.model.try(:name).try :to_sym
          elsif entity.is_a?(Class)
            entity.name.to_sym
          elsif entity.is_a?(String) || entity.is_a?(Symbol)
            entity.to_sym
          else
            entity.class.name.to_sym
          end
        end

        @registry[key] ||= RailsAdmin::Config::LazyModel.new(entity)
        @registry[key].add_deferred_block(&block) if block
        @registry[key]
      end

      def default_hidden_fields=(fields)
        if fields.is_a?(Array)
          @default_hidden_fields = {}
          @default_hidden_fields[:edit] = fields
          @default_hidden_fields[:show] = fields
        else
          @default_hidden_fields = fields
        end
      end

      # Returns action configuration object
      def actions(&block)
        RailsAdmin::Config::Actions.instance_eval(&block) if block
      end

      # Returns all model configurations
      #
      # @see RailsAdmin::Config.registry
      def models
        RailsAdmin::AbstractModel.all.collect { |m| model(m) }
      end

      # Reset all configurations to defaults.
      #
      # @see RailsAdmin::Config.registry
      def reset
        @compact_show_view = true
        @browser_validations = true
        @authenticate = nil
        @authorize = nil
        @audit = nil
        @current_user = nil
        @default_hidden_fields = {}
        @default_hidden_fields[:base] = [:_type]
        @default_hidden_fields[:edit] = [:id, :_id, :created_at, :created_on, :deleted_at, :updated_at, :updated_on, :deleted_on]
        @default_hidden_fields[:show] = [:id, :_id, :created_at, :created_on, :deleted_at, :updated_at, :updated_on, :deleted_on]
        @default_items_per_page = 20
        @default_associated_collection_limit = 100
        @default_search_operator = 'default'
        @excluded_models = []
        @included_models = []
        @total_columns_width = 697
        @sidescroll = nil
        @collapsible_sidebar = false
        @label_methods = [:name, :title]
        @main_app_name = proc { [Rails.application.engine_name.titleize.chomp(' Application'), 'Admin'] }
        @registry = {}
        @show_gravatar = true
        @navigation_static_links = {}
        @navigation_static_label = nil
        @parent_controller = '::ActionController::Base'
        @forgery_protection_settings = {with: :exception}
        RailsAdmin::Config::Actions.reset
      end

      # Reset a provided model's configuration.
      #
      # @see RailsAdmin::Config.registry
      def reset_model(model)
        key = model.is_a?(Class) ? model.name.to_sym : model.to_sym
        @registry.delete(key)
      end

      # Reset all models configuration
      # Used to clear all configurations when reloading code in development.
      # @see RailsAdmin::Engine
      # @see RailsAdmin::Config.registry
      def reset_all_models
        @registry = {}
      end

      # Get all models that are configured as visible sorted by their weight and label.
      #
      # @see RailsAdmin::Config::Hideable

      def visible_models(bindings)
        visible_models_with_bindings(bindings).sort do |a, b|
          if (weight_order = a.weight <=> b.weight) == 0
            a.label.downcase <=> b.label.downcase
          else
            weight_order
          end
        end
      end

    private

      def lchomp(base, arg)
        base.to_s.reverse.chomp(arg.to_s.reverse).reverse
      end

      def viable_models
        included_models.collect(&:to_s).presence || begin
          @@system_models ||= # memoization for tests
            ([Rails.application] + Rails::Engine.subclasses.collect(&:instance)).flat_map do |app|
              (app.paths['app/models'].to_a + app.paths.eager_load).collect do |load_path|
                Dir.glob(app.root.join(load_path)).collect do |load_dir|
                  Dir.glob(load_dir + '/**/*.rb').collect do |filename|
                    # app/models/module/class.rb => module/class.rb => module/class => Module::Class
                    lchomp(filename, "#{app.root.join(load_dir)}/").chomp('.rb').camelize
                  end
                end
              end
            end.flatten.reject { |m| m.starts_with?('Concerns::') } # rubocop:disable Style/MultilineBlockChain
        end
      end

      def visible_models_with_bindings(bindings)
        models.collect { |m| m.with(bindings) }.select do |m|
          m.visible? &&
            RailsAdmin::Config::Actions.find(:index, bindings.merge(abstract_model: m.abstract_model)).try(:authorized?) &&
            (!m.abstract_model.embedded? || m.abstract_model.cyclic?)
        end
      end
    end

    # Set default values for configuration options on load
    reset
  end
end
