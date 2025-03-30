import Toybox.Application;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;

enum /*Mode*/ {
  MODE_NORMAL,
  MODE_ELEVATION,
  MODE_MAP_MOVE,
  MODE_DEBUG,
  MODE_MAX,
}

enum /*ZoomMode*/ {
  ZOOM_AT_PACE_MODE_PACE,
  ZOOM_AT_PACE_MODE_STOPPED,
  ZOOM_AT_PACE_MODE_MAX,
}

enum /*UiMode*/ {
  UI_MODE_SHOW_ALL, // show a heap of ui elements on screen always
  UI_MODE_HIDDEN, // ui still active, but is hidden
  UI_MODE_NONE, // no accessible ui (touch events disabled)
  UI_MODE_MAX
}

const COMPANION_APP_TILE_URL = "http://127.0.0.1:8080";

class Settings {
    // should be a multiple of 256 (since thats how tiles are stored, though the companion app will render them scaled for you)
    // we will support rounding up though. ie. if we use 50 the 256 tile will be sliced into 6 chunks on the phone, this allows us to support more pixel sizes. 
    // so math.ceil should be used what figuring out how many meters a tile is.
    // eg. maybe we cannot do 128 but we can do 120 (this would limit the number of tiles, but the resolution would be slightly off)
    var tileSize as Number = 64;
    // there is both a memory limit to the number of tiles we can store, as well as a storage limit
    // for now this is both, though we may be able to store more than we can in memory 
    // so we could use the storage as a tile cache, and revert to loading from there, as it would be much faster than 
    // fetching over bluetooth
    // not sure if we can even store bitmaps into storage, it says only BitmapResource
    // id have to serialise it to an array and back out (might not be too hard)
    // 64 is enough to render outside the screen a bit 64*64 tiles with 64 tiles gives us 512*512 worth of pixel data
    var tileCacheSize as Number = 64; // represented in number of tiles, parsed from a string eg. "64"=64tiles, "100KB"=100/2Kb per tile = 50 
    var mode as Number = MODE_NORMAL;
    // todo clear tile cache when this changes
    var mapEnabled as Boolean = true;
    var trackColour as Number = Graphics.COLOR_GREEN;
    var elevationColour as Number = Graphics.COLOR_ORANGE;
    var userColour as Number = Graphics.COLOR_ORANGE;
    // this should probably be the same as tileCacheSize? since there is no point hadving 20 outstanding if we can only store 10 of them
    var maxPendingWebRequests as Number = 100;
    var scale as Float or Null = null;
    // note: this renders around the users position, but may result in a
    // different zoom level `scale` is set
    var metersAroundUser as Number = 100;
    var zoomAtPaceMode as Number = ZOOM_AT_PACE_MODE_PACE;
    var zoomAtPaceSpeedMPS as Float = 1.0; // meters per second
    var uiMode as Number = UI_MODE_SHOW_ALL;
    var fixedLatitude as Float or Null = null;
    var fixedLongitude as Float or Null = null;
    // supports place holders such as 
    // use http://127.0.0.1:8080 for companion app
    // but you can also use something like https://a.tile.opentopomap.org/{z}/{x}/{y}.png
    // to make this work on the emulator you ned to run 
    // adb forward tcp:8080 tcp:8080
    var tileUrl as String = COMPANION_APP_TILE_URL;
    // see keys below in routes = getArraySchema(...)
    // see oddity with route name and route loading new in context.newRoute
    var routes as Array<Dictionary> = [];
    var routesEnabled as Boolean = true;
    var disableMapsFailureCount as Number = 200; // 0 for unlimited
    var enableRotation as Boolean = true;
    var displayRouteNames as Boolean = true;
    var normalModeColour as Number = Graphics.COLOR_BLUE;
    var uiColour as Number = Graphics.COLOR_DK_GRAY;
    var debugColour as Number = Graphics.COLOR_WHITE;

    // todo impl features for alerte
    // note this only works if a single track is enabled (multiple tracks would always error)
    var enableOffTrackAlerts as Boolean = true;
    var offTrackAlertsDistanceM as Number = 20;
    
