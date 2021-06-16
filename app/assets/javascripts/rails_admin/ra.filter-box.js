(function($) {

  var filters;

  $.filters = filters = {
    append: function(options) {
      options = options || {};
      var field_label = options['label'];
      var field_name  = options['name'];
      var field_type  = options['type'];
      var field_value = options['value'];
      var field_operator = options['operator'];
      var select_options = options['select_options'];
      var required = options['required'];
      var index = options['index'];
      var value_name    = 'f[' +  field_name + '][' + index + '][v]';
      var operator_name = 'f[' +  field_name + '][' + index + '][o]';
      var control = null;
      var additional_control = null;

      switch(field_type) {
        case 'boolean':
          control = $('<select class="input-sm form-control"></select>')
            .prop('name', value_name)
            .append('<option value="_discard">...</option>')
            .append($('<option value="true"></option>').prop('selected', field_value == "true").text(RailsAdmin.I18n.t("true")))
            .append($('<option value="false"></option>').prop('selected', field_value == "false").text(RailsAdmin.I18n.t("false")))
            if (!required) {
              control.append([
                '<option disabled="disabled">---------</option>',
                $('<option value="_present"></option>').prop('selected', field_value == "_present").text(RailsAdmin.I18n.t("is_present")),
                $('<option value="_blank"></option>').prop('selected', field_value == "_blank").text(RailsAdmin.I18n.t("is_blank"))
              ])
            }
          break;
        case 'date':
          additional_control =
            $('<input size="20" class="date additional-fieldset default input-sm form-control" type="text" />')
            .css('display', (!field_operator || field_operator == "default") ? 'inline-block' : 'none')
            .prop('name', value_name + '[]')
            .prop('value', field_value[0] || '')
            .add(
              $('<input size="20" placeholder="-∞" class="date additional-fieldset between input-sm form-control" type="text" />')
              .css('display', (field_operator == "between") ? 'inline-block' : 'none')
              .prop('name', value_name + '[]')
              .prop('value', field_value[1] || '')
            )
            .add(
              $('<input size="20" placeholder="∞" class="date additional-fieldset between input-sm form-control" type="text" />')
              .css('display', (field_operator == "between") ? 'inline-block' : 'none')
              .prop('name', value_name + '[]')
              .prop('value', field_value[2] || '')
            );
        case 'datetime':
        case 'timestamp':
          control = control || $('<select class="switch-additional-fieldsets input-sm form-control"></select>')
            .prop('name', operator_name)
            .append($('<option data-additional-fieldset="default" value="default"></option>').prop('selected', field_operator == "default").text(RailsAdmin.I18n.t("date")))
            .append($('<option data-additional-fieldset="between" value="between"></option>').prop('selected', field_operator == "between").text(RailsAdmin.I18n.t("between_and_")))
            .append($('<option value="today"></option>').prop('selected', field_operator == "today").text(RailsAdmin.I18n.t("today")))
            .append($('<option value="yesterday"></option>').prop('selected', field_operator == "yesterday").text(RailsAdmin.I18n.t("yesterday")))
            .append($('<option value="this_week"></option>').prop('selected', field_operator == "this_week").text(RailsAdmin.I18n.t("this_week")))
            .append($('<option value="last_week"></option>').prop('selected', field_operator == "last_week").text(RailsAdmin.I18n.t("last_week")))
          if (!required) {
            control.append([
              '<option disabled="disabled">---------</option>',
              $('<option value="_not_null"></option>').prop('selected', field_operator == "_not_null").text(RailsAdmin.I18n.t("is_present")),
              $('<option value="_null"></option>').prop('selected', field_operator == "_null").text(RailsAdmin.I18n.t("is_blank"))
            ])
          }
          additional_control = additional_control ||
            $('<input size="25" class="datetime additional-fieldset default input-sm form-control" type="text" />')
            .css('display', (!field_operator || field_operator == "default") ? 'inline-block' : 'none')
            .prop('name', value_name + '[]')
            .prop('value', field_value[0] || '')
            .add(
              $('<input size="25" placeholder="-∞" class="datetime additional-fieldset between input-sm form-control" type="text" />')
              .css('display', (field_operator == "between") ? 'inline-block' : 'none')
              .prop('name', value_name + '[]')
              .prop('value', field_value[1] || '')
            )
            .add(
              $('<input size="25" placeholder="∞" class="datetime additional-fieldset between input-sm form-control" type="text" />')
              .css('display', (field_operator == "between") ? 'inline-block' : 'none')
              .prop('name', value_name + '[]')
              .prop('value', field_value[2] || '')
            );
          break;
        case 'enum':
          var multiple_values = ((field_value instanceof Array) ? true : false)
          control = $('<select class="select-single input-sm form-control"></select>')
            .css('display', multiple_values ? 'none' : 'inline-block')
            .prop('name', multiple_values ? undefined : value_name)
            .data('name', value_name)
            .append('<option value="_discard">...</option>')
            .append(required ? [] : [
              $('<option value="_present"></option>').prop('selected', field_value == "_present").text(RailsAdmin.I18n.t("is_present")),
              $('<option value="_blank"></option>').prop('selected', field_value == "_blank").text(RailsAdmin.I18n.t("is_blank")),
              '<option disabled="disabled">---------</option>'
            ])
            .add(
              $('<select multiple="multiple" class="select-multiple input-sm form-control"></select>')
              .css('display', multiple_values ? 'inline-block' : 'none')
              .prop('name', multiple_values ? value_name + '[]' : undefined)
              .data('name', value_name + '[]')
              .append(select_options)
            )
            .add(
              $('<a href="#" class="switch-select"></a>')
              .append($('<i></i>').addClass('icon-' + (multiple_values ? 'minus' : 'plus')))
            );
        break;
        case 'string':
        case 'text':
        case 'belongs_to_association':
        case 'fulltext_indexed':
          control = $('<select class="switch-additional-fieldsets input-sm form-control"></select>')
            .prop('value', field_operator)
            .prop('name', operator_name)
            .append('<option value="_discard">...</option>')
            .append($('<option data-additional-fieldset="additional-fieldset" value="like"></option>').prop('selected', field_operator == "like").text(RailsAdmin.I18n.t("contains")))
            .append($('<option data-additional-fieldset="additional-fieldset" value="is"></option>').prop('selected', field_operator == "is").text(RailsAdmin.I18n.t("is_exactly")))
            .append($('<option data-additional-fieldset="additional-fieldset" value="starts_with"></option>').prop('selected', field_operator == "starts_with").text(RailsAdmin.I18n.t("starts_with")))
            .append($('<option data-additional-fieldset="additional-fieldset" value="ends_with"></option>').prop('selected', field_operator == "ends_with").text(RailsAdmin.I18n.t("ends_with")))
          if (!required) {
            control.append([
              '<option disabled="disabled">---------</option>',
              $('<option value="_present"></option>').prop('selected', field_operator == "_present").text(RailsAdmin.I18n.t("is_present")),
              $('<option value="_blank"></option>').prop('selected', field_operator == "_blank").text(RailsAdmin.I18n.t("is_blank"))
            ])
          }
          additional_control = $('<input class="additional-fieldset input-sm form-control" type="text" />')
            .css('display', field_operator == "_present" || field_operator == "_blank" ? 'none' : 'inline-block')
            .prop('name', value_name)
            .prop('value', field_value);
          break;
        case 'integer':
        case 'decimal':
        case 'float':
          control = $('<select class="switch-additional-fieldsets input-sm form-control"></select>')
            .prop('name', operator_name)
            .append($('<option data-additional-fieldset="default" value="default"></option>').prop('selected', field_operator == "default").text(RailsAdmin.I18n.t("number")))
            .append($('<option data-additional-fieldset="between" value="between"></option>').prop('selected', field_operator == "between").text(RailsAdmin.I18n.t("between_and_")))
          if (!required) {
            control.append([
              '<option disabled="disabled">---------</option>',
              $('<option value="_not_null"></option>').prop('selected', field_operator == "_not_null").text(RailsAdmin.I18n.t("is_present")),
              $('<option value="_null"></option>').prop('selected', field_operator == "_null").text(RailsAdmin.I18n.t("is_blank"))
            ])
          }
          additional_control =
            $('<input class="additional-fieldset default input-sm form-control" type="text" />')
            .css('display', (!field_operator || field_operator == "default") ? 'inline-block' : 'none')
            .prop('type', field_type)
            .prop('name', value_name + '[]')
            .prop('value', field_value[0] || '')
            .add(
              $('<input placeholder="-∞" class="additional-fieldset between input-sm form-control" />')
              .css('display', (field_operator == "between") ? 'inline-block' : 'none')
              .prop('type', field_type)
              .prop('name', value_name + '[]')
              .prop('value', field_value[1] || '')
            )
            .add(
              $('<input placeholder="∞" class="additional-fieldset between input-sm form-control" />')
              .css('display', (field_operator == "between") ? 'inline-block' : 'none')
              .prop('type', field_type)
              .prop('name', value_name + '[]')
              .prop('value', field_value[2] || '')
            );
          break;
        default:
          control = $('<input type="text" class="input-sm form-control" />')
            .prop('name', value_name)
            .prop('value', field_value);
          break;
      }

      var filterContainerId = field_name + '-' + index + '-filter-container';
      $('p#' + filterContainerId).remove();

      var $content = $('<p>')
        .attr('id', filterContainerId)
        .addClass('filter form-search')
        .append(
          $('<span class="label label-info form-label"></span>')
          .append($('<a href="#delete" class="delete"></a>').append('<i class="fa fa-trash-o fa-fw icon-white"></i>').append(document.createTextNode(field_label)))
        )
        .append('&nbsp;')
        .append(control)
        .append('&nbsp;')
        .append(additional_control);

      $('#filters_box').append($content);

      $content.find('.date, .datetime').datetimepicker({
        locale: RailsAdmin.I18n.locale,
        showTodayButton: true,
        format: options['datetimepicker_format']
      });

      $("hr.filters_box:hidden").show('slow');
    }
  }

  $(document).on('click', "#filters a", function(e) {
    e.preventDefault();
    $.filters.append({
      label: $(this).data('field-label'),
      name:  $(this).data('field-name'),
      type:  $(this).data('field-type'),
      value: $(this).data('field-value'),
      operator: $(this).data('field-operator'),
      select_options: $(this).data('field-options'),
      required: $(this).data('field-required'),
      index: $.now().toString().slice(6,11),
      datetimepicker_format: $(this).data('field-datetimepicker-format')
    });
  });

  $(document).on('click', "#filters_box .delete", function(e) {
    e.preventDefault();
    form = $(this).parents('form');
    $(this).parents('.filter').remove();
    !$("#filters_box").children().length && $("hr.filters_box:visible").hide('slow');
  });

  $(document).on('click', "#filters_box .switch-select", function(e) {
    e.preventDefault();
    var selected_select = $(this).siblings('select:visible');
    var not_selected_select = $(this).siblings('select:hidden');
    not_selected_select.attr('name', not_selected_select.data('name')).show('slow');
    selected_select.attr('name', null).hide('slow');
    $(this).find('i').toggleClass("icon-plus icon-minus")
  });

  $(document).on('change', "#filters_box .switch-additional-fieldsets", function(e) {
    var selected_option = $(this).find('option:selected');
    if(klass = $(selected_option).data('additional-fieldset')) {
      $(this).siblings('.additional-fieldset:not(.' + klass + ')').hide('slow');
      $(this).siblings('.' + klass).show('slow');
    } else {
      $(this).siblings('.additional-fieldset').hide('slow');
    }
  });
})( jQuery );
