$(function() {
    $('.ra-menu-collapse').on('shown.bs.collapse', function () {
        var target_obj = $("[data-menu-label-id*='"+$(this).attr('id')+"']");
        target_obj.html(target_obj.attr('data-menu-label') + ' -')
    }).on('hidden.bs.collapse', function () {
        var target_obj = $("[data-menu-label-id*='"+$(this).attr('id')+"']");
        target_obj.html(target_obj.attr('data-menu-label') + ' +')
    });
});