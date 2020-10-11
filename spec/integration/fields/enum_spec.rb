require 'spec_helper'

RSpec.describe 'Enum field', type: :request, active_record: true do
  subject { page }

  describe "when object responds to '\#{method}_enum'" do
    before do
      Team.class_eval do
        def color_enum
          %w[blue green red]
        end
      end
      RailsAdmin.config Team do
        edit do
          field :color
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.send(:remove_method, :color_enum)
    end

    it 'auto-detects enumeration' do
      is_expected.to have_selector('.enum_type select')
      is_expected.not_to have_selector('.enum_type select[multiple]')
      expect(all('.enum_type option').map(&:text).select(&:present?)).to eq %w[blue green red]
    end
  end

  describe "when class responds to '\#{method}_enum'" do
    before do
      Team.instance_eval do
        def color_enum
          %w[blue green red]
        end
      end
      RailsAdmin.config Team do
        edit do
          field :color
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.instance_eval { undef :color_enum }
    end

    it 'auto-detects enumeration' do
      is_expected.to have_selector('.enum_type select')
      is_expected.to have_content('green')
    end
  end

  describe 'the enum instance method' do
    before do
      Team.class_eval do
        def color_list
          %w[blue green red]
        end
      end
      RailsAdmin.config Team do
        edit do
          field :color, :enum do
            enum_method :color_list
          end
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.send(:remove_method, :color_list)
    end

    it 'allows configuration' do
      is_expected.to have_selector('.enum_type select')
      is_expected.to have_content('green')
    end
  end

  describe 'the enum class method' do
    before do
      Team.instance_eval do
        def color_list
          %w[blue green red]
        end
      end
      RailsAdmin.config Team do
        edit do
          field :color, :enum do
            enum_method :color_list
          end
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.instance_eval { undef :color_list }
    end

    it 'allows configuration' do
      is_expected.to have_selector('.enum_type select')
      is_expected.to have_content('green')
    end
  end

  describe 'when overriding enum configuration' do
    before do
      Team.class_eval do
        def color_list
          %w[blue green red]
        end
      end
      RailsAdmin.config Team do
        edit do
          field :color, :enum do
            enum_method :color_list
            enum do
              %w[yellow black]
            end
          end
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.send(:remove_method, :color_list)
    end

    it 'allows direct listing of enumeration options and override enum method' do
      is_expected.to have_selector('.enum_type select')
      is_expected.to have_no_content('green')
      is_expected.to have_content('yellow')
    end
  end

  describe 'when serialize is enabled in ActiveRecord model', active_record: true do
    before do
      # ActiveRecord 4.2 momoizes result of serialized_attributes, so we have to clear it.
      Team.remove_instance_variable(:@serialized_attributes) if Team.instance_variable_defined?(:@serialized_attributes)
      Team.instance_eval do
        serialize :color
        def color_enum
          %w[blue green red]
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.reset_column_information
      Team.attribute_type_decorations.clear
      Team.instance_eval { undef :color_enum }
    end

    it 'makes enumeration multi-selectable' do
      is_expected.to have_selector('.enum_type select[multiple]')
    end
  end

  describe 'when serialize is enabled in Mongoid model', mongoid: true do
    before do
      Team.instance_eval do
        field :color, type: Array
        def color_enum
          %w[blue green red]
        end
      end
      visit new_path(model_name: 'team')
    end

    after do
      Team.instance_eval do
        field :color, type: String
        undef :color_enum
      end
    end

    it 'makes enumeration multi-selectable' do
      is_expected.to have_selector('.enum_type select[multiple]')
    end
  end
end
