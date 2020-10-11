require 'haml'
require 'haml/template'
Haml::Template.options[:ugly] = true if Haml::Options.buffer_option_keys.include?(:ugly)
