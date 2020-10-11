module RailsAdmin
  module Config
    module Inspectable
      def inspect
        set_named_instance_variables

        instance_name = try(:name) || try(:abstract_model).try(:model).try(:name)
        instance_name = instance_name ? "[#{instance_name}]" : ''

        instance_vars = instance_variables.collect do |v|
          instance_variable_name(v)
        end.join(', ')

        "#<#{self.class.name}#{instance_name} #{instance_vars}>"
      end

    private

      def instance_variable_name(variable)
        value = instance_variable_get(variable)
        if self.class::NAMED_INSTANCE_VARIABLES.include?(variable)
          if value.respond_to?(:name)
            "#{variable}=#{value.name.inspect}"
          else
            "#{variable}=#{value.class.name}"
          end
        else
          "#{variable}=#{value.inspect}"
        end
      end

      def set_named_instance_variables
        self.class.const_set('NAMED_INSTANCE_VARIABLES', []) unless defined?(self.class::NAMED_INSTANCE_VARIABLES)
      end
    end
  end
end
