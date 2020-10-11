require 'activemodel-serializers-xml'

module RailsAdmin
  module Config
    module Actions
      class Index < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          %i[get post]
        end

        register_instance_option :route_fragment do
          ''
        end

        register_instance_option :breadcrumb_parent do
          parent_model = bindings[:abstract_model].try(:config).try(:parent)
          if am = parent_model && RailsAdmin.config(parent_model).try(:abstract_model)
            [:index, am]
          else
            [:dashboard]
          end
        end

        register_instance_option :controller do
          proc do
            @objects ||= list_entries

            unless @model_config.list.scopes.empty?
              if params[:scope].blank?
                @objects = @objects.send(@model_config.list.scopes.first) unless @model_config.list.scopes.first.nil?
              elsif @model_config.list.scopes.collect(&:to_s).include?(params[:scope])
                @objects = @objects.send(params[:scope].to_sym)
              end
            end

            respond_to do |format|
              format.html do
                render @action.template_name, status: @status_code || :ok
              end

              format.json do
                output = begin
                  if params[:compact]
                    primary_key_method = @association ? @association.associated_primary_key : @model_config.abstract_model.primary_key
                    label_method = @model_config.object_label_method
                    @objects.collect { |o| {id: o.send(primary_key_method).to_s, label: o.send(label_method).to_s} }
                  else
                    @objects.to_json(@schema)
                  end
                end
                if params[:send_data]
                  send_data output, filename: "#{params[:model_name]}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.json"
                else
                  render json: output, root: false
                end
              end

              format.xml do
                output = @objects.to_xml(@schema)
                if params[:send_data]
                  send_data output, filename: "#{params[:model_name]}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.xml"
                else
                  render xml: output
                end
              end

              format.csv do
                header, encoding, output = CSVConverter.new(@objects, @schema).to_csv(params[:csv_options].permit!.to_h)
                if params[:send_data]
                  send_data output,
                            type: "text/csv; charset=#{encoding}; #{'header=present' if header}",
                            disposition: "attachment; filename=#{params[:model_name]}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.csv"
                else
                  render plain: output
                end
              end
            end
          end
        end

        register_instance_option :link_icon do
          'icon-th-list'
        end
      end
    end
  end
end
