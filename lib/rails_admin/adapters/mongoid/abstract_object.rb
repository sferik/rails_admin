require 'rails_admin/adapters/active_record/abstract_object'

module RailsAdmin
  module Adapters
    module Mongoid
      class AbstractObject < RailsAdmin::Adapters::ActiveRecord::AbstractObject
        def initialize(object)
          super
          object.associations.each do |name, association|
            association = Association.new(association, object.class)
            if %i[has_many references_many].include? association.macro
              instance_eval <<-RUBY, __FILE__, __LINE__ + 1
                def #{name.to_s.singularize}_ids
                  #{name}.map{|item| item.id }
                end

                def #{name.to_s.singularize}_ids=(item_ids)
                  __items__ = Array.wrap(item_ids).map{|item_id| #{name}.klass.find(item_id) rescue nil }.compact
                  unless persisted?
                    __items__.each do |item|
                      item.update_attribute('#{association.foreign_key}', id)
                    end
                  end
                  super __items__.map(&:id)
                end
              RUBY
            elsif %i[has_one references_one].include? association.macro
              instance_eval <<-RUBY, __FILE__, __LINE__ + 1
                def #{name}_id=(item_id)
                  item = (#{association.klass}.find(item_id) rescue nil)
                  return unless item
                  item.update_attribute('#{association.foreign_key}', id) unless persisted?
                  super item.id
                end
              RUBY
            end
          end
        end
      end
    end
  end
end
