module RailsAdmin
  class MainController < RailsAdmin::ApplicationController
    include ActionView::Helpers::TextHelper
    include RailsAdmin::MainHelper
    include RailsAdmin::ApplicationHelper

    layout :get_layout

    before_action :get_model, except: RailsAdmin::Config::Actions.all(:root).collect(&:action_name)
    before_action :get_object, only: RailsAdmin::Config::Actions.all(:member).collect(&:action_name)
    before_action :check_for_cancel

    RailsAdmin::Config::Actions.all.each do |action|
      class_eval <<-EOS, __FILE__, __LINE__ + 1
        def #{action.action_name}
          action = RailsAdmin::Config::Actions.find('#{action.action_name}'.to_sym)
          @authorization_adapter.try(:authorize, action.authorization_key, @abstract_model, @object)
          @action = action.with({controller: self, abstract_model: @abstract_model, object: @object})
          fail(ActionNotAllowed) unless @action.enabled?
          @page_name = wording_for(:title)

          instance_eval &@action.controller
        end
      EOS
    end

    def bulk_action
      send(params[:bulk_action]) if params[:bulk_action].in?(RailsAdmin::Config::Actions.all(controller: self, abstract_model: @abstract_model).select(&:bulkable?).collect(&:route_fragment))
    end

    def list_entries(model_config = @model_config, auth_scope_key = :index, additional_scope = get_association_scope_from_params, pagination = !(params[:associated_collection] || params[:all] || params[:bulk_ids]))
      scope = model_config.abstract_model.scoped
      if auth_scope = @authorization_adapter && @authorization_adapter.query(auth_scope_key, model_config.abstract_model)
        scope = scope.merge(auth_scope)
      end
      scope = scope.instance_eval(&additional_scope) if additional_scope
      get_collection(model_config, scope, pagination)
    end

  private

    def get_layout
      "rails_admin/#{request.headers['X-PJAX'] ? 'pjax' : 'application'}"
    end

    def back_or_index
      params[:return_to].presence && params[:return_to].include?(request.host) && (params[:return_to] != request.fullpath) ? params[:return_to] : index_path
    end

    def get_sort_hash(model_config)
      abstract_model = model_config.abstract_model
      params[:sort] = params[:sort_reverse] = nil unless model_config.list.fields.collect { |f| f.name.to_s }.include? params[:sort]
      params[:sort] ||= model_config.list.sort_by.to_s
      params[:sort_reverse] ||= 'false'

      field = model_config.list.fields.detect { |f| f.name.to_s == params[:sort] }
      column = begin
        if field.nil? || field.sortable == true # use params[:sort] on the base table
          "#{abstract_model.table_name}.#{params[:sort]}"
        elsif field.sortable == false # use default sort, asked field is not sortable
          "#{abstract_model.table_name}.#{model_config.list.sort_by}"
        elsif (field.sortable.is_a?(String) || field.sortable.is_a?(Symbol)) && field.sortable.to_s.include?('.') # just provide sortable, don't do anything smart
          field.sortable
        elsif field.sortable.is_a?(Hash) # just join sortable hash, don't do anything smart
          "#{field.sortable.keys.first}.#{field.sortable.values.first}"
        elsif field.association? # use column on target table
          "#{field.associated_model_config.abstract_model.table_name}.#{field.sortable}"
        else # use described column in the field conf.
          "#{abstract_model.table_name}.#{field.sortable}"
        end
      end

      reversed_sort = (field ? field.sort_reverse? : model_config.list.sort_reverse?)
      {sort: column, sort_reverse: (params[:sort_reverse] == reversed_sort.to_s)}
    end

    def redirect_to_on_success
      notice = I18n.t('admin.flash.successful', name: @model_config.label, action: I18n.t("admin.actions.#{@action.key}.done"))
      if params[:_add_another]
        redirect_to new_path(return_to: params[:return_to]), flash: {success: notice}
      elsif params[:_add_edit]
        redirect_to edit_path(id: @object.id, return_to: params[:return_to]), flash: {success: notice}
      else
        redirect_to back_or_index, flash: {success: notice}
      end
    end

    def visible_fields(action, model_config = @model_config)
      model_config.send(action).with(controller: self, view: view_context, object: @object).visible_fields
    end

    def sanitize_params_for!(action, model_config = @model_config, target_params = params[@abstract_model.param_key])
      return unless target_params.present?

      fields = visible_fields(action, model_config)
      allowed_methods = fields.collect(&:allowed_methods).flatten.uniq.collect(&:to_s) << 'id' << '_destroy'
      fields.each { |field| field.parse_input(target_params) }
      target_params.slice!(*allowed_methods)
      target_params.permit! if target_params.respond_to?(:permit!)
      fields.select(&:nested_form).each do |association|
        children_params = association.multiple? ? target_params[association.method_name].try(:values) : [target_params[association.method_name]].compact
        (children_params || []).each do |children_param|
          sanitize_params_for!(:nested, association.associated_model_config, children_param)
        end
      end
    end

    def handle_save_error(whereto = :new)
      flash.now[:error] = I18n.t('admin.flash.error', name: @model_config.label, action: I18n.t("admin.actions.#{@action.key}.done").html_safe).html_safe
      flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe

      respond_to do |format|
        format.html { render whereto, status: :not_acceptable }
        format.js   { render whereto, layout: false, status: :not_acceptable }
      end
    end

    def check_for_cancel
      return unless params[:_continue] || (params[:bulk_action] && !params[:bulk_ids])

      redirect_to(back_or_index, notice: I18n.t('admin.flash.noaction'))
    end

    def get_collection(model_config, scope, pagination)
      associations = model_config.list.fields.select { |f| f.try(:eager_load?) }.collect { |f| f.association.name }
      options = {}
      options = options.merge(page: (params[Kaminari.config.param_name] || 1).to_i, per: (params[:per] || model_config.list.items_per_page)) if pagination
      options = options.merge(include: associations) unless associations.blank?
      options = options.merge(get_sort_hash(model_config))
      options = options.merge(query: params[:query]) if params[:query].present?
      options = options.merge(filters: params[:f]) if params[:f].present?
      options = options.merge(bulk_ids: params[:bulk_ids]) if params[:bulk_ids]
      model_config.abstract_model.all(options, scope)
    end

    def get_association_scope_from_params
      return nil unless params[:associated_collection].present?

      source_abstract_model = RailsAdmin::AbstractModel.new(to_model_name(params[:source_abstract_model]))
      source_model_config = source_abstract_model.config
      source_object = source_abstract_model.get(params[:source_object_id])
      action = params[:current_action].in?(%w[create update]) ? params[:current_action] : 'edit'
      @association = source_model_config.send(action).fields.detect { |f| f.name == params[:associated_collection].to_sym }.with(controller: self, object: source_object)
      @association.associated_collection_scope
    end
  end
end
