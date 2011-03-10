jQuery(function($) {
    var CLOUDMADE_API_KEY = $("meta[name=cloudmade-api-key]").attr("content");

    var isStatic   = true,
        staticMap  = $("#static-map"),
        dynamicMap = $("<div id='dynamic-map' class='map'></div>"),
        latitude   = staticMap.data("latitude"),
        longitude  = staticMap.data("longitude"),
        address    = staticMap.data("address"),
        link       = $("<a href='#' class='toggle-map'>Mapa interactivo</a>");

    staticMap.before(link).before(dynamicMap.hide());

    var map = new CM.Map('dynamic-map', new CM.Tiles.CloudMade.Web({ key: CLOUDMADE_API_KEY })),
        mapLocation = new CM.LatLng(latitude, longitude),
        marker = new CM.Marker(mapLocation, { title: address });

    window.map = map;

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