    // calculated whenever others change
    var smallTilesPerBigTile = Math.ceil(256f/tileSize);
    var fixedPosition as RectangularPoint or Null = null;
    // will be changed whenever scale is adjusted, falls back to metersAroundUser when no scale
    var mapMoveDistanceM as Float = metersAroundUser * 1f;
    
    function setMode(_mode as Number) as Void {
        mode = _mode;
        Application.Properties.setValue("mode", mode);
    }
    
    function setUiMode(_uiMode as Number) as Void {
        uiMode = _uiMode;
        Application.Properties.setValue("uiMode", uiMode);
    }
    
    function setFixedPosition(lat as Float or Null, long as Float or Null) as Void {
        // System.println("moving to: " + lat + " " + long);
        // be very careful about putting null into properties, it breaks everything
        if (lat == null || !(lat instanceof Float))
        {
            lat = 0f;
        }
        if (long == null || !(long instanceof Float))
        {
            long = 0f;
        }
        fixedLatitude = lat;
        fixedLongitude = long;
        Application.Properties.setValue("fixedLatitude", lat);
        Application.Properties.setValue("fixedLongitude", long);

        var latIsBasicallyNull = fixedLatitude == null || fixedLatitude == 0;
        var longIsBasicallyNull = fixedLongitude == null || fixedLongitude == 0;
        if (latIsBasicallyNull && longIsBasicallyNull)
        {
            fixedLatitude = null;
            fixedLongitude = null;
            fixedPosition = null;
            clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
            return;
        }

        // ensure any remaing nulls are removed and gets us a fixedPosition
        setPositionIfNotSet();
        var latlong = RectangularPoint.xyToLatLon(fixedPosition.x, fixedPosition.y);
        // System.println("round trip conversion result: " + latlong);
        clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
    }
    
    function setZoomAtPaceMode(_zoomAtPaceMode as Number) as Void {
        zoomAtPaceMode = _zoomAtPaceMode;
        Application.Properties.setValue("zoomAtPaceMode", zoomAtPaceMode);
    }
    
    function setTileUrl(_tileUrl as String) as Void {
        tileUrl = _tileUrl;
        Application.Properties.setValue("tileUrl", tileUrl);
        clearPendingWebRequests();
        clearTileCache();
    }
    
    function setZoomAtPaceSpeedMPS(mps as Float) as Void {
        zoomAtPaceSpeedMPS = mps;
        Application.Properties.setValue("zoomAtPaceSpeedMPS", zoomAtPaceSpeedMPS);
    }
    
    function setMetersAroundUser(value as Number) as Void {
        metersAroundUser = value;
        Application.Properties.setValue("metersAroundUser", metersAroundUser);
    }

    function setFixedLatitude(value as Float) as Void {
        setFixedPosition(value, fixedLongitude);
    }
    
    function setFixedLongitude(value as Float) as Void {
        setFixedPosition(fixedLatitude, value);
    }

    function setMaxPendingWebRequests(value as Number) as Void {
        maxPendingWebRequests = value;
        Application.Properties.setValue("maxPendingWebRequests", maxPendingWebRequests);
    }
    
    function setTileSize(value as Number) as Void {
        tileSize = value;
        Application.Properties.setValue("tileSize", tileSize);
        clearPendingWebRequests();
        clearTileCache();
    }
    
    function setDisableMapsFailureCount(value as Number) as Void {
        disableMapsFailureCount = value;
        Application.Properties.setValue("disableMapsFailureCount", disableMapsFailureCount);
    }
    
    function setOffTrackAlertsDistanceM(value as Number) as Void {
        offTrackAlertsDistanceM = value;
        Application.Properties.setValue("offTrackAlertsDistanceM", offTrackAlertsDistanceM);
    }
    
    function setTileCacheSize(value as Number) as Void {
        tileCacheSize = value;
        Application.Properties.setValue("tileCacheSize", tileCacheSize);
    }
    
