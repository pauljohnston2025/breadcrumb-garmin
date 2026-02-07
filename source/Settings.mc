import Toybox.Application;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Application;
import Toybox.Communications;
import Toybox.WatchUi;
import Toybox.PersistedContent;

enum /* TrackStyle */ {
    TRACK_STYLE_LINE = 0, // Standard continuous line
    TRACK_STYLE_DASHED = 1, // Interpolated dashes
    TRACK_STYLE_POINTS = 2, // Dots only at actual data points
    TRACK_STYLE_POINTS_INTERPOLATED = 3, // Dots spaced evenly along the path
    TRACK_STYLE_BOXES = 4, // Squares outline only at actual data points
    TRACK_STYLE_BOXES_INTERPOLATED = 5, // Squares outline spaced evenly along the path
    TRACK_STYLE_FILLED_SQUARE = 6, // Squares only at actual data points
    TRACK_STYLE_FILLED_SQUARE_INTERPOLATED = 7, // Squares spaced evenly along the path
    TRACK_STYLE_POINTS_OUTLINE = 8, // Dots only at actual data points, just the circle outline
    TRACK_STYLE_POINTS_OUTLINE_INTERPOLATED = 9, // Dots spaced evenly along the path, just the circle outline
    TRACK_STYLE_CHECKERBOARD = 10,
    TRACK_STYLE_HAZARD = 11,
    TRACK_STYLE_DOT_MATRIX = 12,
    TRACK_STYLE_POLKA_DOT = 13,
    TRACK_STYLE_DIAMOND = 14,

    TRACK_STYLE_MAX,
}

enum /*TrackPointReductionMethod*/ {
    TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE = 0,
    TRACK_POINT_REDUCTION_METHOD_REUMANN_WITKAM = 1,
}

enum /*DataType*/ {
    DATA_TYPE_NONE,
    DATA_TYPE_SCALE,
    DATA_TYPE_ALTITUDE,
    DATA_TYPE_AVERAGE_HEART_RATE,
    DATA_TYPE_AVERAGE_SPEED,
    DATA_TYPE_CURRENT_HEART_RATE,
    DATA_TYPE_CURRENT_SPEED,
    DATA_TYPE_ELAPSED_DISTANCE,
    DATA_TYPE_ELAPSED_TIME,
    DATA_TYPE_TOTAL_ASCENT,
    DATA_TYPE_TOTAL_DESCENT,
    DATA_TYPE_AVERAGE_PACE,
    DATA_TYPE_CURRENT_PACE,

    // other metrics that might be good
    // most of these are inbuilt garmin ones (so could easily be added to a second data screen)
    // Ill add them if users ask, but currently only have requests for pace https://github.com/pauljohnston2025/breadcrumb-garmin/issues/8
    // anything to do with laps I will need to store timestamps when onTimerLap() is called, and probably store all the activity info? or maybe just store distance/and timestamp?
    // time of day - wall clock
    // last lap time
    // current lap time
}

enum /*Mode*/ {
    MODE_NORMAL,
    MODE_ELEVATION,
    MODE_MAP_MOVE,
    MODE_DEBUG,
    MODE_MAX,
}

enum /*ElevationMode*/ {
    ELEVATION_MODE_STACKED,
    ELEVATION_MODE_ORDERED_ROUTES,
    ELEVATION_MODE_MAX,
}

enum /*ZoomMode*/ {
    ZOOM_AT_PACE_MODE_PACE,
    ZOOM_AT_PACE_MODE_STOPPED,
    ZOOM_AT_PACE_MODE_NEVER_ZOOM,
    ZOOM_AT_PACE_MODE_ALWAYS_ZOOM,
    ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK,
    ZOOM_AT_PACE_MODE_MAX,
}

enum /*UiMode*/ {
    UI_MODE_SHOW_ALL, // show a heap of ui elements on screen always
    UI_MODE_HIDDEN, // ui still active, but is hidden
    UI_MODE_NONE, // no accessible ui (touch events disabled)
    UI_MODE_MAX,
}

enum /*RenderMode*/ {
    RENDER_MODE_BUFFERED_ROTATING,
    RENDER_MODE_UNBUFFERED_ROTATING,
    RENDER_MODE_BUFFERED_NO_ROTATION,
    RENDER_MODE_UNBUFFERED_NO_ROTATION,
    RENDER_MODE_MAX,
}

enum /*RenderMode*/ {
    ALERT_TYPE_TOAST,
    ALERT_TYPE_ALERT,
    ALERT_TYPE_IMAGE,
    ALERT_TYPE_MAX,
}

enum /*AttributionType*/ {
    /*ATTRIBUTION_GOOGLE,*/
    ATTRIBUTION_OPENTOPOMAP = 1,
    ATTRIBUTION_ESRI,
    ATTRIBUTION_OPENSTREETMAP,
    ATTRIBUTION_STADIA,
    ATTRIBUTION_CARTO,
    ATTRIBUTION_MAPY,
}

enum /*UrlPrefix*/ {
    URL_PREFIX_NONE,
    URL_PREFIX_ESRI,
    URL_PREFIX_STADIA,
    URL_PREFIX_CARTO,
    URL_PREFIX_MAPY,
}

enum /*AuthTokenType*/ {
    AUTH_TOKEN_TYPE_NONE,
    AUTH_TOKEN_TYPE_STADIA,
    AUTH_TOKEN_TYPE_MAPY,
}

const COMPANION_APP_TILE_URL = "http://127.0.0.1:8080";

(:imageTiles)
class TileServerInfo {
    var attributionType as Number;
    var urlPrefix as Number;
    var authTokenType as Number;
    var urlTemplate as String;
    var tileLayerMin as Number;
    var tileLayerMax as Number;
    function initialize(
        attributionType as Number,
        urlPrefix as Number,
        authTokenType as Number,
        urlTemplate as ResourceId,
        tileLayerMin as Number,
        tileLayerMax as Number
    ) {
        me.attributionType = attributionType;
        me.urlPrefix = urlPrefix;
        me.authTokenType = authTokenType;
        me.urlTemplate = WatchUi.loadResource(urlTemplate) as String;
        me.tileLayerMin = tileLayerMin;
        me.tileLayerMax = tileLayerMax;
    }
}

(:imageTiles)
function getUrlPrefix(prefix as Number) as String {
    if (prefix == URL_PREFIX_NONE) {
        return "";
    } else if (prefix == URL_PREFIX_ESRI) {
        return WatchUi.loadResource(Rez.Strings.esriPrefix) as String;
    } else if (prefix == URL_PREFIX_STADIA) {
        return WatchUi.loadResource(Rez.Strings.stadiaPrefix) as String;
    } else if (prefix == URL_PREFIX_CARTO) {
        return WatchUi.loadResource(Rez.Strings.cartoPrefix) as String;
    } else if (prefix == URL_PREFIX_MAPY) {
        return WatchUi.loadResource(Rez.Strings.mapyPrefix) as String;
    }

    return "";
}

(:imageTiles)
function getAuthTokenSuffix(type as Number) as String {
    switch (type) {
        case AUTH_TOKEN_TYPE_NONE:
            return "";
        case AUTH_TOKEN_TYPE_STADIA:
            return "?api_key={authToken}";
        case AUTH_TOKEN_TYPE_MAPY:
            return "?apiKey={authToken}";
    }

    return "";
}

(:noImageTiles)
function getTileServerInfo(id as Number) as TileServerInfo? {
    return null;
}

(:highMemory)
function getTileServerInfo(id as Number) as TileServerInfo? {
    // prettier-ignore
    // This is an array instead of a dict because dict does not render correctly, also arrays are faster
    // 0 => null, // special custom (no tile property changes will happen)
    // 1 => null, // special companion app (only the tileUrl will be updated)
    switch(id)
    {
        case 2:
            // open topo
            return new TileServerInfo(ATTRIBUTION_OPENTOPOMAP, URL_PREFIX_NONE, AUTH_TOKEN_TYPE_NONE, Rez.Strings.openTopoMapUrlTemplate, 0, 15); // OpenTopoMap
            // google - cannot use returns 404 - works from companion app (userAgent sent)
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}", 0, 20), // "Google - Hybrid"
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}", 0, 20), // "Google - Satellite"
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}", 0, 20), // "Google - Road"
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}", 0, 20), // "Google - Terain"
            // arcgis (esri) - note some of these have been removed due to not enough coverage, and others have had layermin/max altered for australian coverage
            // _Reference maps are all the same - just the location names removing them
            // Note: when testing on the simulator, some of theese occasionaly seem to produce   
            // Error: Invalid Value
            // Details: failed inside handle_image_callback
        case 3:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldImageryTemplate, 0, 20); // Esri - World Imagery
        case 4:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldStreetMapTemplate, 0, 19); // Esri - World Street Map
        case 5:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldTopoMapTemplate, 0, 19); // Esri - World Topo Map
        case 6:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldTransportationTemplate, 0, 15); // Esri - World Transportation
        case 7:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldDarkGrayBaseTemplate, 0, 16); // Esri - World Dark Gray Base
        case 8:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldHillshadeTemplate, 0, 16); // Esri - World Hillshade
        case 9:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldHillshadeDarkTemplate, 0, 16); // Esri - World Hillshade Dark
        case 10:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldLightGrayBaseTemplate, 0, 16); // Esri - World Light Gray Base
        case 11:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriUsaTopoMapsTemplate, 0, 15); // Esri - USA Topo Maps
        case 12:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldOceanBaseTemplate, 0, 13); // Esri - World Ocean Base
        case 13:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldShadedReliefTemplate, 0, 13); // Esri - World Shaded Relief
        case 14:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriNatgeoWorldMapTemplate, 0, 12); // Esri - NatGeo World Map
        case 15:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldNavigationChartsTemplate, 0, 10); // Esri - World Navigation Charts
        case 16:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldPhysicalMapTemplate, 0, 8); // Esri - World Physical Map
        case 17:
            // https://wiki.openstreetmap.org/wiki/Raster_tile_providers
            return new TileServerInfo(ATTRIBUTION_OPENSTREETMAP, URL_PREFIX_NONE, AUTH_TOKEN_TYPE_NONE, Rez.Strings.openstreetmapCyclosmTemplate, 0, 20); // OpenStreetMap - cyclosm
        case 18:
            // stadia (also includes stamen) https://docs.stadiamaps.com/themes/
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaAlidadeSmoothTemplate, 0, 20); // Stadia - Alidade Smooth (auth required)
        case 19:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaAlidadeSmoothDarkTemplate, 0, 20); // Stadia - Alidade Smooth Dark (auth required)
        case 20:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaOutdoorsTemplate, 0, 20); // Stadia - Outdoors (auth required)
        case 21:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaStamenTonerTemplate, 0, 20); // Stadia - Stamen Toner (auth required)
        case 22:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaStamenTonerLiteTemplate, 0, 20); // Stadia - Stamen Toner Lite (auth required)
        case 23:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaStamenTerrainTemplate, 0, 20); // Stadia - Stamen Terrain (auth required)
        case 24:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaStamenWatercolorTemplate, 0, 16); // Stadia - Stamen Watercolor (auth required)
        case 25:
            return new TileServerInfo(ATTRIBUTION_STADIA, URL_PREFIX_STADIA, AUTH_TOKEN_TYPE_STADIA, Rez.Strings.stadiaOsmBrightTemplate, 0, 20); // Stadia - OSM Bright (auth required)
        case 26:
            // carto
            return new TileServerInfo(ATTRIBUTION_CARTO, URL_PREFIX_CARTO, AUTH_TOKEN_TYPE_NONE, Rez.Strings.cartoVoyagerTemplate, 0, 20); // Carto - Voyager
        case 27:
            return new TileServerInfo(ATTRIBUTION_CARTO, URL_PREFIX_CARTO, AUTH_TOKEN_TYPE_NONE, Rez.Strings.cartoDarkMatterTemplate, 0, 20); // Carto - Dark Matter
        case 28:
            return new TileServerInfo(ATTRIBUTION_CARTO, URL_PREFIX_CARTO, AUTH_TOKEN_TYPE_NONE, Rez.Strings.cartoLightAllTemplate, 0, 20); // Carto - Light All
        case 29:
            // Mapy
            return new TileServerInfo(ATTRIBUTION_MAPY, URL_PREFIX_MAPY, AUTH_TOKEN_TYPE_MAPY, Rez.Strings.mapyBasicTemplate, 0, 19); // Mapy - Basic
        case 30:
            return new TileServerInfo(ATTRIBUTION_MAPY, URL_PREFIX_MAPY, AUTH_TOKEN_TYPE_MAPY, Rez.Strings.mapyOutdoorTemplate, 0, 19); // Mapy - Outdoor
        case 31:
            return new TileServerInfo(ATTRIBUTION_MAPY, URL_PREFIX_MAPY, AUTH_TOKEN_TYPE_MAPY, Rez.Strings.mapyWinterTemplate, 0, 19); // Mapy - Winter
        case 32:
            return new TileServerInfo(ATTRIBUTION_MAPY, URL_PREFIX_MAPY, AUTH_TOKEN_TYPE_MAPY, Rez.Strings.mapyAerialTemplate, 0, 13); // Mapy - Aerial
    }
    return null;
}

