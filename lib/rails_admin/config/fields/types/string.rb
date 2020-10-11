require 'rails_admin/config/fields/types/string_like'

module RailsAdmin
  module Config
    module Fields
      module Types
        class String < StringLike
          RailsAdmin::Config::Fields::Types.register(self)

          def input_size
            [50, length.to_i].reject(&:zero?).min
          end

          register_instance_option :html_attributes do
            {
              required: required?,
              maxlength: length,
              size: input_size,
            }
          end

          def generic_help
            text = (required? ? I18n.translate('admin.form.required') : I18n.translate('admin.form.optional')) + '. '
            if valid_length.present? && valid_length[:is].present?
              text += "#{I18n.translate('admin.form.char_length_of').capitalize} #{valid_length[:is]}."
            else
              max_length = [length, valid_length[:maximum] || nil].compact.min
              min_length = [0, valid_length[:minimum] || nil].compact.max
              if max_length
                text +=
                  if min_length.zero?
                    "#{I18n.translate('admin.form.char_length_up_to').capitalize} #{max_length}."
                  else
                    "#{I18n.translate('admin.form.char_length_of').capitalize} #{min_length}-#{max_length}."
                  end
              end
            end
            text
          end

          register_instance_option :partial do
            :form_field
          end
        end
      end
    end
  end
end
