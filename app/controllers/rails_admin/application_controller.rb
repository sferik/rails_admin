require 'rails_admin/abstract_model'

module RailsAdmin
  class ModelNotFound < ::StandardError
  end

  class ObjectNotFound < ::StandardError
  end

  class ActionNotAllowed < ::StandardError
  end

  class ApplicationController < Config.parent_controller.constantize
    include RailsAdmin::Extensions::ControllerExtension

    protect_from_forgery(Config.forgery_protection_settings)

    before_action :_authenticate!
    before_action :_authorize!
    before_action :_audit!

    helper_method :_current_user, :_get_plugin_name

    attr_reader :object, :model_config, :abstract_model, :authorization_adapter

    def get_model
      @model_name = to_model_name(params[:model_name])
      raise(RailsAdmin::ModelNotFound) unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
      raise(RailsAdmin::ModelNotFound) if (@model_config = @abstract_model.config).excluded?

      @properties = @abstract_model.properties
    end

    def get_object
      raise(RailsAdmin::ObjectNotFound) unless (@object = @abstract_model.get(params[:id]))
    end

    def to_model_name(param)
      param.split('~').collect(&:camelize).join('::')
    end

    def _current_user
      instance_eval(&RailsAdmin::Config.current_user_method)
    end

  private

    def _get_plugin_name
      @plugin_name_array ||= [RailsAdmin.config.main_app_name.is_a?(Proc) ? instance_eval(&RailsAdmin.config.main_app_name) : RailsAdmin.config.main_app_name].flatten
    end

    def _authenticate!
      instance_eval(&RailsAdmin::Config.authenticate_with)
    end

    def _authorize!
      instance_eval(&RailsAdmin::Config.authorize_with)
    end

    def _audit!
      instance_eval(&RailsAdmin::Config.audit_with)
    end

    def rails_admin_controller?
      true
    end

    rescue_from RailsAdmin::ObjectNotFound do
      flash[:error] = I18n.t('admin.flash.object_not_found', model: @model_name, id: params[:id])
      params[:action] = 'index'
      @status_code = :not_found
      index
    end

    rescue_from RailsAdmin::ModelNotFound do
      flash[:error] = I18n.t('admin.flash.model_not_found', model: @model_name)
      params[:action] = 'dashboard'
      @status_code = :not_found
      dashboard
    end
  end
end
