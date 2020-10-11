require 'active_support/core_ext/string/strip'

module RailsAdmin
  module Extensions
    module PaperTrail
      class VersionProxy
        def initialize(version, user_class = User)
          @version = version
          @user_class = user_class
        end

        def message
          @message = @version.event
          @version.respond_to?(:changeset) && @version.changeset.present? ? @message + ' [' + @version.changeset.to_a.collect { |c| c[0] + ' = ' + c[1][1].to_s }.join(', ') + ']' : @message
        end

        def created_at
          @version.created_at
        end

        def table
          @version.item_type
        end

        def username
          (begin
             @user_class.find(@version.whodunnit).try(:email)
           rescue StandardError
             nil
           end) || @version.whodunnit
        end

        def item
          @version.item_id
        end
      end

      module ControllerExtension
        def user_for_paper_trail
          _current_user.try(:id) || _current_user
        end
      end

      class AuditingAdapter
        COLUMN_MAPPING = {
          table: :item_type,
          username: :whodunnit,
          item: :item_id,
          created_at: :created_at,
          message: :event,
        }.freeze
        E_VERSION_MODEL_NOT_SET = <<-EOS.strip_heredoc.freeze
          Please set up PaperTrail's version model explicitly.

              config.audit_with :paper_trail, 'User', 'PaperTrail::Version'

          If you have configured a model to use a custom version class
          (https://github.com/paper-trail-gem/paper_trail#6a-custom-version-classes)
          that configuration will take precedence over what you specify in
          `audit_with`.
        EOS

        def self.setup
          raise('PaperTrail not found') unless defined?(::PaperTrail)

          RailsAdmin::Extensions::ControllerExtension.include ControllerExtension
        end

        def initialize(controller, user_class = 'User', version_class = '::Version')
          @controller = controller
          @controller.send(:set_paper_trail_whodunnit) if @controller
          begin
            @user_class = user_class.to_s.constantize
          rescue NameError
            raise "Please set up Papertrail's user model explicitly. Ex: config.audit_with :paper_trail, 'User'"
          end

          begin
            @version_class = version_class.to_s.constantize
          rescue NameError
            raise E_VERSION_MODEL_NOT_SET
          end
        end

        def latest(count = 100)
          @version_class.
            order(id: :desc).includes(:item).limit(count).
            collect { |version| VersionProxy.new(version, @user_class) }
        end

        def delete_object(_object, _model, _user)
          # do nothing
        end

        def update_object(_object, _model, _user, _changes)
          # do nothing
        end

        def create_object(_object, _abstract_model, _user)
          # do nothing
        end

        def listing_for_model(model, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
          listing_for_model_or_object(model, nil, query, sort, sort_reverse, all, page, per_page)
        end

        def listing_for_object(model, object, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
          listing_for_model_or_object(model, object, query, sort, sort_reverse, all, page, per_page)
        end

      protected

        # - model - a RailsAdmin::AbstractModel
        def listing_for_model_or_object(model, object, query, sort, sort_reverse, all, page, per_page)
          if sort.present?
            sort = COLUMN_MAPPING[sort.to_sym]
          else
            sort = :created_at
            sort_reverse = 'true'
          end

          current_page = page.presence || '1'

          versions = object.nil? ? versions_for_model(model) : object.versions
          versions = versions.where('event LIKE ?', "%#{query}%") if query.present?
          versions = versions.order(sort_reverse == 'true' ? "#{sort} DESC" : sort)
          versions = all ? versions : versions.send(Kaminari.config.page_method_name, current_page).per(per_page)
          paginated_proxies = Kaminari.paginate_array([], total_count: versions.try(:total_count) || versions.count)
          paginated_proxies = paginated_proxies.send(
            paginated_proxies.respond_to?(Kaminari.config.page_method_name) ? Kaminari.config.page_method_name : :page,
            current_page,
          ).per(per_page)
          versions.each do |version|
            paginated_proxies << VersionProxy.new(version, @user_class)
          end
          paginated_proxies
        end

        def versions_for_model(model)
          model_name = model.model.name
          base_class_name = model.model.base_class.name

          options =
            if base_class_name == model_name
              {item_type: model_name}
            else
              {item_type: base_class_name, item_id: model.model.all}
            end

          version_class_for(model.model).where(options)
        end

        # PT can be configured to use [custom version
        # classes](https://github.com/paper-trail-gem/paper_trail#6a-custom-version-classes)
        #
        # ```ruby
        # has_paper_trail class_name: 'MyVersion'
        # ```
        def version_class_for(model)
          model.paper_trail_options[:class_name].try(:constantize) || @version_class
        end
      end
    end
  end
end