    function setMapEnabled(_mapEnabled as Boolean) as Void {
        mapEnabled = _mapEnabled;
        Application.Properties.setValue("mapEnabled", mapEnabled);

        if (!mapEnabled)
        {
           clearTileCache();
           clearPendingWebRequests();
           clearTileCacheStats();
           clearWebStats();
        }
    }
    
    function setDisplayRouteNames(_displayRouteNames as Boolean) as Void {
        displayRouteNames = _displayRouteNames;
        Application.Properties.setValue("displayRouteNames", displayRouteNames);
    }
    
    function setEnableOffTrackAlerts(_enableOffTrackAlerts as Boolean) as Void {
        enableOffTrackAlerts = _enableOffTrackAlerts;
        Application.Properties.setValue("enableOffTrackAlerts", enableOffTrackAlerts);
    }
    
    function setEnableRotation(_enableRotation as Boolean) as Void {
        enableRotation = _enableRotation;
        Application.Properties.setValue("enableRotation", enableRotation);
    }
    
    function setRoutesEnabled(_routesEnabled as Boolean) as Void {
        routesEnabled = _routesEnabled;
        Application.Properties.setValue("routesEnabled", routesEnabled);
    }

    function routeColour(routeId as Number) as Number
    {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null)
        {
            return Graphics.COLOR_BLUE;
        }