(:lowMemory)
function getTileServerInfo(id as Number) as TileServerInfo? {
    // prettier-ignore
    // This is an array instead of a dict because dict does not render correctly, also arrays are faster
    // 0 => null, // special custom (no tile property changes will happen)
    // 1 => null, // special companion app (only the tileUrl will be updated)
    switch(id)
    {
        case 2:
            // open topo
            return new TileServerInfo(ATTRIBUTION_OPENTOPOMAP, URL_PREFIX_NONE, AUTH_TOKEN_TYPE_NONE, Rez.Strings.openTopoMapUrlTemplate, 0, 15); // OpenTopoMap
            // google - cannot use returns 404 - works from companion app (userAgent sent)
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}", 0, 20), // "Google - Hybrid"
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}", 0, 20), // "Google - Satellite"
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}", 0, 20), // "Google - Road"
            // new TileServerInfo(ATTRIBUTION_GOOGLE, "https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}", 0, 20), // "Google - Terain"
            // arcgis (esri) - note some of these have been removed due to not enough coverage, and others have had layermin/max altered for australian coverage
            // _Reference maps are all the same - just the location names removing them
            // Note: when testing on the simulator, some of theese occasionaly seem to produce   
            // Error: Invalid Value
            // Details: failed inside handle_image_callback
        case 3:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldImageryTemplate, 0, 20); // Esri - World Imagery
        case 4:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldStreetMapTemplate, 0, 19); // Esri - World Street Map
        case 5:
            return new TileServerInfo(ATTRIBUTION_ESRI, URL_PREFIX_ESRI, AUTH_TOKEN_TYPE_NONE, Rez.Strings.esriWorldTopoMapTemplate, 0, 19); // Esri - World Topo Map
    }
    return null;
}

(:companionTiles)
class TileUpdateHandler {
    var mapChoiceVersion as Number;
    function initialize(_mapChoiceVersion as Number) {
        mapChoiceVersion = _mapChoiceVersion;
    }

    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void {
        if (responseCode != 200) {
            logE("failed TUH: " + responseCode);
            openTileServer();
            return;
        }

        var settings = getApp()._breadcrumbContext.settings;
        if (settings.mapChoiceVersion != mapChoiceVersion || settings.mapChoice != 1) {
            // we have either changed version (and sent out another request that will update), or its no longer the companion app set as the desired choice
            return;
        }

        if (!(data instanceof Dictionary)) {
            logE("failed TUH: wrong type" + data);
            return;
        }

        settings.companionChangedToMaxMin(
            data["tileLayerMin"] as Number,
            data["tileLayerMax"] as Number
        );
    }

    function openTileServer() as Void {
        // PROTOCOL_SEND_OPEN_APP will not work if the tile server is disabled :(
        // also send a toast
        getApp()._breadcrumbContext.webRequestHandler.transmit(
            [PROTOCOL_SEND_OPEN_APP],
            {},
            getApp()._commStatus
        );
        WatchUi.showToast("Tile Server Response Failed", {});
    }
}

// we are getting dangerously close to the app settings limit
// was getting "Unable to serialize app data" in the sim, but after a restart worked fine
// see
// https://forums.garmin.com/developer/connect-iq/f/discussion/409127/unable-to-serialize-app-data---watch-app?pifragment-1298=1#pifragment-1298=1
// is seems like this only happened when:
// * I tried to run on instinct 3 (that only has 128kb of memory)
// * Crashed with OOM
// * Then tried running on the venu2s which has enough memory it fails with "Unable to serialize app data"
// * Reset sim app data and remove apps
// * Works fine
class Settings {
    // todo only load these when needed (but cache them)
    (:imageTiles)
    var attributionImage as WatchUi.BitmapResource =
        WatchUi.loadResource(Rez.Drawables.OpenTopMapAttribution) as BitmapResource;
    var attributionImageType as Number = ATTRIBUTION_OPENTOPOMAP;

    // should be a multiple of 256 (since thats how tiles are stored, though the companion app will render them scaled for you)
    // we will support rounding up though. ie. if we use 50 the 256 tile will be sliced into 6 chunks on the phone, this allows us to support more pixel sizes.
    // so math.ceil should be used what figuring out how many meters a tile is.
    // eg. maybe we cannot do 128 but we can do 120 (this would limit the number of tiles, but the resolution would be slightly off)

    // The smaller tile size, mainly for use with companion app, allows slicing scaledTileSize into smaller tiles
    (:companionTiles)
    var tileSize as Number = 64;
    (:noCompanionTiles)
    var tileSize as Number = 192;

    var fullTileSize as Number = 256; // The tile size on the tile server
    // The tile size to scale images to, results in significantly smaller downloads (and faster speeds) but makes image slightly blurry.
    // 190 seems to be a good compromise between speed and crisp images. it does not effect the image too much, but gives us about 2X the speed.
    // 128 is a bit too blurry, but would be fine on some maps (anything without words)
    var scaledTileSize as Number = 192; // should be a multiple of the default tileSize
    // website says: Worldwide, Zoom to 17. (Zoom limited to 15 on website opentopomap.org)
    // real world test showed 17 produced errors (maybe you need to be authed to get this?)
    var tileLayerMax as Number = 15;
    var tileLayerMin as Number = 0;
    // there is both a memory limit to the number of tiles we can store, as well as a storage limit
    // for now this is both, though we may be able to store more than we can in memory
    // so we could use the storage as a tile cache, and revert to loading from there, as it would be much faster than
    // fetching over bluetooth
    // not sure if we can even store bitmaps into storage, it says only BitmapResource
    // id have to serialise it to an array and back out (might not be too hard)
    // 64 is enough to render outside the screen a bit 64*64 tiles with 64 tiles gives us 512*512 worth of pixel data

    // did some tests in the sim (render mode buffered rotations - so we also have the giant scratchpad bitmap active, suspect that why memory starts at ~115.0k)
    // no tiles 114.8kb used memory
    // 36 64*64 tiles 132.5kb = ~0.491
    // 64 64*64 tiles 144.9kb = ~0.4703125 per 64*64 tile
    // make image request
    // cleared 115.0k
    // 18 192*192 tiles 120.3k = ~0.294k per tile - less than the 64*64 tiles possibly because it stored as an optimised png image instead of a bitmap?
    // 64 64*64 tiles 145.0k = ~0.468 per tile
    // what I did notice though is that I can have many more tiles of 64*64 even though each tile is larger. The 192*192 image tiles crash the system at ~20 tiles with OOM errors.
    // Think its not registering correctly with System.getSystemStats().usedMemory, since its graphics memory pool
    // 95 64*64 tiles 180.0k (though sim was spitting out error saying it could not render) = ~ 0.684
    // so its ~0.000146484375k per pixel
    // there appears to be some overhead though

    // with render mode unbuffered roatations (no scratchpad bitmap)
    // 100 64*64 tiles 174.0k
    // cleared after we are now at 132.4K - go figure, larger than with the scratchpad

    // restart sim with nothing render mode unbuffered rotations (no scratchpad bitmap)
    // cleared - 114.9K
    // changed render mode to buffered rotations - 115.1K so scratchpad has almost 0 effect?
    // a small route is like 3K
    // graphics memory pool is

    // using the memory view (which crashes constantly) instead of the on device System.getSystemStats().usedMemory
    // graphics pool memeory only
    // 36 64*64 tiles 16496b =  .45822k per tile          // note: this is about the same as previous calcs, image resources must be stored differently to bufferedbitmaps
    // 13 192X192 tiles 73840b = 5.680k per tile  0.000154k per pixel - consistent with previous calcs

    const BYTES_PER_PIXEL = 0.15f;
    (:companionTiles)
    var tileCacheSize as Number = 64;
    (:noCompanionTiles)
    var tileCacheSize as Number = 8;
    var mode as Number = MODE_NORMAL;
    var elevationMode as Number = ELEVATION_MODE_STACKED;
    var mapEnabled as Boolean = false;
    // cache the tiles in storage when they are loaded, allows for fully offline maps
    // unfortunately buffered bitmaps cannot be stored into storage (resources and BitMapResources can be, but not the buffered kind)
    // so we need to store the result of makeImageRequest or makeWebRequest
    var cacheTilesInStorage as Boolean = false;
    var storageMapTilesOnly as Boolean = false;
    // storage seems to fill up around 200 with 192*192 tiles from image requests
    // can be much larger for companion app is used, since the tiles can be much smaller with TILE_DATA_TYPE_BASE64_FULL_COLOUR
    // saw a crash around 513 tiles, which would be from our internal array StorageTileCache._tilesInStorage
    var storageTileCacheSize as Number = 150;
    var storageSeedBoundingBox as Boolean = false; // seed entire bounding box
    var storageSeedRouteDistanceM as Float = 10f; // if seeding based on route (storageSeedBoundingBox = false) seed this far around the route
    var storageTileCachePageCount as Number = 1;

    var trackColour as Number = Graphics.COLOR_GREEN;
    var defaultRouteColour as Number = Graphics.COLOR_BLUE;
    var elevationColour as Number = Graphics.COLOR_ORANGE;
    var userColour as Number = Graphics.COLOR_ORANGE;
    // this should probably be the same as tileCacheSize? since there is no point having 20 outstanding if we can only store 10 of them
    var maxPendingWebRequests as Number = 5;
    // Renders around the users position
    var metersAroundUser as Number = 500; // keep this fairly high by default, too small and the map tiles start to go blurry
    var centerUserOffsetY as Float = 0.5f; // fraction of the screen to move the user down the page 0.5 - user appears in center, 0.75 - user appears 3/4 down the screen. Useful to see more of the route in front of the user.
    var mapMoveScreenSize as Float = 0.3f; // how far to move the map when the user presses on screen buttons, a fraction of the screen size.
    var zoomAtPaceMode as Number = ZOOM_AT_PACE_MODE_PACE;
    var zoomAtPaceSpeedMPS as Float = 1.0; // meters per second
    var useTrackAsHeadingSpeedMPS as Float = 1000f; // meters per second
    var topDataType as Number = DATA_TYPE_NONE;
    var bottomDataType as Number = DATA_TYPE_SCALE;
    var dataFieldTextSize as Number = Graphics.FONT_XTINY;
    var minTrackPointDistanceM as Number = 5; // minimum distance between 2 track points
    var trackPointReductionMethod as Number = TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE;
    var uiMode as Number = UI_MODE_SHOW_ALL;
    var fixedLatitude as Float? = null;
    var fixedLongitude as Float? = null;
    // supports place holders such as
    // use http://127.0.0.1:8080 for companion app
    // but you can also use something like https://a.tile.opentopomap.org/{z}/{x}/{y}.png
    // to make this work on the emulator you ned to run
    // adb forward tcp:8080 tcp:8080
    (:companionTiles)
    var tileUrl as String = COMPANION_APP_TILE_URL;
    (:noCompanionTiles)
    var tileUrl as String = "https://a.tile.opentopomap.org/{z}/{x}/{y}.png";
    var authToken as String = "";
    var requiresAuth as Boolean = false;
    (:companionTiles)
    var mapChoice as Number = 0;
    (:noCompanionTiles)
    var mapChoice as Number = 2;
    var mapChoiceVersion as Number = 0;
    // see keys below in routes = getArraySchema(...)
    // see oddity with route name and route loading new in context.newRoute
    var routes as Array<Dictionary> = [];
    var routesEnabled as Boolean = true;
    var disableMapsFailureCount as Number = 200; // 0 for unlimited
    var displayRouteNames as Boolean = true;
    var normalModeColour as Number = Graphics.COLOR_BLUE;
    var uiColour as Number = Graphics.COLOR_DK_GRAY;
    var debugColour as Number = 0xfeffffff; // white, but colour_white results in FFFFFFFF (-1) when we parse it and that is fully transparent
    // I did get up to 4 large routes working with off track alerts, but any more than that and watchdog catches us out, 3 is a safer limit.
    // currently we still load disabled routes into memory, so its also not great having this large and a heap of disabled routes
    private var _routeMax as Number = 3;

    // note this only works if a single track is enabled (multiple tracks would always error)
    var enableOffTrackAlerts as Boolean = true;
    var offTrackAlertsDistanceM as Number = 20;
    var offTrackAlertsMaxReportIntervalS as Number = 60;
    var offTrackCheckIntervalS as Number = 15;
    var alertType as Number = ALERT_TYPE_TOAST;
    var offTrackWrongDirection as Boolean = false;
    var drawCheverons as Boolean = false;

    var drawLineToClosestPoint as Boolean = true;
    var displayLatLong as Boolean = true;
    private var _scaleRestrictedToTileLayers as Boolean = false; // scale will be restricted to the tile layers - could do more optimised render in future
    // https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html#PackingFormat-module
    // some devices do not support other colour pallets, and need to use default pallet and drawBitmap instead of drawBitmap2
    var packingFormat as Number = 1;
    var useDrawBitmap as Boolean = false; // implies scaleRestrictedToTileLayers, since the renders will be off if we do not

    // scratchpad used for rotations, but it also means we have a large bitmap stored around
    // I will also use that bitmap for re-renders though, and just do rotations every render rather than re-drawing all the tracks/tiles again
    var renderMode as Number = RENDER_MODE_BUFFERED_ROTATING;
    // how many seconds should we wait before even considering the next point
    // changes in speed/angle/zoom are not effected by this number. Though maybe they should be?
    var recalculateIntervalS as Number = 5;
    // pre seed tiles on either side of the viewable area
    var tileCachePadding as Number = 0;
    var httpErrorTileTTLS as Number = 60;
    var errorTileTTLS as Number = 20; // other errors are from garmin ble connection issues, retry faster by default
    var turnAlertTimeS as Number = -1; // -1 disables the check
    var minTurnAlertDistanceM as Number = -1; // -1 disables the check
    var maxTrackPoints as Number = 400;
    var trackStyle as Number = TRACK_STYLE_LINE;
    var trackWidth as Number = 4;

    // bunch of debug settings
    var showPoints as Boolean = false;
    var drawLineToClosestTrack as Boolean = false;
    var showTileBorders as Boolean = false;
    var showErrorTileMessages as Boolean = false;
    var tileErrorColour as Number = Graphics.COLOR_BLACK;
    var includeDebugPageInOnScreenUi as Boolean = false;
    var drawHitBoxes as Boolean = false;
    var showDirectionPoints as Boolean = false;
    var showDirectionPointTextUnderIndex as Number = 0;

