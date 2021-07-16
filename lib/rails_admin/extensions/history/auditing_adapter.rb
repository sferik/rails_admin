module RailsAdmin
  module Extensions
    module History
      class AuditingAdapter
        def initialize(controller, user_class = User)
          @controller = controller
          @user_class = user_class.to_s.constantize
          require 'rails_admin/extensions/history/history'
        end

        def latest(count = 100, order = {id: :desc})
          ::RailsAdmin::History.latest(count, order)
        end

        def delete_object(object, model, user)
          ::RailsAdmin::History.create_history_item('delete', object, model, user)
        end

        def update_object(object, model, user, changes)
          ::RailsAdmin::History.create_history_item(changes.collect { |k, v| "#{k}: #{v.collect(&:inspect).join(' -> ')}" }, object, model, user)
        end

        def create_object(object, model, user)
          ::RailsAdmin::History.create_history_item('new', object, model, user)
        end

        def listing_for_model(model, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
          ::RailsAdmin::History.history_for_model(model, query, sort, sort_reverse, all, page, per_page)
        end

        def listing_for_object(model, object, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
          ::RailsAdmin::History.history_for_object(model, object, query, sort, sort_reverse, all, page, per_page)
        end
      end
    end
  end
end
