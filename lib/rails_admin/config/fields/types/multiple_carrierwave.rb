require 'rails_admin/config/fields/types/multiple_file_upload'

module RailsAdmin
  module Config
    module Fields
      module Types
        class MultipleCarrierwave < RailsAdmin::Config::Fields::Types::MultipleFileUpload
          RailsAdmin::Config::Fields::Types.register(self)

          class CarrierwaveAttachment < RailsAdmin::Config::Fields::Types::MultipleFileUpload::AbstractAttachment
            register_instance_option :thumb_method do
              @thumb_method ||= ((versions = value.versions.keys).detect { |k| k.in?([:thumb, :thumbnail, 'thumb', 'thumbnail']) } || versions.first.to_s)
            end

            register_instance_option :keep_value do
              value.cache_name || value.identifier
            end

            register_instance_option :delete_value do
              value.file.filename
            end

            def resource_url(thumb = false)
              return nil unless value

              thumb.present? ? value.send(thumb).url : value.url
            end
          end

          register_instance_option :attachment_class do
            CarrierwaveAttachment
          end

          register_instance_option :cache_method do
            "#{name}_cache" unless ::CarrierWave::VERSION >= '2'
          end

          register_instance_option :keep_method do
            name if ::CarrierWave::VERSION >= '2'
          end

          register_instance_option :reorderable? do
            ::CarrierWave::VERSION >= '2'
          end

          register_instance_option :delete_method do
            "delete_#{name}" if bindings[:object].respond_to?("delete_#{name}")
          end

          def value
            bindings[:object].send(name)
          end
        end
      end
    end
  end
end
