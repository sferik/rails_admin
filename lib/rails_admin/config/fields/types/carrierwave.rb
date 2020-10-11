require 'rails_admin/config/fields/base'
require 'rails_admin/config/fields/types/file_upload'

module RailsAdmin
  module Config
    module Fields
      module Types
        class Carrierwave < RailsAdmin::Config::Fields::Types::FileUpload
          RailsAdmin::Config::Fields::Types.register(self)

          register_instance_option :thumb_method do
            @thumb_method ||= ((versions = bindings[:object].send(name).versions.keys).detect { |k| k.in?([:thumb, :thumbnail, 'thumb', 'thumbnail']) } || versions.first.to_s)
          end

          register_instance_option :delete_method do
            "remove_#{name}"
          end

          register_instance_option :cache_method do
            "#{name}_cache"
          end

          def resource_url(thumb = false)
            return nil unless (uploader = bindings[:object].send(name)).present?

            thumb.present? ? uploader.send(thumb).url : uploader.url
          end
        end
      end
    end
  end
end
