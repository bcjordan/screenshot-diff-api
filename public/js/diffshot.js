(function ($) {
  $(function () {
    var diffshot,
      rbApi = 'http://requestb.in/api/v1/bins',
      form = $('#diffdemo form');

    if (!$.support.cors) {
      form.hide();
      return;
    } else {
      $('#diffdemo .alert.cors').hide();

      form.on('submit', function (event) {
        var img = $('<img>').attr({
          'data-src': 'holder.js/205x154/text:Fetching...'
        }).appendTo($('#diffdemo .output'));

        Holder.run();

        $.post(rbApi, function (postbin) {
          var url = 'http://requestb.in/' + postbin.name;
          var link = '<a href="' + url + '?inspect">' + url + '</a>';
          var content = 'Using ' + link + ' as callback URL';
          form.find('small.note').html(content);
          diffshot(postbin, img);
        });

        return event.preventDefault();
      });
    }

    diffshot = function (postbin, img) {
      var binUrl = rbApi + '/' + postbin.name;

      var params = {
        url_a: form.find('input[name="urlA"]').val(),
        url_b: form.find('input[name="urlB"]').val(),
        callback: 'http://requestb.in/' + postbin.name
      };

      $.post('/diff', params, function () {
        var fn = function () {
          $.get(binUrl, function (data) {
            if (data["request_count"] > 0) {
              $.get(binUrl + '/requests', function (data) {
                var data = $.parseJSON(data[0].body);
                img.attr({
                  src: 'data:image/png;base64,' + data.imageData,
                  'data-src': null,
                  alt: data.title
                });
              });
            } else {
              window.setTimeout(fn, 100);
            }
          });
        };
        window.setTimeout(fn, 100);
      });
    }

  });
})(jQuery);
