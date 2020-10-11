module RailsAdmin
  module Bootstrap
    class FrameworkNotFound < StandardError; end

    # Inspired by Kaminari
    def self.load!
      if compass?
        require 'rails_admin/bootstrap-sass/compass_functions'
        register_compass_extension
      elsif asset_pipeline?
        require 'rails_admin/bootstrap-sass/sass_functions'
      end

      require 'sassc-rails' if rails?

      raise(Bootstrap::FrameworkNotFound.new('bootstrap-sass requires either Rails > 3.1 or Compass, neither of which are loaded')) unless rails? || compass?

      return unless defined?(::Sass)
      return unless ::Sass.respond_to?(:load_paths)

      stylesheets = File.expand_path(File.join('..', 'vendor', 'assets', 'stylesheets'))
      fonts = File.expand_path(File.join('..', 'vendor', 'assets', 'fonts'))
      ::Sass.load_paths << stylesheets
      ::Sass.load_paths << fonts
    end

    def self.asset_pipeline?
      defined?(::Sprockets)
    end

    def self.compass?
      defined?(::Compass)
    end

    def self.rails?
      defined?(::Rails)
    end

    def self.register_compass_extension
      base = File.join(File.dirname(__FILE__), '..')
      styles = File.join(base, 'vendor', 'assets', 'stylesheets')
      templates = File.join(base, 'templates')
      ::Compass::Frameworks.register('bootstrap', path: base, stylesheets_directory: styles, templates_directory: templates)
    end
  end
end

RailsAdmin::Bootstrap.load!
