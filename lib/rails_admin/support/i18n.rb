require 'i18n'

module RailsAdmin
  module Support
    module I18n
      def abbr_day_names
        ::I18n.t('date.abbr_day_names', raise: true)
      rescue ::I18n::ArgumentError
        %w[Sun Mon Tue Wed Thu Fri Sat]
      end

      def abbr_month_names
        begin
          names = ::I18n.t('date.abbr_month_names', raise: true)
        rescue ::I18n::ArgumentError
          names = [nil, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        end
        names[1..-1]
      end

      def date_format
        ::I18n.t('date.formats.default', raise: true)
      rescue StandardError
        '%Y-%m-%d'
      end

      def day_names
        ::I18n.t('date.day_names', raise: true)
      rescue ::I18n::ArgumentError
        %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
      end

      def month_names
        begin
          names = ::I18n.t('date.month_names', raise: true)
        rescue ::I18n::ArgumentError
          names = [nil, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
        end
        names[1..-1]
      end
    end
  end
end
