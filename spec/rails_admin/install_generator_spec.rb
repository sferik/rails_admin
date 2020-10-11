require 'spec_helper'
require 'generators/rails_admin/install_generator'

RSpec.describe RailsAdmin::InstallGenerator, type: :generator do
  destination File.expand_path('../dummy_app/tmp/generator', __dir__)
  arguments ['admin']

  before do
    prepare_destination
  end

  it 'mounts RailsAdmin as Engine and generates RailsAdmin Initializer' do
    expect_any_instance_of(generator_class).to receive(:route).
      with("mount RailsAdmin::Engine => '/admin', as: 'rails_admin'")
    silence_stream(STDOUT) do
      generator.invoke('install')
    end
    expect(destination_root).to have_structure {
      directory 'config' do
        directory 'initializers' do
          file 'rails_admin.rb' do
            contains 'RailsAdmin.config'
          end
        end
      end
    }
  end
end