    // these settings can only be modified externally, but we cache them for faster/easier lookup
    // https://www.youtube.com/watch?v=LasrD6SZkZk&ab_channel=JaylaB
    var distanceImperialUnits as Boolean =
        System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE;
    var elevationImperialUnits as Boolean =
        System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE;
    var trackTexture as Graphics.BitmapTexture or Number = -1; // -1 is to say use colour instead
    var routeTextures as Array<Graphics.BitmapTexture or Number> = []; // -1 is to say use colour instead

    (:lowMemory)
    function routeMax() as Number {
        return 1; // can only get 1 route (second route crashed on storage save), we also still need space for the track
    }

    (:highMemory)
    function routeMax() as Number {
        return _routeMax;
    }

    function setMode(_mode as Number) as Void {
        mode = _mode;
        // directly set mode, its only for what is displayed, which takes effect ont he next onUpdate
        // we do not want to call view.onSettingsChanged because it clears timestamps when going to the debug page.
        // The setValue method on this class calls the view changed method, so do not call it.
        Application.Properties.setValue("mode", mode);
    }

    (:settingsView)
    function setElevationMode(value as Number) as Void {
        elevationMode = value;
        setValue("elevationMode", elevationMode);
    }

    (:settingsView)
    function setUiMode(_uiMode as Number) as Void {
        uiMode = _uiMode;
        setValue("uiMode", uiMode);
    }

    (:settingsView)
    function setAlertType(_alertType as Number) as Void {
        alertType = _alertType;
        setValue("alertType", alertType);
    }

    (:settingsView)
    function setRenderMode(_renderMode as Number) as Void {
        renderMode = _renderMode;
        setValue("renderMode", renderMode);
        updateCachedValues();
        updateViewSettings();
    }

    function setFixedPositionRaw(lat as Float, long as Float) as Void {
        // hack method so that cached values can update the settings without reloading itself
        // its guaranteed to only be when moving around, and will never go to null
        fixedLatitude = lat;
        fixedLongitude = long;
        Application.Properties.setValue("fixedLatitude", lat);
        Application.Properties.setValue("fixedLongitude", long);
        clearPendingWebRequests();
    }

    function setFixedPosition(lat as Float?, long as Float?, clearRequests as Boolean) as Void {
        // logT("moving to: " + lat + " " + long);
        // be very careful about putting null into properties, it breaks everything
        if (lat == null || !(lat instanceof Float)) {
            lat = 0f;
        }
        if (long == null || !(long instanceof Float)) {
            long = 0f;
        }
        fixedLatitude = lat;
        fixedLongitude = long;
        setValue("fixedLatitude", lat);
        setValue("fixedLongitude", long);

        var latIsBasicallyNull = fixedLatitude == null || fixedLatitude == 0;
        var longIsBasicallyNull = fixedLongitude == null || fixedLongitude == 0;
        if (latIsBasicallyNull || longIsBasicallyNull) {
            fixedLatitude = null;
            fixedLongitude = null;
            if (clearRequests) {
                clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
            }
            updateCachedValues();
            return;
        }

        // we should have a lat and a long at this point
        // updateCachedValues(); already called by the above sets
        // var latlong = RectangularPoint.xyToLatLon(fixedPosition.x, fixedPosition.y);
        // logT("round trip conversion result: " + latlong);
        if (clearRequests) {
            clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
        }
    }

    function setFixedPositionWithoutUpdate(
        lat as Float?,
        long as Float?,
        clearRequests as Boolean
    ) as Void {
        // logT("moving to: " + lat + " " + long);
        // be very careful about putting null into properties, it breaks everything
        if (lat == null || !(lat instanceof Float)) {
            lat = 0f;
        }
        if (long == null || !(long instanceof Float)) {
            long = 0f;
        }
        fixedLatitude = lat;
        fixedLongitude = long;
        Application.Properties.setValue("fixedLatitude", lat);
        Application.Properties.setValue("fixedLongitude", long);

        var latIsBasicallyNull = fixedLatitude == null || fixedLatitude == 0;
        var longIsBasicallyNull = fixedLongitude == null || fixedLongitude == 0;
        if (latIsBasicallyNull || longIsBasicallyNull) {
            fixedLatitude = null;
            fixedLongitude = null;
            if (clearRequests) {
                clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
            }
            updateCachedValues();
            return;
        }

        // we should have a lat and a long at this point
        // updateCachedValues(); already called by the above sets
        // var latlong = RectangularPoint.xyToLatLon(fixedPosition.x, fixedPosition.y);
        // logT("round trip conversion result: " + latlong);
        if (clearRequests) {
            clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
        }
    }

    function setValue(key as String, value as PropertyValueType) as Void {
        Application.Properties.setValue(key, value);
        setValueSideEffect();
    }

    function setValueSideEffect() as Void {
        updateCachedValues();
        updateViewSettings();
        updateRouteSettings();
    }

    function setZoomAtPaceMode(_zoomAtPaceMode as Number) as Void {
        zoomAtPaceMode = _zoomAtPaceMode;
        setValue("zoomAtPaceMode", zoomAtPaceMode);
    }

    (:settingsView)
    function setMapChoice(value as Number) as Void {
        setMapChoiceWithoutSideEffect(value);
        setValueSideEffect();
        mapChoiceChanged();
    }

    function setMapChoiceWithoutSideEffect(value as Number) as Void {
        mapChoice = value;
        Application.Properties.setValue("mapChoice", mapChoice);
    }

    function mapChoiceChanged() as Void {
        updateMapChoiceChange(mapChoice);
        updateCachedValues();
        updateViewSettings();
    }

    function authMissing() as Boolean {
        return requiresAuth && authToken.equals("");
    }

    (:noCompanionTiles)
    function mapChoiceValid() as Boolean {
        if (tileUrl.equals(COMPANION_APP_TILE_URL)) {
            return false;
        }

        return mapChoice == 0 /*custom*/ || getTileServerInfo(mapChoice) != null;
    }

    (:companionTiles)
    function mapChoiceValid() as Boolean {
        return (
            mapChoice == 0 /*custom*/ ||
            mapChoice == 1 /*companion*/ ||
            getTileServerInfo(mapChoice) != null
        );
    }

    (:noImageTiles)
    function getAttribution() as WatchUi.BitmapResource? {
        return null;
    }

    (:imageTiles)
    function getAttribution() as WatchUi.BitmapResource? {
        if (mapChoice == 0) {
            // custom - no way to know which tile server
            return null;
        } else if (mapChoice == 1) {
            // companion app - attributions in the companion app (no way to know what image tiles we are getting)
            return null;
        }

        var tileServerInfo = getTileServerInfo(mapChoice);
        if (tileServerInfo == null) {
            return null; // invalid selection
        }

        if (tileServerInfo.attributionType != attributionImageType) {
            switch (tileServerInfo.attributionType) {
                case ATTRIBUTION_OPENTOPOMAP:
                    attributionImage =
                        WatchUi.loadResource(Rez.Drawables.OpenTopMapAttribution) as BitmapResource;
                    break;
                case ATTRIBUTION_ESRI:
                    attributionImage =
                        WatchUi.loadResource(Rez.Drawables.EsriAttribution) as BitmapResource;
                    break;
                case ATTRIBUTION_OPENSTREETMAP:
                    attributionImage =
                        WatchUi.loadResource(Rez.Drawables.OpenStreetMapAttribution) as
                        BitmapResource;
                    break;
                case ATTRIBUTION_STADIA:
                    attributionImage =
                        WatchUi.loadResource(Rez.Drawables.StadiaAttribution) as BitmapResource;
                    break;
                case ATTRIBUTION_CARTO:
                    attributionImage =
                        WatchUi.loadResource(Rez.Drawables.CartoAttribution) as BitmapResource;
                    break;
                case ATTRIBUTION_MAPY:
                    attributionImage =
                        WatchUi.loadResource(Rez.Drawables.MapyAttribution) as BitmapResource;
                    break;
            }
        }

        attributionImageType = tileServerInfo.attributionType;
        return attributionImage;
    }

    (:lowMemory)
    function maxTileCacheSizeGuess() as Number {
        return 8; // its in graphics memory, so it `should` be fine
    }

    // this is a wild guess, its only used to try and protect users
    // they can set it higher after configuring the tile server choice, or custom mode is full hands off
    // this is just to ry and limit it for users when they ar simply selecting a new map choice
    (:highMemory)
    function maxTileCacheSizeGuess() as Number {
        var ROUTE_SIZE_BYTES = 7000; // a large route loaded onto the device
        // var MAX_CACHE_SIZE_USER_PROTECT_BYTES = 80 /*tiles*/ *64*64 /*tile size*/ * BYTES_PER_PIXEL;
        var availableMemBytes = System.getSystemStats().totalMemory - 116000; // magic number we saw in testing with 0 routes loaded
        availableMemBytes -= ROUTE_SIZE_BYTES * routeMax();
        var OVERHEAD_PER_BITMAP_BYTES = 650; // larger image tiles seem to work better (we want smaller tiles to be effected by this more)
        // I pretty much want perfectSize to be ~20 for large image tiles (192*192) and ~90 for small buffered bitmap tiles (64*64)
        // so adjust OVERHEAD_PER_BITMAP_BYTES accordingly
        // all calcs done on venu2s, smaller memory watches will be smaller
        var perfectSize =
            availableMemBytes / (tileSize * tileSize * BYTES_PER_PIXEL + OVERHEAD_PER_BITMAP_BYTES);
        return maxN(1, Math.floor(perfectSize * 0.85).toNumber()); // give ourselves a bit of a buffer
    }

    function maxStorageTileCacheSizeGuess() as Number {
        // StorageTileCache._tilesInStorage is the limiting factor for companion app tiles when using TILE_DATA_TYPE_BASE64_FULL_COLOUR
        // but storage size is the limiting factor for 192*192 image tiles
        // since there is no way to know if we are using TILE_DATA_TYPE_BASE64_FULL_COLOUR or some other mode we will just assume its that
        // see notes above on storageTileCacheSize variable
        return maxTileCacheSizeGuess() * 4; // this will result in ~64 for image tiles and ~324 for companion app 64*64 tiles
    }

    (:noCompanionTiles)
    function updateCompanionAppMapChoiceChange() as Void {}
    (:companionTiles)
    function updateCompanionAppMapChoiceChange() as Void {
        // setting back to defaults otherwise when we chose companion app we will not get the correct tilesize and it will crash
        var defaultSettings = new Settings();
        // we want a tile layer that all tile servers should be able to show, it should also be low enough that users see there is a problem
        // these values will be updated by companion app when tile server changes, or the query below
        setTileLayerMaxWithoutSideEffect(8);
        setTileLayerMinWithoutSideEffect(0);
        if (!tileUrl.equals(COMPANION_APP_TILE_URL)) {
            setTileUrlWithoutSideEffect(COMPANION_APP_TILE_URL);
        }
        if (fullTileSize != defaultSettings.fullTileSize) {
            setFullTileSizeWithoutSideEffect(defaultSettings.fullTileSize);
        }
        if (scaledTileSize != defaultSettings.scaledTileSize) {
            setScaledTileSizeWithoutSideEffect(defaultSettings.scaledTileSize);
        }
        if (tileSize != defaultSettings.tileSize) {
            setTileSizeWithoutSideEffect(defaultSettings.tileSize);
        }
        var tileCacheMax = maxTileCacheSizeGuess();
        if (tileCacheSize > tileCacheMax) {
            logD("limiting tile cache size to: " + tileCacheMax);
            setTileCacheSizeWithoutSideEffect(tileCacheMax);
        }
        var storageTileCacheSizeMax = maxStorageTileCacheSizeGuess();
        if (storageTileCacheSize > storageTileCacheSizeMax) {
            logD("limiting storage tile cache size to: " + storageTileCacheSizeMax);
            setStorageTileCacheSizeWithoutSideEffect(storageTileCacheSizeMax);
        }

        // grab the min and max from the tile server
        getApp()._breadcrumbContext.webRequestHandler.addHighPriority(
            new JsonRequest(
                "TUH-" + mapChoiceVersion,
                tileUrl + "/tileServerDetails",
                {},
                new TileUpdateHandler(mapChoiceVersion)
            )
        );

        return;
    }

    (:noImageTiles)
    function updateTileServerMapChoiceChange(tileServerInfo as TileServerInfo) as Void {}

    (:imageTiles)
    function updateTileServerMapChoiceChange(tileServerInfo as TileServerInfo) as Void {
        var defaultSettings = new Settings();
        // auth token added later
        var newUrl =
            getUrlPrefix(tileServerInfo.urlPrefix) +
            tileServerInfo.urlTemplate +
            getAuthTokenSuffix(tileServerInfo.authTokenType);
        if (!tileUrl.equals(newUrl)) {
            // set url last to clear tile cache (if needed)
            setTileUrlWithoutSideEffect(newUrl);
        }
        if (tileLayerMax != tileServerInfo.tileLayerMax) {
            setTileLayerMaxWithoutSideEffect(tileServerInfo.tileLayerMax);
        }
        if (tileLayerMin != tileServerInfo.tileLayerMin) {
            setTileLayerMinWithoutSideEffect(tileServerInfo.tileLayerMin);
        }
        if (fullTileSize != 256) {
            setFullTileSizeWithoutSideEffect(256);
        }
        // todo: reduce this to 128 for better results
        if (scaledTileSize != defaultSettings.scaledTileSize) {
            setScaledTileSizeWithoutSideEffect(defaultSettings.scaledTileSize);
        }
        if (tileSize != defaultSettings.scaledTileSize) {
            setTileSizeWithoutSideEffect(defaultSettings.scaledTileSize);
        }
        var tileCacheMax = maxTileCacheSizeGuess();
        if (tileCacheSize > tileCacheMax) {
            logD("limiting tile cache size to: " + tileCacheMax);
            setTileCacheSizeWithoutSideEffect(tileCacheMax);
        }
        var storageTileCacheSizeMax = maxStorageTileCacheSizeGuess();
        if (storageTileCacheSize > storageTileCacheSizeMax) {
            logD("limiting storage tile cache size to: " + storageTileCacheSizeMax);
            setStorageTileCacheSizeWithoutSideEffect(storageTileCacheSizeMax);
        }
    }

