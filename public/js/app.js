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

    function Address(street, house) {
        this.street = street;
        this.house  = house;

        this.toString = function() {
            return this.street + " " + this.house;
        }
    }

    Address.parse = function(str) {
        var rev = function(s) { return String(s).split("").reverse().join("") }
        var matches = rev(str).match(/^(?:((?:sib|[ab]p|[a-d])?\s*\d+)?\s+)?(.+)$/);
        return new Address(rev(matches[2]), rev(matches[1]));
    }

    window.Address = Address;

    var searchForm = $("#search form"),
        address = $("#address", searchForm);

    address.autocomplete({
        minLength: 2,
        delay:     200,
        source:    function(request, response) {
            var address = Address.parse(request.term),
                req = $.ajax({
                    url:      "/streets.json",
                    dataType: "json",
                    data:     { term: address.street }
                });

            req.success(function(data) {
                var results = $.map(data, function(street) {
                    return {
                        label: street,
                        value: new Address(street, address.house).toString()
                    }
                });

                response(results);
            });
        },
        open: function(eveent, ui) {
            $(".ui-menu").css({ zIndex: 3000000 }); // WTF, CloudMade.
        }
    });

    address.blur(function() {
        address.autocomplete("close");
    });

    $(document).ajaxStart(function() { address.addClass("loading") });
    $(document).ajaxStop(function() { address.removeClass("loading") });

    window.onpopstate = function(event) {
        event.state && load(event.state.url, false);
    };

    function load(url, push) {
        if (push === true || push === undefined)
            history.pushState({}, "", url);

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
