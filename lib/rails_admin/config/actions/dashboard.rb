module RailsAdmin
  module Config
    module Actions
      class Dashboard < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :root? do
          true
        end

        register_instance_option :breadcrumb_parent do
          nil
        end

        register_instance_option :auditing_versions_limit do
          100
        end

        register_instance_option :controller do
          proc do
            @history = @auditing_adapter && @auditing_adapter.latest(@action.auditing_versions_limit, RailsAdmin::Config.default_versions_order) || []
            if @action.statistics?
              @abstract_models = RailsAdmin::Config.visible_models(controller: self).collect(&:abstract_model)

              @most_recent_created = {}
              @count = {}
              @max = 0
              @abstract_models.each do |t|
                scope = @authorization_adapter && @authorization_adapter.query(:index, t)
                current_count = t.count({}, scope)
                @max = current_count > @max ? current_count : @max
                @count[t.model.name] = current_count
                next unless t.properties.detect { |c| c.name == :created_at }
                sort_field = t.properties.detect { |c| c.name == t.config.dashboard_sort_by} ? t.config.dashboard_sort_by : :id
                @most_recent_created[t.model.name] = t.model.order(sort_field).last.try(:created_at)
              end
            end
            render @action.template_name, status: @status_code || :ok
          end
        end

        register_instance_option :route_fragment do
          ''
        end

        register_instance_option :link_icon do
          'icon-home'
        end

        register_instance_option :statistics? do
          true
        end
      end
    end
  end
end