    function companionChangedToMaxMin(minLayer as Number, maxLayer as Number) as Void {
        // we need to to force the url to be companion app
        // update to be custom (since companion app url will override tile layers)
        // This does mean when the users selects companion app on the watch settings it might not match the currently
        // configured tile server max/min on the companion app
        // assert(tileUrl.equals(COMPANION_APP_TILE_URL));

        // if the users goes custom and has the companion app url, we still do not update the tiles layers
        // this is because they may be artificially capping the tileLayerMax property eg. a tile server on the phone that has 20 layers, but the user only wants
        // 15 layers on the watch in order to be able to run offline tiles and store them all.
        if (mapChoice != 1) {
            // we are no longer on the companion app, abort
            return;
        }

        setTileLayerMaxWithoutSideEffect(maxLayer);
        setTileLayerMinWithoutSideEffect(minLayer);
        setValueSideEffect();
    }

    function updateMapChoiceChange(value as Number) as Void {
        // we need to store the last one we processed seperately so we can know on startup if the setting changed underneath us
        var lastMapChoice = Application.Storage.getValue("lastMapChoice");
        if (lastMapChoice == null || (lastMapChoice instanceof Number and lastMapChoice != value)) {
            updateMapChoiceChangeInner(value);
        }
        safeSetStorage("lastMapChoice", value);
    }

    function updateMapChoiceChangeInner(value as Number) as Void {
        ++mapChoiceVersion;

        if (value == 0) {
            // custom - leave everything alone
            return;
        } else if (value == 1) {
            // companion app
            updateCompanionAppMapChoiceChange();
            return;
        }

        var tileServerInfo = getTileServerInfo(value);
        if (tileServerInfo == null) {
            return; // invalid selection
        }
        updateTileServerMapChoiceChange(tileServerInfo);
    }

    (:settingsView)
    function setTileUrl(_tileUrl as String) as Void {
        setTileUrlWithoutSideEffect(_tileUrl);
        setValueSideEffect();
    }

    function setTileUrlWithoutSideEffect(_tileUrl as String) as Void {
        tileUrl = _tileUrl;
        Application.Properties.setValue("tileUrl", tileUrl);
        tileUrlChanged();
    }

    function tileUrlChanged() as Void {
        clearPendingWebRequests();
        clearTileCache();
        clearTileCacheStats();
        clearWebStats();
        updateRequiresAuth();

        // prompts user to open the app
        if (tileUrl.equals(COMPANION_APP_TILE_URL) && !storageMapTilesOnly) {
            // we could also send a toast, but the transmit allows us to open the app easier on the phone
            // even though the phone side is a bit of a hack (ConnectIQMessageReceiver cannot parse the data), it's still better than having to manualy open the app.
            transmit([PROTOCOL_SEND_OPEN_APP], {}, getApp()._commStatus);
        }
    }

    function updateRequiresAuth() as Void {
        requiresAuth = tileUrl.find("{authToken}") != null;
    }

    (:settingsView)
    function setAuthToken(value as String) as Void {
        authToken = value;
        setValue("authToken", authToken);
        tileServerPropChanged();
    }

    (:settingsView)
    function setZoomAtPaceSpeedMPS(mps as Float) as Void {
        zoomAtPaceSpeedMPS = mps;
        setValue("zoomAtPaceSpeedMPS", zoomAtPaceSpeedMPS);
    }

    (:settingsView)
    function setUseTrackAsHeadingSpeedMPS(mps as Float) as Void {
        useTrackAsHeadingSpeedMPS = mps;
        setValue("useTrackAsHeadingSpeedMPS", useTrackAsHeadingSpeedMPS);
    }

    (:settingsView)
    function setMetersAroundUser(value as Number) as Void {
        metersAroundUser = value;
        setValue("metersAroundUser", metersAroundUser);
    }

    (:settingsView)
    function setTopDataType(value as Number) as Void {
        topDataType = value;
        setValue("topDataType", topDataType);
    }

    (:settingsView)
    function setBottomDataType(value as Number) as Void {
        bottomDataType = value;
        setValue("bottomDataType", bottomDataType);
    }

    (:settingsView)
    function setMinTrackPointDistanceM(value as Number) as Void {
        minTrackPointDistanceM = value;
        setValue("minTrackPointDistanceM", minTrackPointDistanceM);
        setMinTrackPointDistanceMSideEffect();
    }

    function setMinTrackPointDistanceMSideEffect() as Void {
        // only the track needs the setting, routes do not matter, they can stay at the default (5m) because they are limited by the companion app anyway
        getApp()._breadcrumbContext.track.setMinDistanceM(
            minTrackPointDistanceM.toFloat(),
            getApp()._breadcrumbContext.cachedValues.currentScale
        );
    }

    (:settingsView)
    function setTrackPointReductionMethod(value as Number) as Void {
        trackPointReductionMethod = value;
        setValue("trackPointReductionMethod", trackPointReductionMethod);
    }

    (:settingsView)
    function setDataFieldTextSize(value as Number) as Void {
        dataFieldTextSize = value;
        setValue("dataFieldTextSize", dataFieldTextSize);
    }

    (:settingsView)
    function setFixedLatitude(value as Float) as Void {
        setFixedPosition(value, fixedLongitude, true);
    }

    (:settingsView)
    function setFixedLongitude(value as Float) as Void {
        setFixedPosition(fixedLatitude, value, true);
    }

    (:settingsView)
    function setMaxPendingWebRequests(value as Number) as Void {
        maxPendingWebRequests = value;
        setValue("maxPendingWebRequests", maxPendingWebRequests);
    }

    (:settingsView)
    function setTileSize(value as Number) as Void {
        setTileSizeWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setTileSizeWithoutSideEffect(value as Number) as Void {
        tileSize = value;
        if (!tileUrl.equals(COMPANION_APP_TILE_URL)) {
            tileSize = scaledTileSize;
        }
        Application.Properties.setValue("tileSize", tileSize);
        tileServerPropChanged();
    }

    function tileServerPropChanged() as Void {
        clearPendingWebRequests();
        clearTileCache();
    }

    (:settingsView)
    function setHttpErrorTileTTLS(value as Number) as Void {
        httpErrorTileTTLS = value;
        setValue("httpErrorTileTTLS", httpErrorTileTTLS);
        tileServerPropChanged();
    }

    (:settingsView)
    function setTurnAlertTimeS(value as Number) as Void {
        turnAlertTimeS = value;
        setValue("turnAlertTimeS", turnAlertTimeS);
    }

    (:settingsView)
    function setMinTurnAlertDistanceM(value as Number) as Void {
        minTurnAlertDistanceM = value;
        setValue("minTurnAlertDistanceM", minTurnAlertDistanceM);
    }

    (:settingsView)
    function setMaxTrackPoints(value as Number) as Void {
        var oldmaxTrackPoints = maxTrackPoints;
        maxTrackPoints = value;
        if (oldmaxTrackPoints != maxTrackPoints) {
            maxTrackPointsChanged();
        }
        setValue("maxTrackPoints", maxTrackPoints);
    }

    (:settingsView)
    function setTrackStyle(value as Number) as Void {
        trackStyle = value;
        setValue("trackStyle", trackStyle);
        recomputeTrackTexture();
    }

    (:settingsView)
    function setTrackWidth(value as Number) as Void {
        trackWidth = value;
        setValue("trackWidth", trackWidth);
        recomputeTrackTexture();
    }

    function maxTrackPointsChanged() as Void {
        getApp()._breadcrumbContext.track.coordinates.restrictPointsToMaxMemory(
            maxTrackPoints,
            getApp()._breadcrumbContext.settings.trackPointReductionMethod,
            getApp()._breadcrumbContext.cachedValues.currentScale
        );
    }

    (:settingsView)
    function setShowDirectionPointTextUnderIndex(value as Number) as Void {
        showDirectionPointTextUnderIndex = value;
        setValue("showDirectionPointTextUnderIndex", showDirectionPointTextUnderIndex);
    }

    (:settingsView)
    function setErrorTileTTLS(value as Number) as Void {
        errorTileTTLS = value;
        setValue("errorTileTTLS", errorTileTTLS);
        tileServerPropChanged();
    }

    (:settingsView)
    function setFullTileSize(value as Number) as Void {
        setFullTileSizeWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setFullTileSizeWithoutSideEffect(value as Number) as Void {
        fullTileSize = value;
        Application.Properties.setValue("fullTileSize", fullTileSize);
        tileServerPropChanged();
    }

    (:settingsView)
    function setScaledTileSize(value as Number) as Void {
        setScaledTileSizeWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setScaledTileSizeWithoutSideEffect(value as Number) as Void {
        scaledTileSize = value;
        if (useDrawBitmap) {
            scaledTileSize = fullTileSize;
        }
        Application.Properties.setValue("scaledTileSize", scaledTileSize);
        if (!tileUrl.equals(COMPANION_APP_TILE_URL)) {
            setTileSizeWithoutSideEffect(scaledTileSize);
        }
        tileServerPropChanged();
    }

    (:settingsView)
    function setPackingFormat(value as Number) as Void {
        setPackingFormatWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setPackingFormatWithoutSideEffect(value as Number) as Void {
        packingFormat = value;
        Application.Properties.setValue("packingFormat", packingFormat);
        tileServerPropChanged();
    }

    (:settingsView)
    function setUseDrawBitmap(value as Boolean) as Void {
        setUseDrawBitmapWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setUseDrawBitmapWithoutSideEffect(value as Boolean) as Void {
        useDrawBitmap = value;
        Application.Properties.setValue("useDrawBitmap", useDrawBitmap);
        if (useDrawBitmap) {
            setScaledTileSizeWithoutSideEffect(fullTileSize);
        }
        tileServerPropChanged();
    }

    (:settingsView)
    function setTileLayerMax(value as Number) as Void {
        setTileLayerMaxWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setTileLayerMaxWithoutSideEffect(value as Number) as Void {
        tileLayerMax = value;
        Application.Properties.setValue("tileLayerMax", tileLayerMax);
    }

    (:settingsView)
    function setTileLayerMin(value as Number) as Void {
        setTileLayerMinWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setTileLayerMinWithoutSideEffect(value as Number) as Void {
        tileLayerMin = value;
        Application.Properties.setValue("tileLayerMin", tileLayerMin);
    }

    (:settingsView)
    function setDisableMapsFailureCount(value as Number) as Void {
        disableMapsFailureCount = value;
        setValue("disableMapsFailureCount", disableMapsFailureCount);
    }

    (:settingsView)
    function setOffTrackAlertsDistanceM(value as Number) as Void {
        offTrackAlertsDistanceM = value;
        setValue("offTrackAlertsDistanceM", offTrackAlertsDistanceM);
        updateViewSettings();
    }

    (:settingsView)
    function setOffTrackAlertsMaxReportIntervalS(value as Number) as Void {
        offTrackAlertsMaxReportIntervalS = value;
        setValue("offTrackAlertsMaxReportIntervalS", offTrackAlertsMaxReportIntervalS);
        updateViewSettings();
    }

    (:settingsView)
    function setOffTrackCheckIntervalS(value as Number) as Void {
        offTrackCheckIntervalS = value;
        setValue("offTrackCheckIntervalS", offTrackCheckIntervalS);
        updateViewSettings();
    }

    (:settingsView)
    function setRouteMax(value as Number) as Void {
        var oldRouteMax = _routeMax;
        _routeMax = value;
        if (oldRouteMax > _routeMax) {
            routeMaxReduced();
        }
        setValue("routeMax", _routeMax);
        updateCachedValues();
        updateViewSettings();
    }

    function routeMaxReduced() as Void {
        // remove the first oes or the last ones? we do not have an age, so just remove the last ones.
        var routesToRemove = [] as Array<Number>;
        for (var i = _routeMax; i < routes.size(); ++i) {
            var oldRouteEntry = routes[i];
            var oldRouteId = oldRouteEntry["routeId"] as Number;
            routesToRemove.add(oldRouteId);
        }
        for (var i = 0; i < routesToRemove.size(); ++i) {
            var routeId = routesToRemove[i];
            clearRouteFromContext(routeId);
            // do not use the clear route helper method, it will stack overflow
            var routeIndex = getRouteIndexById(routeId);
            if (routeIndex == null) {
                continue;
            }
            routes.remove(routes[routeIndex]);
        }

        saveRoutesNoSideEffect();
    }

    (:settingsView)
    function setTileCacheSize(value as Number) as Void {
        setTileCacheSizeWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setTileCacheSizeWithoutSideEffect(value as Number) as Void {
        var oldTileCacheSize = tileCacheSize;
        tileCacheSize = value;
        Application.Properties.setValue("tileCacheSize", tileCacheSize);

        if (oldTileCacheSize > tileCacheSize) {
            // only nuke tile cache if we reduce the number of tiles we can store
            tileCacheSizeReduced();
        }
    }

    function tileCacheSizeReduced() as Void {
        clearPendingWebRequests();
        getApp()._breadcrumbContext.tileCache.clearValuesWithoutStorage(); // do not remove our cached tiles, we only reduced the caches size, so they are still valid
    }

    function storageTileCacheSizeReduced() as Void {
        getApp()._breadcrumbContext.tileCache._storageTileCache.clearValues();
    }

    (:settingsView)
    function setStorageTileCacheSize(value as Number) as Void {
        setStorageTileCacheSizeWithoutSideEffect(value);
        setValueSideEffect();
    }
    function setStorageTileCacheSizeWithoutSideEffect(value as Number) as Void {
        var oldStorageTileCacheSize = storageTileCacheSize;
        storageTileCacheSize = value;
        Application.Properties.setValue("storageTileCacheSize", storageTileCacheSize);

        if (oldStorageTileCacheSize > storageTileCacheSize) {
            // only nuke storage tile cache if we reduce the number of tiles we can store
            storageTileCacheSizeReduced();
        }
    }

    (:settingsView)
    function setStorageTileCachePageCount(value as Number) as Void {
        var oldStorageTileCachePageCount = storageTileCachePageCount;
        storageTileCachePageCount = value;
        if (oldStorageTileCachePageCount != storageTileCachePageCount) {
            storageTilePageCountChanged();
        }
        setValue("storageTileCachePageCount", storageTileCachePageCount);
    }

    function storageTilePageCountChanged() as Void {
        getApp()._breadcrumbContext.tileCache._storageTileCache.setNewPageCount(
            storageTileCachePageCount
        );
    }

    (:settingsView)
    function setTileCachePadding(value as Number) as Void {
        tileCachePadding = value;
        setValue("tileCachePadding", tileCachePadding);
    }

    (:settingsView)
    function setStorageSeedRouteDistanceM(value as Float) as Void {
        storageSeedRouteDistanceM = value;
        setValue("storageSeedRouteDistanceM", storageSeedRouteDistanceM);
    }

    (:settingsView)
    function setMapMoveScreenSize(value as Float) as Void {
        mapMoveScreenSize = value;
        setValue("mapMoveScreenSize", mapMoveScreenSize);
    }

    (:settingsView)
    function setCenterUserOffsetY(value as Float) as Void {
        centerUserOffsetY = value;
        setValue("centerUserOffsetY", centerUserOffsetY);
    }

    (:settingsView)
    function setRecalculateIntervalS(value as Number) as Void {
        recalculateIntervalS = value;
        recalculateIntervalS = recalculateIntervalS <= 0 ? 1 : recalculateIntervalS;
        setValue("recalculateIntervalS", recalculateIntervalS);
    }

    function setMapEnabled(_mapEnabled as Boolean) as Void {
        setMapEnabledRaw(_mapEnabled);
        setValue("mapEnabled", mapEnabled);
    }

    function setMapEnabledRaw(_mapEnabled as Boolean) as Void {
        mapEnabled = _mapEnabled;
        mapEnabledChanged();
    }

    function mapEnabledChanged() as Void {
        if (!mapEnabled) {
            getApp()._breadcrumbContext.tileCache.clearValuesWithoutStorage(); // do not remove our cached tiles, we might just be temporarily disabling maps
            clearPendingWebRequests();
            clearTileCacheStats();
            clearWebStats();
            return;
        }

        // prompts user to open the app
        if (tileUrl.equals(COMPANION_APP_TILE_URL) && !storageMapTilesOnly) {
            // we could also send a toast, but the transmit allows us to open the app easier on the phone
            // even though the phone side is a bit of a hack (ConnectIQMessageReceiver cannot parse the data), it's still better than having to manualy open the app.
            transmit([PROTOCOL_SEND_OPEN_APP], {}, getApp()._commStatus);
        }
    }

    (:settingsView)
    function setCacheTilesInStorage(value as Boolean) as Void {
        cacheTilesInStorage = value;
        setValue("cacheTilesInStorage", cacheTilesInStorage);

        if (!cacheTilesInStorage) {
            tileServerPropChanged();
        }
    }

    (:settingsView)
    function setStorageMapTilesOnly(value as Boolean) as Void {
        storageMapTilesOnly = value;
        setValue("storageMapTilesOnly", storageMapTilesOnly);
    }

    (:settingsView)
    function setDrawLineToClosestPoint(value as Boolean) as Void {
        drawLineToClosestPoint = value;
        setValue("drawLineToClosestPoint", drawLineToClosestPoint);
        updateViewSettings();
    }

    (:settingsView)
    function setShowPoints(value as Boolean) as Void {
        showPoints = value;
        setValue("showPoints", showPoints);
    }
    (:settingsView)
    function setDrawLineToClosestTrack(value as Boolean) as Void {
        drawLineToClosestTrack = value;
        setValue("drawLineToClosestTrack", drawLineToClosestTrack);
    }
    (:settingsView)
    function setShowTileBorders(value as Boolean) as Void {
        showTileBorders = value;
        setValue("showTileBorders", showTileBorders);
    }
    (:settingsView)
    function setShowErrorTileMessages(value as Boolean) as Void {
        showErrorTileMessages = value;
        setValue("showErrorTileMessages", showErrorTileMessages);
        getApp()._breadcrumbContext.tileCache.clearValuesWithoutStorage(); // remove the errored tiles from cache and redraw
    }
    (:settingsView)
    function setIncludeDebugPageInOnScreenUi(value as Boolean) as Void {
        includeDebugPageInOnScreenUi = value;
        setValue("includeDebugPageInOnScreenUi", includeDebugPageInOnScreenUi);
    }

    (:settingsView)
    function setDrawHitBoxes(value as Boolean) as Void {
        drawHitBoxes = value;
        setValue("drawHitBoxes", drawHitBoxes);
    }

    (:settingsView)
    function setShowDirectionPoints(value as Boolean) as Void {
        showDirectionPoints = value;
        setValue("showDirectionPoints", showDirectionPoints);
    }

    (:settingsView)
    function setDisplayLatLong(value as Boolean) as Void {
        displayLatLong = value;
        setValue("displayLatLong", displayLatLong);
    }

    function scaleRestrictedToTileLayers() as Boolean {
        return _scaleRestrictedToTileLayers || useDrawBitmap;
    }

    (:settingsView)
    function setDisplayRouteNames(_displayRouteNames as Boolean) as Void {
        displayRouteNames = _displayRouteNames;
        setValue("displayRouteNames", displayRouteNames);
    }

    function setRoutesEnabled(_routesEnabled as Boolean) as Void {
        routesEnabled = _routesEnabled;
        setValue("routesEnabled", routesEnabled);
    }

    function routeColour(routeId as Number) as Number {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return defaultRouteColour;
        }

        return routes[routeIndex]["colour"] as Number;
    }

    // see oddity with route name and route loading new in context.newRoute
    function routeName(routeId as Number) as String {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return "";
        }

        return routes[routeIndex]["name"] as String;
    }

    (:storage)
    function atLeast1RouteEnabled() as Boolean {
        if (!routesEnabled) {
            return false;
        }

        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (route["enabled"]) {
                return true;
            }
        }

        return false;
    }

    function routeEnabled(routeId as Number) as Boolean {
        if (!routesEnabled) {
            return false;
        }

        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return false;
        }
        return routes[routeIndex]["enabled"] as Boolean;
    }

    function routeReversed(routeId as Number) as Boolean {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return false;
        }
        return routes[routeIndex]["reversed"] as Boolean;
    }

    function routeStyle(routeId as Number) as Number {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return TRACK_STYLE_LINE;
        }
        return routes[routeIndex]["style"] as Number;
    }

    function routeTexture(routeId as Number) as Graphics.BitmapTexture or Number {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return -1;
        }
        padRouteTextures(routeIndex);
        return routeTextures[routeIndex];
    }

    function routeWidth(routeId as Number) as Number {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return 4;
        }
        return routes[routeIndex]["width"] as Number;
    }

