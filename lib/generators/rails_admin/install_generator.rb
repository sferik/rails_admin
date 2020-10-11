require 'rails/generators'
require File.expand_path('utils', __dir__)

module RailsAdmin
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)
    include Generators::Utils::InstanceMethods

    argument :_namespace, type: :string, required: false, desc: 'RailsAdmin url namespace'
    desc 'RailsAdmin installation generator'

    def install
      namespace = ask_for('Where do you want to mount rails_admin?', 'admin', _namespace)
      route("mount RailsAdmin::Engine => '/#{namespace}', as: 'rails_admin'")
      template 'initializer.erb', 'config/initializers/rails_admin.rb'
    end
  end
end