        return routes[routeIndex]["colour"];
    }

    // see oddity with route name and route loading new in context.newRoute
    function routeName(routeId as Number) as String
    {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null)
        {
            return "";
        }
        
        return routes[routeIndex]["name"];
    }

    function routeEnabled(routeId as Number) as Boolean
    {
        if (!routesEnabled)
        {
            return false;
        }

        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null)
        {
            return false;
        }
        return routes[routeIndex]["enabled"];
    }

    function setRouteColour(routeId as Number, value as Number) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null)
        {
            return;
        }

        routes[routeIndex]["colour"] = value;
        saveRoutes();
    }
    
    // see oddity with route name and route loading new in context.newRoute
    function setRouteName(routeId as Number, value as String) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null)
        {
            return;
        }

        routes[routeIndex]["name"] = value;
        saveRoutes();
    }

    function setRouteEnabled(routeId as Number, value as Boolean) as Void {
        ensureRouteId(routeId);
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex == null)
        {
            return;
        }
        
        routes[routeIndex]["enabled"] = value;
        saveRoutes();
    }

    function ensureRouteId(routeId as Number) as Void
    {
        var routeIndex = getRouteIndexById(routeId);
        if (routeIndex != null)
        {
            return;
        }

        if (routes.size() >= ROUTE_MAX)
        {
            return;
        }

        routes.add(
            {
                "id" => routeId,
                "name" => routeName(routeId),
                "enabled" => true,
                "colour" => routeColour(routeId)
            }
        );
        saveRoutes();
    }

    function getRouteIndexById(routeId as Number) as Number or Null
    {
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (route["id"] == routeId)
            {
                return i;
            }
        }

        return null;
    }

    function clearRoutes() as Void {
        routes = [];
        saveRoutes();
    }
    
    function saveRoutes()
    {
        var toSave = [];
        for (var i = 0; i < routes.size(); ++i) {
            var entry = routes[i];
            toSave.add(
                {
                    "id" => entry["id"],
                    "name" => entry["name"],
                    "enabled" => entry["enabled"],
                    "colour" => entry["colour"].format("%X") // this is why we have to copy it :(
                }
            );
        }
        Application.Properties.setValue("routes", toSave);
    }
    
    function setTrackColour(value as Number) as Void {
        trackColour = value;
        Application.Properties.setValue("trackColour", trackColour.format("%X"));
    }
    
    function setUserColour(value as Number) as Void {
        userColour = value;
        Application.Properties.setValue("userColour", userColour.format("%X"));
    }
    
    function setNormalModeColour(value as Number) as Void {
        normalModeColour = value;
        Application.Properties.setValue("normalModeColour", normalModeColour.format("%X"));
    }
    
    function setDebugColour(value as Number) as Void {
        debugColour = value;
        Application.Properties.setValue("debugColour", debugColour.format("%X"));
    }
    
    function setUiColour(value as Number) as Void {
        uiColour = value;
        Application.Properties.setValue("uiColour", uiColour.format("%X"));
    }
    
    function setElevationColour(value as Number) as Void {
        elevationColour = value;
        Application.Properties.setValue("elevationColour", elevationColour.format("%X"));
    }

    function toggleMapEnabled() as Void 
    {
        if (mapEnabled)
        {
            setMapEnabled(false);
            return;
        }

        setMapEnabled(true);
    }
    
    function toggleDisplayRouteNames() as Void 
    {
        if (displayRouteNames)
        {
            setDisplayRouteNames(false);
            return;
        }

        setDisplayRouteNames(true);
    }
    
    function toggleEnableOffTrackAlerts() as Void 
    {
        if (enableOffTrackAlerts)
        {
            setEnableOffTrackAlerts(false);
            return;
        }

        setEnableOffTrackAlerts(true);
    }
    
    function toggleEnableRotation() as Void 
    {
        if (enableRotation)
        {
            setEnableRotation(false);
            return;
        }

        setEnableRotation(true);
    }
    
    function toggleRoutesEnabled() as Void 
    {
        if (routesEnabled)
        {
            setRoutesEnabled(false);
            return;
        }

        setRoutesEnabled(true);
    }
    
    function setScale(_scale as Float or Null) as Void {
        scale = _scale;
        // be very careful about putting null into properties, it breaks everything
        if (scale == null)
        {
            Application.Properties.setValue("scale", 0);
            mapMoveDistanceM = metersAroundUser.toFloat();
            return;
        }

        mapMoveDistanceM = metersAroundUser.toFloat(); // todo: caculate this off scale
        Application.Properties.setValue("scale", scale);
    }

    // todo: make all of these take into acount the sceen rotation, and move in the direction the screen is pointing
    // for now just moving NSEW as if there was no screen rotation (N is up)
    function moveFixedPositionUp() as Void
    {
        setPositionIfNotSet();
        var latlong = RectangularPoint.xyToLatLon(fixedPosition.x, fixedPosition.y + mapMoveDistanceM);
        if (latlong != null)
        {
            setFixedPosition(latlong[0], latlong[1]);
        }
    }

    function moveFixedPositionDown() as Void
    {
        setPositionIfNotSet();
        var latlong = RectangularPoint.xyToLatLon(fixedPosition.x, fixedPosition.y - mapMoveDistanceM);
        if (latlong != null)
        {
            setFixedPosition(latlong[0], latlong[1]);
        }
    }

    function moveFixedPositionLeft() as Void
    {
        setPositionIfNotSet();
        var latlong = RectangularPoint.xyToLatLon(fixedPosition.x - mapMoveDistanceM, fixedPosition.y);
        if (latlong != null)
        {
            setFixedPosition(latlong[0], latlong[1]);
        }
    }

    function moveFixedPositionRight() as Void
    {
        setPositionIfNotSet();
        var latlong = RectangularPoint.xyToLatLon(fixedPosition.x + mapMoveDistanceM, fixedPosition.y);
        if (latlong != null)
        {
            setFixedPosition(latlong[0], latlong[1]);
        }
    }

    // note: this does not save the position just sets it
    function setPositionIfNotSet() as Void
    {
        var lastRenderedLatLongCenter = null;
        // context might not be set yet
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext && context has :_breadcrumbRenderer && context._breadcrumbRenderer != null && context._breadcrumbRenderer instanceof BreadcrumbRenderer)
        {
            if (context._breadcrumbRenderer.lastRenderedCenter != null)
            {
                lastRenderedLatLongCenter = RectangularPoint.xyToLatLon(
                    context._breadcrumbRenderer.lastRenderedCenter.x, 
                    context._breadcrumbRenderer.lastRenderedCenter.y
                );
            }
        }
        
        if (fixedLatitude == null)
        {
            fixedLatitude = lastRenderedLatLongCenter == null ? 0f : lastRenderedLatLongCenter[0];
        }

        if (fixedLongitude == null)
        {
            fixedLongitude = lastRenderedLatLongCenter == null ? 0f : lastRenderedLatLongCenter[1];;
        }
        fixedPosition = RectangularPoint.latLon2xy(fixedLatitude, fixedLongitude, 0f);
        // System.println("new fixed pos: " + fixedPosition);
    }

    function nextMode() as Void
    {
        // System.println("mode cycled");
        // could just add one and check if over MODE_MAX?
        mode++;
        if (mode >= MODE_MAX)
        {
            mode = MODE_NORMAL;
        }
        
        if (mode == MODE_MAP_MOVE && !mapEnabled)
        {
            nextMode();
        }

        setMode(mode);
    }

    function toggleZoomAtPace() as Void { 
        if (mode != MODE_NORMAL)
        {
            return;
        }

        zoomAtPaceMode++;
        if (zoomAtPaceMode >= ZOOM_AT_PACE_MODE_MAX)
        {
            zoomAtPaceMode = ZOOM_AT_PACE_MODE_PACE;
        }

        setZoomAtPaceMode(zoomAtPaceMode);
    }

    function parseTileCacheSizeString(key as String, _tileSize as Number) as Number {
        var sizeString = null;
        try {
            sizeString = Application.Properties.getValue(key);
            if (sizeString == null)
            {
                return _tileSize;
            }

            if (!(sizeString instanceof String))
            {
                return _tileSize;
            }

            var unit = sizeString.substring(sizeString.length() - 2, sizeString.length()); // Extract unit ("KB")
            if (unit.equals("KB")) {
                var value = sizeString.substring(0, sizeString.length() - 2).toNumber();
                // empty or invalid strings convert to null
                if (value == null)
                {
                    return _tileSize;
                }
                // todo figure out a sane value for _memoryKbPerPixel
                // probably better to just specify a number
                var memoryKbPerPixel = 1;
                return value / (memoryKbPerPixel * _tileSize * _tileSize);
            }

            return parseNumber(key, _tileSize);
        } 
        catch (e) {
            logE("Error parsing tile size: " + key + " " + sizeString);
        }

        return _tileSize;
    }

    function clearTileCache() as Void {
        // symbol not found if the loadSettings method is called before we set tile cache
        // should n ot happen unless onsettingschange is called before initalise finishes
        // it alwasys has the symbol, but it might not be initalised yet
        // _breadcrumbContext also may not be set yet, as we are loading the settings from within the contructor
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext && context has :_tileCache && context._tileCache != null && context._tileCache instanceof TileCache)
        {
            context._tileCache.clearValues();
        }
    }
    
    function clearTileCacheStats() as Void {
        // symbol not found if the loadSettings method is called before we set tile cache
        // should n ot happen unless onsettingschange is called before initalise finishes
        // it alwasys has the symbol, but it might not be initalised yet
        // _breadcrumbContext also may not be set yet, as we are loading the settings from within the contructor
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext && context has :_tileCache && context._tileCache != null && context._tileCache instanceof TileCache)
        {
            context._tileCache.clearStats();
        }
    }
    
    function clearPendingWebRequests() as Void {
        // symbol not found if the loadSettings method is called before we set tile cache
        // should n ot happen unless onsettingschange is called before initalise finishes
        // it alwasys has the symbol, but it might not be initalised yet
        // _breadcrumbContext also may not be set yet, as we are loading the settings from within the contructor
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext && context has :_webRequestHandler && context._webRequestHandler != null && context._webRequestHandler instanceof WebRequestHandler)
        {
            context._webRequestHandler.clearValues();
        }
    }
    
    function clearWebStats() as Void {
        // symbol not found if the loadSettings method is called before we set tile cache
        // should n ot happen unless onsettingschange is called before initalise finishes
        // it alwasys has the symbol, but it might not be initalised yet
        // _breadcrumbContext also may not be set yet, as we are loading the settings from within the contructor
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext && context has :_webRequestHandler && context._webRequestHandler != null && context._webRequestHandler instanceof WebRequestHandler)
        {
            context._webRequestHandler.clearStats();
        }
    }
    
    function clearContextRoutes() as Void {
        // symbol not found if the loadSettings method is called before we set tile cache
        // should n ot happen unless onsettingschange is called before initalise finishes
        // it alwasys has the symbol, but it might not be initalised yet
        // _breadcrumbContext also may not be set yet, as we are loading the settings from within the contructor
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext)
        {
            context.clearRoutes();
        }
    }
    
    function clearRouteFromContext(routeId as Number) as Void {
        // symbol not found if the loadSettings method is called before we set tile cache
        // should n ot happen unless onsettingschange is called before initalise finishes
        // it alwasys has the symbol, but it might not be initalised yet
        // _breadcrumbContext also may not be set yet, as we are loading the settings from within the contructor
        var context = getApp()._breadcrumbContext;
        if (context != null and context instanceof BreadcrumbContext)
        {
            context.clearRouteId(routeId);
        }
    }

    // some times these parserswere throwing when it was an empty strings seem to result in, or wrong type
    // 
    // Error: Unhandled Exception
    // Exception: UnexpectedTypeException: Expected Number/Float/Long/Double/Char, given null/Number

    function parseColour(key as String, defaultValue as Number) as Number {
        try {
            return parseColourRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            System.println("Error parsing float: " + key);
        }
        return defaultValue;
    }
    
    function parseColourRaw(key as String, colorString as String or Null, defaultValue as Number) as Number {
        try {
            if (colorString == null)
            {
                return defaultValue;
            }

            if (colorString instanceof String)
            {
                // empty or invalid strings convert to null
                var ret = colorString.toNumberWithBase(16);
                if (ret == null)
                {
                    return defaultValue;
                }

                return ret;
            }

            return parseNumberRaw(key, colorString, defaultValue);
                
        } catch (e) {
            System.println("Error parsing colour: " + key + " " + colorString);
        }
        return defaultValue;
    }

    function parseNumber(key as String, defaultValue as Number) as Number {
        try {
            return parseNumberRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            System.println("Error parsing float: " + key);
        }
        return defaultValue;
    }
    
    function parseNumberRaw(key as String, value as String or Null or Float or Number or Double, defaultValue as Number) as Number {
        try {
            if (value == null)
            {
                return defaultValue;
            }

            if (value instanceof String || value instanceof Float || value instanceof Number || value instanceof Double)
            {
                // empty or invalid strings convert to null
                var ret = value.toNumber();
                if (ret == null)
                {
                    return defaultValue;
                }

                return ret;
            }

            return defaultValue;
        } catch (e) {
            System.println("Error parsing number: " + key + " " + value);
        }
        return defaultValue;
    }
    
    function parseBool(key as String, defaultValue as Boolean) as Boolean {
        try {
            return parseBoolRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            System.println("Error parsing bool: " + key);
        }
        return defaultValue;
    }
    
    function parseBoolRaw(key as String, value as String or Boolean or Null, defaultValue as Boolean) as Boolean {
        try {
            if (value == null)
            {
                return false;
            }

            if (value instanceof String)
            {
                return value.equals("") || value.equals("false") || value.equals("False") || value.equals("FALSE") || value.equals("0");
            }

            if (!(value instanceof Boolean))
            {
                return false;
            }

            return value;
        } catch (e) {
            System.println("Error parsing bool: " + key + " " + value);
        }
        return defaultValue;
    }

    function parseFloat(key as String, defaultValue as Float) as Float {
        try {
            return parseFloatRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            System.println("Error parsing float: " + key);
        }
        return defaultValue;
    }
    
    function parseFloatRaw(key as String, value as String or Null or Float or Number or Double , defaultValue as Float) as Float {
        try {
            if (value == null)
            {
                return defaultValue;
            }

            if (value instanceof String || value instanceof Float || value instanceof Number || value instanceof Double)
            {
                // empty or invalid strings convert to null
                var ret = value.toFloat();
                if (ret == null)
                {
                    return defaultValue;
                }

                return ret;
            }

            return defaultValue;
        } catch (e) {
            System.println("Error parsing float: " + key + " " + value);
        }
        return defaultValue;
    }
    
    function parseString(key as String, defaultValue as String) as String {
        try {
            return parseStringRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            System.println("Error parsing string: " + key);
        }
        return defaultValue;
    }

    function parseStringRaw(key as String, value as String or Null, defaultValue as String) as String {
        try {
            if (value == null)
            {
                return defaultValue;
            }

            if (value instanceof String)
            {

                return value;
            }

            return defaultValue;
        } catch (e) {
            System.println("Error parsing string: " + key + " " + value);
        }
        return defaultValue;
    }

    function parseOptionalFloat(key as String, defaultValue as Float or Null) as Float or Null {
        try {
            return parseOptionalFloatRaw(key, Application.Properties.getValue(key), defaultValue);
        } catch (e) {
            System.println("Error parsing optional float: " + key);
        }
        return defaultValue;
    }

    function parseOptionalFloatRaw(key as String, value as String or Float or Null, defaultValue as Float or Null) as Float or Null {
        try {
            if (value == null)
            {
                return null;
            }

            return parseFloatRaw(key, value, defaultValue);
        } catch (e) {
            System.println("Error parsing optional float: " + key);
        }
        return defaultValue;
    }
    
    function getArraySchema(key as String, expectedKeys as Array<String>, parsers as Array<Method>, defaultValue as Array) as Array {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
            if (value == null)
            {
                return defaultValue;
            }

            if (!(value instanceof Array))
            {
                return defaultValue;
            }

            for (var i = 0; i < value.size(); ++i) {
                var entry = value[i];
                if (!(entry instanceof Dictionary))
                {
                    return defaultValue;
                }

                for (var j = 0; j < expectedKeys.size(); ++j) {
                    var thisKey = expectedKeys[j];
                    var thisParser = parsers[j];
                    if (!entry.hasKey(thisKey))
                    {
                        return defaultValue;
                    }

                    entry[thisKey] = thisParser.invoke(key + "." + i + "." + thisKey, entry[thisKey]);
                }
            }

            return value;
        } catch (e) {
            System.println("Error parsing array: " + key + " " + value);
        }
        return defaultValue;
    }

    function resetDefaults() as Void
    {
        System.println("Resetting settings to default values");
        // clear the flag first thing in case of crash we do not want to try clearing over and over
        Application.Properties.setValue("resetDefaults", false);

        var settings = new Settings();
        setTileSize(settings.tileSize);
        setTileCacheSize(settings.tileCacheSize);
        setMode(settings.mode);
        setMapEnabled(settings.mapEnabled);
        setTrackColour(settings.trackColour);
        setElevationColour(settings.elevationColour);
        setUserColour(settings.userColour);
        setMaxPendingWebRequests(settings.maxPendingWebRequests);
        setScale(0f);
        setMetersAroundUser(settings.metersAroundUser);
        setZoomAtPaceMode(settings.zoomAtPaceMode);
        setZoomAtPaceSpeedMPS(settings.zoomAtPaceSpeedMPS);
        setUiMode(settings.uiMode);
        setFixedLatitude(0f);
        setFixedLongitude(0f);
        setTileUrl(tileUrl);
        routes = settings.routes;
        saveRoutes();
        setRoutesEnabled(settings.routesEnabled);
        setDisplayRouteNames(settings.displayRouteNames);
        setDisableMapsFailureCount(settings.disableMapsFailureCount);
        setEnableRotation(settings.enableRotation);
        setEnableOffTrackAlerts(settings.enableOffTrackAlerts);
        setOffTrackAlertsDistanceM(settings.offTrackAlertsDistanceM);
        setNormalModeColour(settings.normalModeColour);
        setUiColour(settings.uiColour);
        setDebugColour(settings.debugColour);

        // purge storage too on reset
        Application.Storage.clearValues();
        clearTileCache();
        clearPendingWebRequests();
        clearTileCacheStats();
        clearWebStats();
        clearContextRoutes();
        // load all the settings we just wrote
        loadSettings();
    }

    // Load the values initially from storage
    function loadSettings() as Void {
        var resetDefaults = Application.Properties.getValue("resetDefaults") as Boolean;
        if (resetDefaults)
        {
            resetDefaults();
            return;
        }

        System.println("loadSettings: Loading all settings");
        tileSize = parseNumber("tileSize", tileSize);
        // System.println("tileSize: " + tileSize);
        if (tileSize < 2)
        {
            tileSize = 2;
        }
        else if (tileSize > 256)
        {
            tileSize = 256;
        }
        smallTilesPerBigTile = Math.ceil(256f/tileSize).toNumber();

        tileCacheSize = parseTileCacheSizeString("tileCacheSize", tileSize);
        mode = parseNumber("mode", mode);
        mapEnabled = parseBool("mapEnabled", mapEnabled);
        displayRouteNames = parseBool("displayRouteNames", displayRouteNames);
        enableOffTrackAlerts = parseBool("enableOffTrackAlerts", enableOffTrackAlerts);
        enableRotation = parseBool("enableRotation", enableRotation);
        routesEnabled = parseBool("routesEnabled", routesEnabled);
        trackColour = parseColour("trackColour", trackColour);
        elevationColour = parseColour("elevationColour", elevationColour);
        userColour = parseColour("userColour", userColour);
        normalModeColour = parseColour("normalModeColour", normalModeColour);
        uiColour = parseColour("uiColour", uiColour);
        debugColour = parseColour("debugColour", debugColour);
        maxPendingWebRequests = parseNumber("maxPendingWebRequests", maxPendingWebRequests);
        scale = parseOptionalFloat("scale", scale);
        if (scale == 0)
        {
            scale = null;
        }
        metersAroundUser = parseNumber("metersAroundUser", metersAroundUser);
        zoomAtPaceMode = parseNumber("zoomAtPaceMode", zoomAtPaceMode);
        zoomAtPaceSpeedMPS = parseFloat("zoomAtPaceSpeedMPS", zoomAtPaceSpeedMPS);
        uiMode = parseNumber("uiMode", uiMode);

        fixedPosition = null;
        fixedLatitude = parseOptionalFloat("fixedLatitude", fixedLatitude);
        fixedLongitude = parseOptionalFloat("fixedLongitude", fixedLongitude);
        setFixedPosition(fixedLatitude, fixedLongitude);
        tileUrl = parseString("tileUrl", tileUrl);
        routes = getArraySchema(
            "routes", 
            ["id", "name", "enabled", "colour"], 
            [method(:defaultNumberParser), method(:emptyString), method(:defaultFalse), method(:defaultColourParser)],
            routes
        );
        System.println("parsed routes: " + routes);
        disableMapsFailureCount = parseNumber("disableMapsFailureCount", disableMapsFailureCount);
        offTrackAlertsDistanceM = parseNumber("offTrackAlertsDistanceM", offTrackAlertsDistanceM);
    }

    function emptyString(key as String, value) as String
    {
        return parseStringRaw(key, value, "");
    }
    
    function defaultNumberParser(key as String, value) as Number
    {
        return parseNumberRaw(key, value, 0);
    }

    function defaultFalse(key as String, value) as Boolean
    {
        if (value instanceof Boolean)
        {
            return value;
        }

        return false;
    }

    function defaultColourParser(key as String, value) as Number
    {
        return parseColourRaw(key, value, Graphics.COLOR_RED);
    }

   function onSettingsChanged() as Void {
        System.println("onSettingsChanged: Setting Changed, loading");
        var oldRoutes = routes;
        loadSettings();
        if ( routes.size() < oldRoutes.size())
        {
            for (var i=0; i<oldRoutes.size(); ++i)
            {
                var oldRouteEntry = oldRoutes[i];
                var oldRouteId = oldRouteEntry["id"];

                var routeIndex = getRouteIndexById(oldRouteId);
                if (routeIndex != null)
                {
                    continue;
                }

                // clear the route
                clearRouteFromContext(oldRouteId);
            }
        }
    }
}