    function setRouteColour(routeId as Number, value as Number) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }

        routes[routeIndex]["colour"] = value;
        saveRoutes();
        recomputeRouteTexture(routeIndex, routeStyle(routeId), routeWidth(routeId), value);
    }

    // see oddity with route name and route loading new in context.newRoute
    function setRouteName(routeId as Number, value as String) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }

        routes[routeIndex]["name"] = value;
        saveRoutes();
    }

    function setRouteStyle(routeId as Number, value as Number) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }

        routes[routeIndex]["style"] = value;
        saveRoutes();
        recomputeRouteTexture(routeIndex, value, routeWidth(routeId), routeColour(routeId));
    }

    function setRouteWidth(routeId as Number, value as Number) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }

        routes[routeIndex]["width"] = value;
        saveRoutes();
        recomputeRouteTexture(routeIndex, routeStyle(routeId), value, routeColour(routeId));
    }

    function setRouteEnabled(routeId as Number, value as Boolean) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }

        routes[routeIndex]["enabled"] = value;
        saveRoutes();
        updateViewSettings(); // routes enabled/disabled can effect off track alerts and other view renderring
    }

    function setRouteReversed(routeId as Number, value as Boolean) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }

        var oldVal = routes[routeIndex]["reversed"];
        if (oldVal != value) {
            getApp()._breadcrumbContext.reverseRouteId(routeId);
        }
        routes[routeIndex]["reversed"] = value;
        saveRoutes();
        updateViewSettings();
    }

    function ensureRouteId(routeId as Number) as Void {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex != null) {
            return;
        }

        if (routes.size() >= _routeMax) {
            return;
        }

        routes.add({
            "routeId" => routeId,
            "name" => routeName(routeId),
            "enabled" => true,
            "colour" => routeColour(routeId),
            "reversed" => routeReversed(routeId),
            "style" => routeStyle(routeId),
            "width" => routeWidth(routeId),
        });
        saveRoutes();
    }

    function getRouteIndexById(routeId as Number) as Number? {
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (route["routeId"] == routeId) {
                return i;
            }
        }

        return null;
    }

    function clearRoutes() as Void {
        routes = [];
        saveRoutes();
    }

    function storageCleared() as Void {
        // routes are already cleared seperately through context
        safeSetStorage("lastMapChoice", mapChoice); // make sure we do not reload our map choice
    }

    function clearRoute(routeId as Number) as Void {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null) {
            return;
        }
        routes.remove(routes[routeIndex]);
        saveRoutes();
    }

    function routesToSave() as Array<Dictionary<String, PropertyValueType> > {
        var toSave = [] as Array<Dictionary<String, PropertyValueType> >;
        for (var i = 0; i < routes.size(); ++i) {
            var entry = routes[i];
            var toAdd =
                ({
                    "routeId" => entry["routeId"] as Number,
                    "name" => entry["name"] as String,
                    "enabled" => entry["enabled"] as Boolean,
                    "colour" => (entry["colour"] as Number).format("%X"), // this is why we have to copy it :(
                    "reversed" => entry["reversed"] as Boolean,
                    "style" => entry["style"] as Number,
                    "width" => entry["width"] as Number,
                }) as Dictionary<String, PropertyValueType>;
            toSave.add(toAdd);
        }
        return toSave;
    }

    function saveRoutes() as Void {
        saveRoutesNoSideEffect();
        setValueSideEffect();
    }

    function saveRoutesNoSideEffect() as Void {
        var toSave = routesToSave();
        // note toSave is Array<Dictionary<String, PropertyValueType>>
        // but the compiler only allows "Array<PropertyValueType>" even though the array of dicts seems to work on sim and real watch
        safeSetStorage("routes", toSave as Array<PropertyValueType>);
    }

    (:settingsView)
    function setTrackColour(value as Number) as Void {
        trackColour = value;
        setValue("trackColour", trackColour.format("%X"));
        recomputeTrackTexture();
    }

    function recomputeTrackTexture() as Void {
        trackTexture = getTexture(trackStyle, trackWidth, trackWidth / 2, trackColour);
    }

    function recomputeRouteTexture(
        routeIndex as Number,
        currentStyle as Number,
        currentWidth as Number,
        currentColour as Number
    ) as Void {
        padRouteTextures(routeIndex);
        routeTextures[routeIndex] = getTexture(
            currentStyle,
            currentWidth,
            currentWidth / 2,
            currentColour
        );
    }

    function padRouteTextures(routeIndex as Number) as Void {
        if (routeTextures.size() <= routeIndex) {
            // Calculate how many new slots we need
            var elementsToAdd = routeIndex + 1 - routeTextures.size();

            // Create the "padding" array filled with -1
            var padding = new [elementsToAdd] as Array<Graphics.BitmapTexture or Number>;
            for (var i = 0; i < elementsToAdd; i++) {
                padding[i] = -1;
            }

            routeTextures.addAll(padding);
        }
    }

    (:settingsView)
    function setDefaultRouteColour(value as Number) as Void {
        defaultRouteColour = value;
        setValue("defaultRouteColour", defaultRouteColour.format("%X"));
    }

    (:settingsView)
    function setTileErrorColour(value as Number) as Void {
        tileErrorColour = value;
        setValue("tileErrorColour", tileErrorColour.format("%X"));
        getApp()._breadcrumbContext.tileCache.clearValuesWithoutStorage(); // remove the errored tiles from cache and redraw
    }

    (:settingsView)
    function setUserColour(value as Number) as Void {
        userColour = value;
        setValue("userColour", userColour.format("%X"));
    }

    (:settingsView)
    function setNormalModeColour(value as Number) as Void {
        normalModeColour = value;
        setValue("normalModeColour", normalModeColour.format("%X"));
    }

    (:settingsView)
    function setDebugColour(value as Number) as Void {
        debugColour = value;
        setValue("debugColour", debugColour.format("%X"));
    }

    (:settingsView)
    function setUiColour(value as Number) as Void {
        uiColour = value;
        setValue("uiColour", uiColour.format("%X"));
    }

    (:settingsView)
    function setElevationColour(value as Number) as Void {
        elevationColour = value;
        setValue("elevationColour", elevationColour.format("%X"));
    }

    function toggleMapEnabled() as Void {
        if (mapEnabled) {
            setMapEnabled(false);
            return;
        }

        setMapEnabled(true);
    }

    function toggleUseDrawBitmap() as Void {
        if (useDrawBitmap) {
            setUseDrawBitmapWithoutSideEffect(false);
            tileServerPropChanged();
            setValueSideEffect();
            return;
        }

        setUseDrawBitmapWithoutSideEffect(true);
        tileServerPropChanged();
        setValueSideEffect();
    }

    (:settingsView)
    function toggleStorageSeedBoundingBox() as Void {
        storageSeedBoundingBox = !storageSeedBoundingBox;
        setValue("storageSeedBoundingBox", storageSeedBoundingBox);
    }
    (:settingsView)
    function toggleCacheTilesInStorage() as Void {
        cacheTilesInStorage = !cacheTilesInStorage;
        setValue("cacheTilesInStorage", cacheTilesInStorage);
        tileServerPropChanged();
    }
    (:settingsView)
    function toggleStorageMapTilesOnly() as Void {
        storageMapTilesOnly = !storageMapTilesOnly;
        setValue("storageMapTilesOnly", storageMapTilesOnly);
    }
    (:settingsView)
    function toggleDrawLineToClosestPoint() as Void {
        drawLineToClosestPoint = !drawLineToClosestPoint;
        setValue("drawLineToClosestPoint", drawLineToClosestPoint);
    }
    (:settingsView)
    function toggleShowPoints() as Void {
        showPoints = !showPoints;
        setValue("showPoints", showPoints);
    }
    (:settingsView)
    function toggleDrawLineToClosestTrack() as Void {
        drawLineToClosestTrack = !drawLineToClosestTrack;
        setValue("drawLineToClosestTrack", drawLineToClosestTrack);
    }
    (:settingsView)
    function toggleShowTileBorders() as Void {
        showTileBorders = !showTileBorders;
        setValue("showTileBorders", showTileBorders);
    }
    (:settingsView)
    function toggleShowErrorTileMessages() as Void {
        showErrorTileMessages = !showErrorTileMessages;
        setValue("showErrorTileMessages", showErrorTileMessages);
        getApp()._breadcrumbContext.tileCache.clearValuesWithoutStorage(); // remove the errored tiles from cache and redraw
    }
    (:settingsView)
    function toggleIncludeDebugPageInOnScreenUi() as Void {
        includeDebugPageInOnScreenUi = !includeDebugPageInOnScreenUi;
        setValue("includeDebugPageInOnScreenUi", includeDebugPageInOnScreenUi);
    }
    (:settingsView)
    function toggleDrawHitBoxes() as Void {
        drawHitBoxes = !drawHitBoxes;
        setValue("drawHitBoxes", drawHitBoxes);
    }
    (:settingsView)
    function toggleShowDirectionPoints() as Void {
        showDirectionPoints = !showDirectionPoints;
        setValue("showDirectionPoints", showDirectionPoints);
    }
    (:settingsView)
    function toggleDisplayLatLong() as Void {
        displayLatLong = !displayLatLong;
        setValue("displayLatLong", displayLatLong);
    }
    (:settingsView)
    function toggleScaleRestrictedToTileLayers() as Void {
        _scaleRestrictedToTileLayers = !_scaleRestrictedToTileLayers;
        setValue("scaleRestrictedToTileLayers", _scaleRestrictedToTileLayers);
    }
    (:settingsView)
    function toggleDisplayRouteNames() as Void {
        displayRouteNames = !displayRouteNames;
        setValue("displayRouteNames", displayRouteNames);
    }
    (:settingsView)
    function toggleEnableOffTrackAlerts() as Void {
        enableOffTrackAlerts = !enableOffTrackAlerts;
        setValue("enableOffTrackAlerts", enableOffTrackAlerts);
    }
    (:settingsView)
    function toggleOffTrackWrongDirection() as Void {
        offTrackWrongDirection = !offTrackWrongDirection;
        setValue("offTrackWrongDirection", offTrackWrongDirection);
    }
    (:settingsView)
    function toggleDrawCheverons() as Void {
        drawCheverons = !drawCheverons;
        setValue("drawCheverons", drawCheverons);
    }
    (:settingsView)
    function toggleRoutesEnabled() as Void {
        routesEnabled = !routesEnabled;
        setValue("routesEnabled", routesEnabled);
    }

    function nextMode() as Void {
        // logT("mode cycled");
        // could just add one and check if over MODE_MAX?
        mode++;
        if (mode >= MODE_MAX) {
            mode = MODE_NORMAL;
        }

        if (mode == MODE_DEBUG && !includeDebugPageInOnScreenUi) {
            nextMode();
        }

        setMode(mode);
    }

    function nextZoomAtPaceMode() as Void {
        if (mode != MODE_NORMAL) {
            return;
        }

        // could also do this? not sure what better for perf (probably the modulo 1 less instruction), below is more readable
        // zoomAtPaceMode = (zoomAtPaceMode + 1) % ZOOM_AT_PACE_MODE_MAX;
        zoomAtPaceMode++;
        if (zoomAtPaceMode >= ZOOM_AT_PACE_MODE_MAX) {
            zoomAtPaceMode = ZOOM_AT_PACE_MODE_PACE;
        }

        setZoomAtPaceMode(zoomAtPaceMode);
    }

    function clearTileCache() as Void {
        getApp()._breadcrumbContext.tileCache.clearValues();
    }

    function clearStorageTiles() as Void {
        getApp()._breadcrumbContext.tileCache._storageTileCache.clearValues();
    }

    function transmit(
        content as Application.PersistableType,
        options as Dictionary?,
        listener as Communications.ConnectionListener
    ) as Void {
        getApp()._breadcrumbContext.webRequestHandler.transmit(content, options, listener);
    }

    function clearTileCacheStats() as Void {
        getApp()._breadcrumbContext.tileCache.clearStats();
    }

    function clearPendingWebRequests() as Void {
        getApp()._breadcrumbContext.webRequestHandler.clearValues();
    }

    function updateViewSettings() as Void {
        getApp()._view.onSettingsChanged();
    }

    function updateRouteSettings() as Void {
        var contextRoutes = getApp()._breadcrumbContext.routes;
        for (var i = 0; i < contextRoutes.size(); ++i) {
            var route = contextRoutes[i];
            // we do not care if its curently disabled, nuke the data anyway
            // if (!routeEnabled(route.storageIndex)) {
            //     continue;
            // }
            // todo only call this if setting sthat effect it changed, taking nuclear approach for now
            route.settingsChanged();
        }
    }

    function updateCachedValues() as Void {
        getApp()._breadcrumbContext.cachedValues.recalculateAll();
    }

    function clearWebStats() as Void {
        getApp()._breadcrumbContext.webRequestHandler.clearStats();
    }

    function clearContextRoutes() as Void {
        getApp()._breadcrumbContext.clearRoutes();
    }

    function clearRouteFromContext(routeId as Number) as Void {
        getApp()._breadcrumbContext.clearRouteId(routeId);
    }

    function purgeRoutesFromContext() as Void {
        getApp()._breadcrumbContext.purgeRoutes();
    }

    // some times these parserswere throwing when it was an empty strings seem to result in, or wrong type
    //
    // Error: Unhandled Exception
    // Exception: UnexpectedTypeException: Expected Number/Float/Long/Double/Char, given null/Number
    function parseColour(key as String, defaultValue as Number) as Number {
        try {
            return parseColourRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            logE("Error parsing float: " + key);
        }
        return defaultValue;
    }

    static function parseColourRaw(
        key as String,
        colourString as PropertyValueType,
        defaultValue as Number
    ) as Number {
        try {
            if (colourString == null) {
                return defaultValue;
            }

            if (colourString instanceof String) {
                // want final string as AARRGGBB
                // colourString = padStart(colourString, 6, '0'); // fill in 24 bit colour with 0's
                // colourString = padStart(colourString, 8, 'F'); // pad alpha channel with FF
                // empty or invalid strings convert to null
                // anything with leading FF (when 8 characters supplied) needs to be a long, because its too big to fit in Number
                // if a user chooses FFFFFFFF (white) it is (-1) which is fully transparent, should choose FFFFFF (no alpha) or something close like FFFFFFFE
                // in any case we are currently ignoring alpha because we use setColor (text does not support alpha)
                var long = colourString.toLongWithBase(16);
                if (long == null) {
                    return defaultValue;
                }

                // calling tonumber breaks - because its out of range, but we need to set the alpha bits
                var number = (long & 0xffffffffl).toNumber();
                if (number == 0xffffffff) {
                    // -1 is transparent and will not render
                    number = 0xfeffffff;
                }
                return number;
            }

            return parseNumberRaw(key, colourString, defaultValue);
        } catch (e) {
            logE("Error parsing colour: " + key + " " + colourString);
        }
        return defaultValue;
    }

    function parseNumber(key as String, defaultValue as Number) as Number {
        try {
            return parseNumberRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            logE("Error parsing float: " + key);
        }
        return defaultValue;
    }

    static function parseNumberRaw(
        key as String,
        value as PropertyValueType,
        defaultValue as Number
    ) as Number {
        try {
            if (value == null) {
                return defaultValue;
            }

            if (
                value instanceof String ||
                value instanceof Float ||
                value instanceof Number ||
                value instanceof Double
            ) {
                // empty or invalid strings convert to null
                var ret = value.toNumber();
                if (ret == null) {
                    return defaultValue;
                }

                return ret;
            }

            return defaultValue;
        } catch (e) {
            logE("Error parsing number: " + key + " " + value);
        }
        return defaultValue;
    }

    function parseBool(key as String, defaultValue as Boolean) as Boolean {
        try {
            return parseBoolRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            logE("Error parsing bool: " + key);
        }
        return defaultValue;
    }

    function parseBoolRaw(
        key as String,
        value as PropertyValueType,
        defaultValue as Boolean
    ) as Boolean {
        try {
            if (value == null) {
                return false;
            }

            if (value instanceof String) {
                return (
                    value.equals("") ||
                    value.equals("false") ||
                    value.equals("False") ||
                    value.equals("FALSE") ||
                    value.equals("0")
                );
            }

            if (!(value instanceof Boolean)) {
                return false;
            }

            return value;
        } catch (e) {
            logE("Error parsing bool: " + key + " " + value);
        }
        return defaultValue;
    }

    function parseFloat(key as String, defaultValue as Float) as Float {
        try {
            return parseFloatRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            logE("Error parsing float: " + key);
        }
        return defaultValue;
    }

    static function parseFloatRaw(
        key as String,
        value as PropertyValueType,
        defaultValue as Float
    ) as Float {
        try {
            if (value == null) {
                return defaultValue;
            }

            if (
                value instanceof String ||
                value instanceof Float ||
                value instanceof Number ||
                value instanceof Double
            ) {
                // empty or invalid strings convert to null
                var ret = value.toFloat();
                if (ret == null) {
                    return defaultValue;
                }

                return ret;
            }

            return defaultValue;
        } catch (e) {
            logE("Error parsing float: " + key + " " + value);
        }
        return defaultValue;
    }

    function parseString(key as String, defaultValue as String) as String {
        try {
            return parseStringRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            logE("Error parsing string: " + key);
        }
        return defaultValue;
    }

    function parseStringRaw(
        key as String,
        value as PropertyValueType,
        defaultValue as String
    ) as String {
        try {
            if (value == null) {
                return defaultValue;
            }

            if (value instanceof String) {
                return value;
            }

            return defaultValue;
        } catch (e) {
            logE("Error parsing string: " + key + " " + value);
        }
        return defaultValue;
    }

    function parseOptionalFloat(key as String, defaultValue as Float?) as Float? {
        try {
            return parseOptionalFloatRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            logE("Error parsing optional float: " + key);
        }
        return defaultValue;
    }

    function parseOptionalFloatRaw(
        key as String,
        value as PropertyValueType,
        defaultValue as Float?
    ) as Float? {
        try {
            if (value == null) {
                return null;
            }

            // as Float is a bit of a hack, it can be null, but we just want allow us to use our helper
            // (duck typing means at runtime the null passes through fine)
            return parseFloatRaw(key, value, defaultValue as Float);
        } catch (e) {
            logE("Error parsing optional float: " + key);
        }
        return defaultValue;
    }

    function getArraySchema(
        key as String,
        expectedKeys as Array<String>,
        parsers as Array<Method>,
        defaultValue as Array<Dictionary>
    ) as Array<Dictionary> {
        var value = null;
        try {
            value = Application.Storage.getValue(key);
            if (value == null) {
                return defaultValue;
            }

            if (!(value instanceof Array)) {
                return defaultValue;
            }

            // The dict we get is memory mapped, do not use it directly - need to create a copy so we can change the colour type from string to int
            // If we use it directly the storage value gets overwritten
            var result = [] as Array<Dictionary>;
            for (var i = 0; i < value.size(); ++i) {
                var entry = value[i];
                var entryOut = {};
                if (!(entry instanceof Dictionary)) {
                    return defaultValue;
                }

                for (var j = 0; j < expectedKeys.size(); ++j) {
                    var thisKey = expectedKeys[j];
                    var thisParser = parsers[j];
                    if (!entry.hasKey(thisKey)) {
                        return defaultValue;
                    }

                    entryOut[thisKey] = thisParser.invoke(
                        key + "." + i + "." + thisKey,
                        entry[thisKey]
                    );
                }
                result.add(entryOut);
            }

            return result;
        } catch (e) {
            logE("Error parsing array: " + key + " " + value);
        }
        return defaultValue;
    }

    function resetDefaults() as Void {
        logT("Resetting settings to default values");
        // clear the flag first thing in case of crash we do not want to try clearing over and over
        setValue("resetDefaults", false);

        // note: this pulls the defaults from whatever we have at the top of the file these may differ from the defaults in properties.xml
        var defaultSettings = new Settings();
        tileSize = defaultSettings.tileSize;
        httpErrorTileTTLS = defaultSettings.httpErrorTileTTLS;
        turnAlertTimeS = defaultSettings.turnAlertTimeS;
        minTurnAlertDistanceM = defaultSettings.minTurnAlertDistanceM;
        maxTrackPoints = defaultSettings.maxTrackPoints;
        trackStyle = defaultSettings.trackStyle;
        trackWidth = defaultSettings.trackWidth;
        showDirectionPointTextUnderIndex = defaultSettings.showDirectionPointTextUnderIndex;
        errorTileTTLS = defaultSettings.errorTileTTLS;
        fullTileSize = defaultSettings.fullTileSize;
        scaledTileSize = defaultSettings.scaledTileSize;
        packingFormat = defaultSettings.packingFormat;
        useDrawBitmap = defaultSettings.useDrawBitmap;
        tileLayerMax = defaultSettings.tileLayerMax;
        tileLayerMin = defaultSettings.tileLayerMin;
        tileCacheSize = defaultSettings.tileCacheSize;
        storageTileCacheSize = defaultSettings.storageTileCacheSize;
        storageTileCachePageCount = defaultSettings.storageTileCachePageCount;
        storageSeedBoundingBox = defaultSettings.storageSeedBoundingBox;
        storageSeedRouteDistanceM = defaultSettings.storageSeedRouteDistanceM;
        centerUserOffsetY = defaultSettings.centerUserOffsetY;
        mapMoveScreenSize = defaultSettings.mapMoveScreenSize;
        tileCachePadding = defaultSettings.tileCachePadding;
        recalculateIntervalS = defaultSettings.recalculateIntervalS;
        mode = defaultSettings.mode;
        mapEnabled = defaultSettings.mapEnabled;
        cacheTilesInStorage = defaultSettings.cacheTilesInStorage;
        storageMapTilesOnly = defaultSettings.storageMapTilesOnly;
        drawLineToClosestPoint = defaultSettings.drawLineToClosestPoint;
        showPoints = defaultSettings.showPoints;
        drawLineToClosestTrack = defaultSettings.drawLineToClosestTrack;
        showTileBorders = defaultSettings.showTileBorders;
        showErrorTileMessages = defaultSettings.showErrorTileMessages;
        includeDebugPageInOnScreenUi = defaultSettings.includeDebugPageInOnScreenUi;
        drawHitBoxes = defaultSettings.drawHitBoxes;
        showDirectionPoints = defaultSettings.showDirectionPoints;
        displayLatLong = defaultSettings.displayLatLong;
        _scaleRestrictedToTileLayers = defaultSettings.scaleRestrictedToTileLayers();
        trackColour = defaultSettings.trackColour;
        defaultRouteColour = defaultSettings.defaultRouteColour;
        tileErrorColour = defaultSettings.tileErrorColour;
        elevationColour = defaultSettings.elevationColour;
        userColour = defaultSettings.userColour;
        maxPendingWebRequests = defaultSettings.maxPendingWebRequests;
        metersAroundUser = defaultSettings.metersAroundUser;
        zoomAtPaceMode = defaultSettings.zoomAtPaceMode;
        zoomAtPaceSpeedMPS = defaultSettings.zoomAtPaceSpeedMPS;
        useTrackAsHeadingSpeedMPS = defaultSettings.useTrackAsHeadingSpeedMPS;
        topDataType = defaultSettings.topDataType;
        bottomDataType = defaultSettings.bottomDataType;
        minTrackPointDistanceM = defaultSettings.minTrackPointDistanceM;
        trackPointReductionMethod = defaultSettings.trackPointReductionMethod;
        dataFieldTextSize = defaultSettings.dataFieldTextSize;
        uiMode = defaultSettings.uiMode;
        elevationMode = defaultSettings.elevationMode;
        alertType = defaultSettings.alertType;
        renderMode = defaultSettings.renderMode;
        fixedLatitude = defaultSettings.fixedLatitude;
        fixedLongitude = defaultSettings.fixedLongitude;
        tileUrl = defaultSettings.tileUrl;
        authToken = defaultSettings.authToken;
        mapChoice = defaultSettings.mapChoice;
        routes = defaultSettings.routes;
        routesEnabled = defaultSettings.routesEnabled;
        displayRouteNames = defaultSettings.displayRouteNames;
        disableMapsFailureCount = defaultSettings.disableMapsFailureCount;
        enableOffTrackAlerts = defaultSettings.enableOffTrackAlerts;
        offTrackWrongDirection = defaultSettings.offTrackWrongDirection;
        drawCheverons = defaultSettings.drawCheverons;
        offTrackAlertsDistanceM = defaultSettings.offTrackAlertsDistanceM;
        offTrackAlertsMaxReportIntervalS = defaultSettings.offTrackAlertsMaxReportIntervalS;
        offTrackCheckIntervalS = defaultSettings.offTrackCheckIntervalS;
        _routeMax = defaultSettings.routeMax();
        normalModeColour = defaultSettings.normalModeColour;
        uiColour = defaultSettings.uiColour;
        debugColour = defaultSettings.debugColour;

        // raw write the settings to disk
        var dict = asDict();
        saveSettings(dict);

        // purge storage, all routes and caches
        Application.Storage.clearValues();
        clearTileCache();
        clearPendingWebRequests();
        clearTileCacheStats();
        clearWebStats();
        purgeRoutesFromContext();
        updateCachedValues();
        updateViewSettings();
    }

    function asDict() as Dictionary<String, PropertyValueType> {
        // all these return values should be identical to the storage value
        // eg. nulls are exposed as 0
        // colours are strings

        return (
            ({
                "tileSize" => tileSize,
                "httpErrorTileTTLS" => httpErrorTileTTLS,
                "turnAlertTimeS" => turnAlertTimeS,
                "minTurnAlertDistanceM" => minTurnAlertDistanceM,
                "maxTrackPoints" => maxTrackPoints,
                "trackStyle" => trackStyle,
                "trackWidth" => trackWidth,
                "showDirectionPointTextUnderIndex" => showDirectionPointTextUnderIndex,
                "errorTileTTLS" => errorTileTTLS,
                "fullTileSize" => fullTileSize,
                "scaledTileSize" => scaledTileSize,
                "packingFormat" => packingFormat,
                "useDrawBitmap" => useDrawBitmap,
                "tileLayerMax" => tileLayerMax,
                "tileLayerMin" => tileLayerMin,
                "tileCacheSize" => tileCacheSize,
                "storageTileCacheSize" => storageTileCacheSize,
                "storageTileCachePageCount" => storageTileCachePageCount,
                "storageSeedBoundingBox" => storageSeedBoundingBox,
                "storageSeedRouteDistanceM" => storageSeedRouteDistanceM,
                "centerUserOffsetY" => centerUserOffsetY,
                "mapMoveScreenSize" => mapMoveScreenSize,
                "tileCachePadding" => tileCachePadding,
                "recalculateIntervalS" => recalculateIntervalS,
                "mode" => mode,
                "mapEnabled" => mapEnabled,
                "cacheTilesInStorage" => cacheTilesInStorage,
                "storageMapTilesOnly" => storageMapTilesOnly,
                "drawLineToClosestPoint" => drawLineToClosestPoint,
                "showPoints" => showPoints,
                "drawLineToClosestTrack" => drawLineToClosestTrack,
                "showTileBorders" => showTileBorders,
                "showErrorTileMessages" => showErrorTileMessages,
                "includeDebugPageInOnScreenUi" => includeDebugPageInOnScreenUi,
                "drawHitBoxes" => drawHitBoxes,
                "showDirectionPoints" => showDirectionPoints,
                "displayLatLong" => displayLatLong,
                "scaleRestrictedToTileLayers" => scaleRestrictedToTileLayers(),
                "trackColour" => trackColour.format("%X"),
                "defaultRouteColour" => defaultRouteColour.format("%X"),
                "tileErrorColour" => tileErrorColour.format("%X"),
                "elevationColour" => elevationColour.format("%X"),
                "userColour" => userColour.format("%X"),
                "maxPendingWebRequests" => maxPendingWebRequests,
                "metersAroundUser" => metersAroundUser,
                "zoomAtPaceMode" => zoomAtPaceMode,
                "zoomAtPaceSpeedMPS" => zoomAtPaceSpeedMPS,
                "useTrackAsHeadingSpeedMPS" => useTrackAsHeadingSpeedMPS,
                "topDataType" => topDataType,
                "bottomDataType" => bottomDataType,
                "minTrackPointDistanceM" => minTrackPointDistanceM,
                "trackPointReductionMethod" => trackPointReductionMethod,
                "dataFieldTextSize" => dataFieldTextSize,
                "uiMode" => uiMode,
                "elevationMode" => elevationMode,
                "alertType" => alertType,
                "renderMode" => renderMode,
                "fixedLatitude" => fixedLatitude == null ? 0f : fixedLatitude,
                "fixedLongitude" => fixedLongitude == null ? 0f : fixedLongitude,
                "tileUrl" => tileUrl,
                "authToken" => authToken,
                "mapChoice" => mapChoice,
                "routes" => routesToSave(),
                "routesEnabled" => routesEnabled,
                "displayRouteNames" => displayRouteNames,
                "disableMapsFailureCount" => disableMapsFailureCount,
                "enableOffTrackAlerts" => enableOffTrackAlerts,
                "offTrackWrongDirection" => offTrackWrongDirection,
                "drawCheverons" => drawCheverons,
                "offTrackAlertsDistanceM" => offTrackAlertsDistanceM,
                "offTrackAlertsMaxReportIntervalS" => offTrackAlertsMaxReportIntervalS,
                "offTrackCheckIntervalS" => offTrackCheckIntervalS,
                "normalModeColour" => normalModeColour.format("%X"),
                "routeMax" => _routeMax,
                "uiColour" => uiColour.format("%X"),
                "debugColour" => debugColour.format("%X"),
                "resetDefaults" => false,
            }) as Dictionary<String, PropertyValueType>
        );
    }

    function saveSettings(settings as Dictionary<String, PropertyValueType>) as Void {
        // should we sanitize this as its untrusted? makes it significantly more annoying to do
        var keys = settings.keys();
        for (var i = 0; i < keys.size(); ++i) {
            var key = keys[i] as String;
            var value = settings[key];
            // for now just blindly trust the users
            // we do reload which sanitizes, but they could break garmins settings page with unexpected types
            try {
                if (key.equals("routes")) {
                    Application.Storage.setValue(
                        key,
                        value as Dictionary<PropertyKeyType, PropertyValueType>
                    );
                } else {
                    Application.Properties.setValue(key, value as PropertyValueType);
                }
            } catch (e) {
                logE("failed property save: " + e.getErrorMessage() + " " + key + ":" + value);
                ++$.globalExceptionCounter;
            }
        }
    }

    function setup() as Void {
        // assert the map choice when we load the settings, as it may have been changed when the app was not running and onSettingsChanged might not be called
        loadSettings();
        updateMapChoiceChange(mapChoice);
        setMinTrackPointDistanceMSideEffect();
        for (var i = 0; i < routes.size(); ++i) {
            var routeId = routes[i]["routeId"] as Number;
            recomputeRouteTexture(
                i,
                routeStyle(routeId),
                routeWidth(routeId),
                routeColour(routeId)
            );
        }
    }

    function loadSettingsPart1() as Void {
        httpErrorTileTTLS = parseNumber("httpErrorTileTTLS", httpErrorTileTTLS);
        turnAlertTimeS = parseNumber("turnAlertTimeS", turnAlertTimeS);
        minTurnAlertDistanceM = parseNumber("minTurnAlertDistanceM", minTurnAlertDistanceM);
        maxTrackPoints = parseNumber("maxTrackPoints", maxTrackPoints);
        trackStyle = parseNumber("trackStyle", trackStyle);
        trackWidth = parseNumber("trackWidth", trackWidth);
        showDirectionPointTextUnderIndex = parseNumber(
            "showDirectionPointTextUnderIndex",
            showDirectionPointTextUnderIndex
        );
        errorTileTTLS = parseNumber("errorTileTTLS", errorTileTTLS);
        fullTileSize = parseNumber("fullTileSize", fullTileSize);
        useDrawBitmap = parseBool("useDrawBitmap", useDrawBitmap);
        packingFormat = parseNumber("packingFormat", packingFormat);
        scaledTileSize = parseNumber("scaledTileSize", scaledTileSize);
        if (useDrawBitmap) {
            scaledTileSize = fullTileSize;
        }
        tileUrl = parseString("tileUrl", tileUrl);
        tileSize = parseNumber("tileSize", tileSize);
        if (!tileUrl.equals(COMPANION_APP_TILE_URL)) {
            tileSize = scaledTileSize;
        }
        tileLayerMax = parseNumber("tileLayerMax", tileLayerMax);
        tileLayerMin = parseNumber("tileLayerMin", tileLayerMin);
        // logT("tileSize: " + tileSize);
        if (tileSize < 2) {
            tileSize = 2;
        } else if (tileSize > 256) {
            tileSize = 256;
        }
        if (fullTileSize < 2) {
            fullTileSize = 2;
        } else if (fullTileSize > 256) {
            fullTileSize = 256;
        }
        if (scaledTileSize < 2) {
            scaledTileSize = 2;
        } else if (scaledTileSize > 256) {
            scaledTileSize = 256;
        }

        tileCacheSize = parseNumber("tileCacheSize", tileCacheSize);
        storageTileCacheSize = parseNumber("storageTileCacheSize", storageTileCacheSize);
        storageTileCachePageCount = parseNumber(
            "storageTileCachePageCount",
            storageTileCachePageCount
        );
        storageSeedBoundingBox = parseBool("storageSeedBoundingBox", storageSeedBoundingBox);
        storageSeedRouteDistanceM = parseFloat(
            "storageSeedRouteDistanceM",
            storageSeedRouteDistanceM
        );
        centerUserOffsetY = parseFloat("centerUserOffsetY", centerUserOffsetY);
        mapMoveScreenSize = parseFloat("mapMoveScreenSize", mapMoveScreenSize);
        tileCachePadding = parseNumber("tileCachePadding", tileCachePadding);
        recalculateIntervalS = parseNumber("recalculateIntervalS", recalculateIntervalS);
        recalculateIntervalS = recalculateIntervalS <= 0 ? 1 : recalculateIntervalS;
        mode = parseNumber("mode", mode);
        mapEnabled = parseBool("mapEnabled", mapEnabled);
        setMapEnabledRaw(mapEnabled); // prompt for app to open if needed
        cacheTilesInStorage = parseBool("cacheTilesInStorage", cacheTilesInStorage);
        storageMapTilesOnly = parseBool("storageMapTilesOnly", storageMapTilesOnly);
        drawLineToClosestPoint = parseBool("drawLineToClosestPoint", drawLineToClosestPoint);
        showPoints = parseBool("showPoints", showPoints);
        drawLineToClosestTrack = parseBool("drawLineToClosestTrack", drawLineToClosestTrack);
        showTileBorders = parseBool("showTileBorders", showTileBorders);
        showErrorTileMessages = parseBool("showErrorTileMessages", showErrorTileMessages);
        includeDebugPageInOnScreenUi = parseBool(
            "includeDebugPageInOnScreenUi",
            includeDebugPageInOnScreenUi
        );
        drawHitBoxes = parseBool("drawHitBoxes", drawHitBoxes);
        showDirectionPoints = parseBool("showDirectionPoints", showDirectionPoints);
        displayLatLong = parseBool("displayLatLong", displayLatLong);
        _scaleRestrictedToTileLayers = parseBool(
            "scaleRestrictedToTileLayers",
            _scaleRestrictedToTileLayers
        );
        displayRouteNames = parseBool("displayRouteNames", displayRouteNames);
        enableOffTrackAlerts = parseBool("enableOffTrackAlerts", enableOffTrackAlerts);
        offTrackWrongDirection = parseBool("offTrackWrongDirection", offTrackWrongDirection);
        drawCheverons = parseBool("drawCheverons", drawCheverons);
        routesEnabled = parseBool("routesEnabled", routesEnabled);
        trackColour = parseColour("trackColour", trackColour);
        defaultRouteColour = parseColour("defaultRouteColour", defaultRouteColour);
        tileErrorColour = parseColour("tileErrorColour", tileErrorColour);
        elevationColour = parseColour("elevationColour", elevationColour);
        userColour = parseColour("userColour", userColour);
        normalModeColour = parseColour("normalModeColour", normalModeColour);
    }

    function loadSettingsPart2() as Void {
        _routeMax = parseColour("routeMax", _routeMax);
        uiColour = parseColour("uiColour", uiColour);
        debugColour = parseColour("debugColour", debugColour);
        maxPendingWebRequests = parseNumber("maxPendingWebRequests", maxPendingWebRequests);
        metersAroundUser = parseNumber("metersAroundUser", metersAroundUser);
        zoomAtPaceMode = parseNumber("zoomAtPaceMode", zoomAtPaceMode);
        zoomAtPaceSpeedMPS = parseFloat("zoomAtPaceSpeedMPS", zoomAtPaceSpeedMPS);
        useTrackAsHeadingSpeedMPS = parseFloat(
            "useTrackAsHeadingSpeedMPS",
            useTrackAsHeadingSpeedMPS
        );
        topDataType = parseNumber("topDataType", topDataType);
        bottomDataType = parseNumber("bottomDataType", bottomDataType);
        minTrackPointDistanceM = parseNumber("minTrackPointDistanceM", minTrackPointDistanceM);
        trackPointReductionMethod = parseNumber(
            "trackPointReductionMethod",
            trackPointReductionMethod
        );
        dataFieldTextSize = parseNumber("dataFieldTextSize", dataFieldTextSize);
        uiMode = parseNumber("uiMode", uiMode);
        elevationMode = parseNumber("elevationMode", elevationMode);
        alertType = parseNumber("alertType", alertType);
        renderMode = parseNumber("renderMode", renderMode);

        fixedLatitude = parseOptionalFloat("fixedLatitude", fixedLatitude);
        fixedLongitude = parseOptionalFloat("fixedLongitude", fixedLongitude);
        setFixedPositionWithoutUpdate(fixedLatitude, fixedLongitude, false);
        updateRequiresAuth();
        authToken = parseString("authToken", authToken);
        mapChoice = parseNumber("mapChoice", mapChoice);
        routes = getArraySchema(
            "routes",
            ["routeId", "name", "enabled", "colour", "reversed", "style", "width"],
            [
                method(:defaultNumberParser),
                method(:emptyString),
                method(:defaultFalse),
                method(:defaultColourParser),
                method(:defaultFalse),
                method(:defaultNumberParser),
                method(:defaultNumberParser4),
            ],
            routes
        );
        logT("parsed routes: " + routes);
        disableMapsFailureCount = parseNumber("disableMapsFailureCount", disableMapsFailureCount);
        offTrackAlertsDistanceM = parseNumber("offTrackAlertsDistanceM", offTrackAlertsDistanceM);
        offTrackAlertsMaxReportIntervalS = parseNumber(
            "offTrackAlertsMaxReportIntervalS",
            offTrackAlertsMaxReportIntervalS
        );
        offTrackCheckIntervalS = parseNumber("offTrackCheckIntervalS", offTrackCheckIntervalS);
    }

    // Load the values initially from storage
    function loadSettings() as Void {
        // fix for a garmin bug where bool settings are not changable if they default to true
        // https://forums.garmin.com/developer/connect-iq/i/bug-reports/bug-boolean-properties-with-default-value-true-can-t-be-changed-in-simulator
        var haveDoneFirstLoadSetup = Application.Properties.getValue("haveDoneFirstLoadSetup");
        if (haveDoneFirstLoadSetup instanceof Boolean && !haveDoneFirstLoadSetup) {
            setValue("haveDoneFirstLoadSetup", true);
            resetDefaults(); // pulls from our defaults
        }

        var resetDefaults = Application.Properties.getValue("resetDefaults") as Boolean;
        if (resetDefaults) {
            resetDefaults();
            return;
        }

        var returnToUser = Application.Properties.getValue("returnToUser") as Boolean;
        if (returnToUser) {
            Application.Properties.setValue("returnToUser", false);
            getApp()._breadcrumbContext.cachedValues.returnToUser();
        }

        logT("loadSettings: Loading all settings");
        loadSettingsPart1();
        loadSettingsPart2();

        // testing coordinates (piper-comanche-wreck)
        // setFixedPosition(-27.297773, 152.753883);
        // // cachedValues.setScale(0.39); // zoomed out a bit
        // cachedValues.setScale(1.96); // really close
    }

    function emptyString(key as String, value as PropertyValueType) as String {
        return parseStringRaw(key, value, "");
    }

    function defaultNumberParser(key as String, value as PropertyValueType) as Number {
        return parseNumberRaw(key, value, 0);
    }

    function defaultNumberParser4(key as String, value as PropertyValueType) as Number {
        return parseNumberRaw(key, value, 4);
    }

    function defaultFalse(key as String, value as PropertyValueType) as Boolean {
        if (value instanceof Boolean) {
            return value;
        }

        return false;
    }

    function defaultColourParser(key as String, value as PropertyValueType) as Number {
        return parseColourRaw(key, value, Graphics.COLOR_RED);
    }

    function onSettingsChanged() as Void {
        logT("onSettingsChanged: Setting Changed, loading");
        var oldRoutes = routes;
        var oldRouteMax = _routeMax;
        var oldMapChoice = mapChoice;
        var oldTileUrl = tileUrl;
        var oldTileSize = tileSize;
        var oldHttpErrorTileTTLS = httpErrorTileTTLS;
        var oldMaxTrackPoints = maxTrackPoints;
        var oldErrorTileTTLS = errorTileTTLS;
        var oldFullTileSize = fullTileSize;
        var oldScaledTileSize = scaledTileSize;
        var oldPackingFormat = packingFormat;
        var oldUseDrawBitmap = useDrawBitmap;
        var oldTileCacheSize = tileCacheSize;
        var oldStorageTileCacheSize = storageTileCacheSize;
        var oldStorageTileCachePageCount = storageTileCachePageCount;
        var oldMapEnabled = mapEnabled;
        var oldCacheTilesInStorage = cacheTilesInStorage;
        var oldAuthToken = authToken;
        var oldTileErrorColour = tileErrorColour;
        var oldShowErrorTileMessages = showErrorTileMessages;
        var oldMinTrackPointDistanceM = minTrackPointDistanceM;
        var oldTrackStyle = trackStyle;
        var oldTrackWidth = trackWidth;
        var oldTrackColour = trackColour;
        loadSettings();
        // route settins do not work because garmins setting spage cannot edit them
        // when any property is modified, so we have to explain to users not to touch the settings, but we cannot because it looks
        // like garmmins settings are not rendering desciptions anymore :(
        for (var i = 0; i < oldRoutes.size(); ++i) {
            var oldRouteEntry = oldRoutes[i];
            var oldRouteId = oldRouteEntry["routeId"] as Number;

            var routeIndex = getRouteIndexById(oldRouteId);
            if (routeIndex != null) {
                // we have the same route
                var currentRouteEntry = routes[routeIndex];
                if (oldRouteEntry["reversed"] != currentRouteEntry["reversed"]) {
                    getApp()._breadcrumbContext.reverseRouteId(oldRouteId);
                }

                var currentStyle = currentRouteEntry["style"] as Number;
                var currentWidth = currentRouteEntry["width"] as Number;
                var currentColour = currentRouteEntry["colour"] as Number;
                if (
                    oldRouteEntry["style"] != currentStyle ||
                    oldRouteEntry["width"] != currentWidth ||
                    oldRouteEntry["colour"] != currentColour
                ) {
                    recomputeRouteTexture(routeIndex, currentStyle, currentWidth, currentColour);
                }

                continue;
            }

            // clear the route
            clearRouteFromContext(oldRouteId);
        }

        if (oldRouteMax > _routeMax) {
            routeMaxReduced();
        }

        if (
            oldTileErrorColour != tileErrorColour ||
            oldShowErrorTileMessages != showErrorTileMessages
        ) {
            getApp()._breadcrumbContext.tileCache.clearValuesWithoutStorage(); // remove the errored tiles from cache and redraw
        }

        // run any tile cache clearing that we need to when map features change
        if (!oldTileUrl.equals(tileUrl)) {
            tileUrlChanged();
        }
        if (
            oldTileSize != tileSize ||
            oldHttpErrorTileTTLS != httpErrorTileTTLS ||
            oldErrorTileTTLS != errorTileTTLS ||
            oldFullTileSize != fullTileSize ||
            oldScaledTileSize != scaledTileSize ||
            oldUseDrawBitmap != useDrawBitmap ||
            oldPackingFormat != packingFormat ||
            oldCacheTilesInStorage != cacheTilesInStorage ||
            !oldAuthToken.equals(authToken)
        ) {
            tileServerPropChanged();
        }

        if (oldStorageTileCacheSize > storageTileCacheSize) {
            storageTileCacheSizeReduced();
        }

        if (oldStorageTileCachePageCount != storageTileCachePageCount) {
            storageTilePageCountChanged();
        }

        if (oldTileCacheSize > tileCacheSize) {
            tileCacheSizeReduced();
        }

        if (oldMaxTrackPoints != maxTrackPoints) {
            maxTrackPointsChanged();
        }

        if (oldMapEnabled != mapEnabled) {
            mapEnabledChanged();
        }

        if (oldMapChoice != mapChoice) {
            updateMapChoiceChange(mapChoice);
        }

        if (oldMinTrackPointDistanceM != minTrackPointDistanceM) {
            setMinTrackPointDistanceMSideEffect();
        }

        if (
            oldTrackStyle != trackStyle ||
            oldTrackWidth != trackWidth ||
            oldTrackColour != trackColour
        ) {
            recomputeTrackTexture();
        }

        setValueSideEffect();
    }
}

