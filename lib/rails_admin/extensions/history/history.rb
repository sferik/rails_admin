module RailsAdmin
  class History < ActiveRecord::Base
    self.table_name = :rails_admin_histories

    IGNORED_ATTRS = Set[:id, :created_at, :created_on, :deleted_at, :updated_at, :updated_on, :deleted_on]

    if defined?(ActiveModel::MassAssignmentSecurity) && ancestors.include?(ActiveModel::MassAssignmentSecurity)
      attr_accessible :message, :item, :table, :username
    end

    default_scope { order('id DESC') }

    class << self
      def latest(count = 100, order = {id: :desc})
        order(order).limit(count)
      end

      def create_history_item(message, object, abstract_model, user)
        create(message: [message].flatten.join(', '),
               item: object.id,
               table: abstract_model.to_s,
               username: user.try(:email))
      end

      def history_for_model(abstract_model, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
        history = where(table: abstract_model.to_s)
        history_for_model_or_object(history, abstract_model, query, sort, sort_reverse, all, page, per_page)
      end

      def history_for_object(abstract_model, object, query, sort, sort_reverse, all, page, per_page = (RailsAdmin::Config.default_items_per_page || 20))
        history = where(table: abstract_model.to_s, item: object.id)
        history_for_model_or_object(history, abstract_model, query, sort, sort_reverse, all, page, per_page)
      end

    protected

      def history_for_model_or_object(history, _abstract_model, query, sort, sort_reverse, all, page, per_page)
        history = history.where('message LIKE ? OR username LIKE ?', "%#{query}%", "%#{query}%") if query
        history = history.order(sort_reverse == 'true' ? "#{sort} DESC" : sort) if sort
        all ? history : history.send(Kaminari.config.page_method_name, page.presence || '1').per(per_page)
      end
    end
  end
end
