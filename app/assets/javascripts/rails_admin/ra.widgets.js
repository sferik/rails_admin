(function($) {
  $(document).on('rails_admin.dom_ready', function(e, content) {
    var $editors, array, config_options, goBootstrapWysihtml5s, goCkeditors, goCodeMirrors, goFroalaWysiwygs, goSimpleMDEs, options;
    content = content ? content : $('form');
    if (content.length) {
      content.find('[data-color]').each(function() {
        var that;
        that = this;
        return $(this).ColorPicker({
          color: $(that).val(),
          onShow: function(el) {
            $(el).fadeIn(500);
            return false;
          },
          onHide: function(el) {
            $(el).fadeOut(500);
            return false;
          },
          onChange: function(hsb, hex, rgb) {
            $(that).val(hex);
            $(that).css('backgroundColor', '#' + hex);
          }
        });
      });
      $.fn.datetimepicker.defaults.icons = {
        time: 'fa fa-clock-o',
        date: 'fa fa-calendar',
        up: 'fa fa-chevron-up',
        down: 'fa fa-chevron-down',
        previous: 'fa fa-angle-double-left',
        next: 'fa fa-angle-double-right',
        today: 'fa fa-dot-circle-o',
        clear: 'fa fa-trash',
        close: 'fa fa-times'
      };
      content.find('[data-datetimepicker]').each(function() {
        var options;
        options = $(this).data('options');
        $.extend(options, {
          locale: RailsAdmin.I18n.locale
        });
        $(this).datetimepicker(options);
      });
      content.find('[data-enumeration]').each(function() {
        if ($(this).is('[multiple]')) {
          $(this).filteringMultiselect($(this).data('options'));
        } else {
          $(this).filteringSelect($(this).data('options'));
        }
      });
      content.find('[data-fileupload]').each(function() {
        var parent;
        parent = $(this).closest('.controls');
        parent.find('.btn-remove-image').on('click', function() {
          $(this).siblings('[type=checkbox]').click();
          parent.find('.toggle').toggle('slow');
          $(this).toggleClass('btn-danger btn-info');
          return false;
        });
      });
      content.find('[data-fileupload]').change(function() {
        var ext, image_container, input, reader;
        input = this;
        image_container = $("#" + input.id).parent().children(".preview");
        if (!image_container.length) {
          image_container = $("#" + input.id).parent().prepend($('<img />').addClass('preview').addClass('img-thumbnail')).find('img.preview');
          image_container.parent().find('img:not(.preview)').hide();
        }
        ext = $("#" + input.id).val().split('.').pop().toLowerCase();
        if (input.files && input.files[0] && $.inArray(ext, ['gif', 'png', 'jpg', 'jpeg', 'bmp']) !== -1) {
          reader = new FileReader();
          reader.onload = function(e) {
            image_container.attr("src", e.target.result);
          };
          reader.readAsDataURL(input.files[0]);
          image_container.show();
        } else {
          image_container.hide();
        }
      });
      content.find('[data-multiple-fileupload]').each(function() {
        $(this).closest('.controls').find('.btn-remove-image').on('click', function() {
          $(this).siblings('[type=checkbox]').click();
          $(this).parent('.toggle').toggle('slow');
          $(this).toggleClass('btn-danger btn-info');
          return false;
        }).end().sortable({
          items: '.sortables'
        });
      });
      content.find('[data-multiple-fileupload]').change(function() {
        var ext, file, i, image_container, input, len, ref, results;
        input = this;
        $("#" + input.id).parent().children(".preview").remove();
        ref = input.files;
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          file = ref[i];
          ext = file.name.split('.').pop().toLowerCase();
          if ($.inArray(ext, ['gif', 'png', 'jpg', 'jpeg', 'bmp']) === -1) {
            continue;
          }
          image_container = $('<img />').addClass('preview').addClass('img-thumbnail');
          results.push((function(image_container) {
            var reader;
            reader = new FileReader();
            reader.onload = function(e) {
              image_container.attr("src", e.target.result);
            };
            reader.readAsDataURL(file);
            return $("#" + input.id).parent().append($('<div></div>').addClass('preview').append(image_container));
          })(image_container));
        }
        return results;
      });
      content.find('[data-filteringmultiselect]').each(function() {
        $(this).filteringMultiselect($(this).data('options'));
        if ($(this).parents("#modal").length) {
          $(this).siblings('.btn').remove();
        } else {
          $(this).parents('.control-group').first().remoteForm();
        }
      });
      content.find('[data-filteringselect]').each(function() {
        $(this).filteringSelect($(this).data('options'));
        if ($(this).parents("#modal").length) {
          $(this).siblings('.btn').remove();
        } else {
          $(this).parents('.control-group').first().remoteForm();
        }
      });
      content.find('[data-nestedmany]').each(function() {
        var field, nav, tab_content, toggler;
        field = $(this).parents('.control-group').first();
        nav = field.find('> .controls > .nav');
        tab_content = field.find('> .tab-content');
        toggler = field.find('> .controls > .btn-group > .toggler');
        tab_content.children('.fields:not(.tab-pane)').addClass('tab-pane').each(function() {
          $(this).attr('id', 'unique-id-' + (new Date().getTime()) + Math.floor(Math.random() * 100000));
          nav.append(
              $('<li></li>').append(
                  $('<a></a>').attr('data-toggle', 'tab').attr('href', '#' + this.id).text($(this).children('.object-infos').data('object-label'))
              )
          );
        });
        if (nav.find("> li.active").length === 0) {
          nav.find("> li > a[data-toggle='tab']:first").tab('show');
        }
        if (nav.children().length === 0) {
          nav.hide();
          tab_content.hide();
          toggler.addClass('disabled').removeClass('active').children('i').addClass('icon-chevron-right');
        } else {
          if (toggler.hasClass('active')) {
            nav.show();
            tab_content.show();
            toggler.children('i').addClass('icon-chevron-down');
          } else {
            nav.hide();
            tab_content.hide();
            toggler.children('i').addClass('icon-chevron-right');
          }
        }
      });
      content.find('[data-nestedone]').each(function() {
        var field, first_tab, nav, tab_content, toggler;
        field = $(this).parents('.control-group').first();
        nav = field.find("> .controls > .nav");
        tab_content = field.find("> .tab-content");
        toggler = field.find('> .controls > .btn-group > .toggler');
        tab_content.children(".fields:not(.tab-pane)").addClass('tab-pane active').each(function() {
          field.find('> .controls .add_nested_fields').removeClass('add_nested_fields').text($(this).children('.object-infos').data('object-label'));
          nav.append(
              $('<li></li>').append(
                  $('<a></a>').attr('data-toggle', 'tab').attr('href', '#' + $(this).id).text($(this).children('.object-infos').data('object-label'))
              )
          );
        });
        first_tab = nav.find("> li > a[data-toggle='tab']:first");
        first_tab.tab('show');
        field.find("> .controls > [data-target]:first").html('<i class="icon-white"></i> ' + first_tab.html());
        nav.hide();
        if (nav.children().length === 0) {
          nav.hide();
          tab_content.hide();
          toggler.addClass('disabled').removeClass('active').children('i').addClass('icon-chevron-right');
        } else {
          if (toggler.hasClass('active')) {
            toggler.children('i').addClass('icon-chevron-down');
            tab_content.show();
          } else {
            toggler.children('i').addClass('icon-chevron-right');
            tab_content.hide();
          }
        }
      });
      content.find('[data-polymorphic]').each(function() {
        var field, object_select, type_select, urls;
        type_select = $(this);
        field = type_select.parents('.control-group').first();
        object_select = field.find('select').last();
        urls = type_select.data('urls');
        type_select.on('change', function(e) {
          var selected_data, selected_type;
          selected_type = type_select.val().toLowerCase().replace("::", "-");
          selected_data = $("#" + selected_type + "-js-options").data('options');
          object_select.data('options', selected_data);
          object_select.filteringSelect("destroy");
          object_select.filteringSelect(selected_data);
        });
      });
      goSimpleMDEs = function() {
        return content.find('[data-richtext=simplemde]').not('.simplemded').each(function(index, domEle) {
          var instance_config, options;
          options = $(this).data('options');
          instance_config = options.instance_config;
          new window.SimpleMDE($.extend(true, {
            element: document.getElementById(this.id),
            autosave: {
              uniqueId: this.id
            }
          }, instance_config));
          $(this).addClass('simplemded');
        });
      };
      $editors = content.find('[data-richtext=simplemde]').not('.simplemded');
      if ($editors.length) {
        if (!window.SimpleMDE) {
          options = $editors.first().data('options');
          $('head').append('<link href="' + options['css_location'] + '" rel="stylesheet" media="all" type="text\/css">');
          $.getScript(options['js_location'], function(script, textStatus, jqXHR) {
            return goSimpleMDEs();
          });
        } else {
          goSimpleMDEs();
        }
      }
      goCkeditors = function() {
        return content.find('[data-richtext=ckeditor]').not('.ckeditored').each(function(index, domEle) {
          var instance;
          try {
            if (instance = window.CKEDITOR.instances[this.id]) {
              instance.destroy(true);
            }
          } catch (error1) {}
          window.CKEDITOR.replace(this, $(this).data('options').options);
          $(this).addClass('ckeditored');
        });
      };
      $editors = content.find('[data-richtext=ckeditor]').not('.ckeditored');
      if ($editors.length) {
        if (!window.CKEDITOR) {
          options = $editors.first().data('options');
          window.CKEDITOR_BASEPATH = options['base_location'];
          $.getScript(options['jspath'], (function(_this) {
            return function(script, textStatus, jqXHR) {
              return goCkeditors();
            };
          })(this));
        } else {
          goCkeditors();
        }
      }
      goCodeMirrors = (function(_this) {
        return function(array) {
          return array.each(function(index, domEle) {
            var textarea;
            options = $(this).data('options');
            textarea = this;
            $.getScript(options['locations']['mode'], function(script, textStatus, jqXHR) {
              options = $(domEle).data('options');
              $('head').append('<link href="' + options['locations']['theme'] + '" rel="stylesheet" media="all" type="text\/css">');
              CodeMirror.fromTextArea(textarea, options['options']);
              return $(textarea).addClass('codemirrored');
            });
          });
        };
      })(this);
      array = content.find('[data-richtext=codemirror]').not('.codemirrored');
      if (array.length) {
        this.array = array;
        if (!window.CodeMirror) {
          options = $(array[0]).data('options');
          $('head').append('<link href="' + options['csspath'] + '" rel="stylesheet" media="all" type="text\/css">');
          $.getScript(options['jspath'], (function(_this) {
            return function(script, textStatus, jqXHR) {
              return goCodeMirrors(_this.array);
            };
          })(this));
        } else {
          goCodeMirrors(this.array);
        }
      }
      goBootstrapWysihtml5s = (function(_this) {
        return function(array, config_options) {
          return array.each(function() {
            $(this).addClass('bootstrap-wysihtml5ed');
            $(this).closest('.controls').addClass('well');
            $(this).wysihtml5(config_options);
          });
        };
      })(this);
      array = content.find('[data-richtext=bootstrap-wysihtml5]').not('.bootstrap-wysihtml5ed');
      if (array.length) {
        this.array = array;
        options = $(array[0]).data('options');
        config_options = $.parseJSON(options['config_options']);
        if (!window.wysihtml5) {
          $('head').append('<link href="' + options['csspath'] + '" rel="stylesheet" media="all" type="text\/css">');
          $.getScript(options['jspath'], (function(_this) {
            return function(script, textStatus, jqXHR) {
              return goBootstrapWysihtml5s(_this.array, config_options);
            };
          })(this));
        } else {
          goBootstrapWysihtml5s(this.array, config_options);
        }
      }
      goFroalaWysiwygs = (function(_this) {
        return function(array) {
          return array.each(function() {
            var uploadEnabled;
            options = $(this).data('options');
            config_options = $.parseJSON(options['config_options']);
            if (config_options) {
              if (!config_options['inlineMode']) {
                config_options['inlineMode'] = false;
              }
            } else {
              config_options = {
                inlineMode: false
              };
            }
            uploadEnabled = config_options['imageUploadURL'] ? config_options['imageUploadParams'] = {
              authenticity_token: $('meta[name=csrf-token]').attr('content')
            } : void 0;
            $(this).addClass('froala-wysiwyged');
            $(this).froalaEditor(config_options);
            if (uploadEnabled) {
              $(this).on('froalaEditor.image.error', function(e, editor, error) {
                alert("error uploading image: " + error.message);
              }).on('froalaEditor.image.removed', function(e, editor, $img) {
                editor.options.imageDeleteParams = {
                  src: $img.attr('src'),
                  authenticity_token: $('meta[name=csrf-token]').attr('content')
                };
                editor.deleteImage($img);
              }).on('editable.imageDeleteSuccess', function(e, editor, data) {}).on('editable.imageDeleteError', function(e, editor, error) {
                alert("error deleting image: " + error.message);
              });
            }
          });
        };
      })(this);
      array = content.find('[data-richtext=froala-wysiwyg]').not('.froala-wysiwyged');
      if (array.length) {
        options = $(array[0]).data('options');
        if (!$.isFunction($.fn.editable)) {
          $('head').append('<link href="' + options['csspath'] + '" rel="stylesheet" media="all" type="text\/css">');
          $.getScript(options['jspath'], (function(_this) {
            return function(script, textStatus, jqXHR) {
              return goFroalaWysiwygs(array);
            };
          })(this));
        } else {
          goFroalaWysiwygs(array);
        }
      }
      return content.find('trix-editor').each(function() {
        if (!window.Trix) {
          options = $(this).data('options');
          $('head').append('<link href="' + options['csspath'] + '" rel="stylesheet" media="all" type="text\/css">');
          return $.getScript(options['jspath']);
        }
      });
    }
  });

}(jQuery));