// As the number of settings and number of cached variables updated are increasing stack overflows are becoming more common
// I think the main issue is the setBlah methods are meant to be used for on app settings, so they all call into setValue()
// but we need to not do that when we are comming from the context of onSettingsChanged, since we manually call the updateCachedValues at the end of onSettingsChanged

// Error: Stack Overflow Error
// Details: 'Failed invoking <symbol>'
// Time: 2025-05-14T11:00:57Z
// Part-Number: 006-B3704-00
// Firmware-Version: '19.05'
// Language-Code: eng
// ConnectIQ-Version: 5.1.1
// Filename: BreadcrumbDataField
// Appname: BreadcrumbDataField
// Stack:
//   - pc: 0x10002541
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 875
//     Function: getRouteIndexById
//   - pc: 0x100024ef
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 813
//     Function: routeEnabled
//   - pc: 0x10008ec0
//     File: 'BreadcrumbDataField\source\CachedValues.mc'
//     Line: 114
//     Function: calcOuterBoundingBoxFromTrackAndRoutes
//   - pc: 0x1000833a
//     File: 'BreadcrumbDataField\source\CachedValues.mc'
//     Line: 170
//     Function: getNewScaleAndUpdateCenter
//   - pc: 0x100092f2
//     File: 'BreadcrumbDataField\source\CachedValues.mc'
//     Line: 128
//     Function: updateScaleCenterAndMap
//   - pc: 0x100093c8
//     File: 'BreadcrumbDataField\source\CachedValues.mc'
//     Line: 440
//     Function: recalculateAll
//   - pc: 0x100043d6
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 1169
//     Function: updateCachedValues
//   - pc: 0x10004359
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 417
//     Function: setValue
//   - pc: 0x10002a86
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 649
//     Function: setTileLayerMax
//   - pc: 0x10003948
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 541
//     Function: updateMapChoiceChange
//   - pc: 0x10003ff6
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 428
//     Function: setMapChoice
//   - pc: 0x10001e3e
//     File: 'BreadcrumbDataField\source\Settings.mc'
//     Line: 1817
//     Function: onSettingsChanged
//   - pc: 0x10006d39
//     File: 'BreadcrumbDataField\source\BreadcrumbDataFieldApp.mc'
//     Line: 253
//     Function: onPhone
