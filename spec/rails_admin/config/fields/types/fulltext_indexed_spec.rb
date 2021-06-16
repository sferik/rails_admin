require 'spec_helper'

RSpec.describe RailsAdmin::Config::Fields::Types::FulltextIndexed do
  it_behaves_like 'a string-like field type', :string_field
end
