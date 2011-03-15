jQuery(function($) {
    var CLOUDMADE_API_KEY = $("meta[name=cloudmade-api-key]").attr("content");

    $.fn.cloudMap = function() {
        return $(this).each(function() {
            var isStatic   = true,
                staticMap  = $(this),
                dynamicMap = $("<div id='dynamic-map' class='map'></div>"),
                latitude   = staticMap.data("latitude"),
                longitude  = staticMap.data("longitude"),
                address    = staticMap.data("address"),
                link       = $("<a href='#' class='toggle-map'>Mapa interactivo</a>");

            staticMap.before(link).before(dynamicMap.hide());

            var map = new CM.Map('dynamic-map', new CM.Tiles.CloudMade.Web({ key: CLOUDMADE_API_KEY })),
            mapLocation = new CM.LatLng(latitude, longitude),
            marker = new CM.Marker(mapLocation, { title: address });

            map.setCenter(mapLocation, 16);
            map.addOverlay(marker);
            map.panBy(new CM.Size(-dynamicMap.width() / 2, -dynamicMap.height() / 2));

            map.addControl(new CM.SmallMapControl());
            map.addControl(new CM.PermalinkControl());
            map.addControl(new CM.ScaleControl());
            map.enableMouseZoom();

            link.click(function(event) {
                isStatic = !isStatic;
                link.text(isStatic ? "Mapa interactivo" : "Mapa estático");

                staticMap.toggle();
                dynamicMap.toggle();

                if (!isStatic) {
                    // force load the map tiles. Sometimes when switching they are
                    // "unloaded" until you pan, so...
                    map.panBy(new CM.Size(1, 1));
                    map.panBy(new CM.Size(-1, -1));
                }

                event.preventDefault();
            });
        });
    }

    var searchForm = $("#search form"),
        address = $("#address", searchForm);

    address.autocomplete({
        source:    "/streets.json",
        minLength: 2,
        delay:     200
    });

    $(document).ajaxStart(function() { address.addClass("loading") });
    $(document).ajaxStop(function() { address.removeClass("loading") });

    $(window).bind("statechange", function() {
        var state = History.getState();
        load(state.url, false);
    });

    function load(url, push) {
        if (push === true || push === undefined)
            History.pushState(null, null, url);

        $.ajax({
            url:      url,
            dataType: "script html"
        }).success(function(response) {
            $("#results").html(response);
            $("#static-map").cloudMap();
        });
    }

    searchForm.submit(function() {
        address.autocomplete("close");
        load(this.action + "?" + searchForm.serialize());
        return false;
    });

    $("#multiple-choices a").live("click", function() {
        load(this.href);
        return false;
    });

    var apiDocs = $("#api-docs h2 + *").hide();
    $("#api-docs h2").css({ cursor: "pointer", textDecoration: "underline" }).click(function() {
        apiDocs.toggle();
    });

    $("#static-map").cloudMap();
});
