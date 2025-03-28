import Toybox.Application;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;

enum /*Mode*/ {
  MODE_NORMAL,
  MODE_ELEVATION,
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
    var routeColour as Number = Graphics.COLOR_BLUE;
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

    // calculated whenever others change
    var smallTilesPerBigTile = Math.ceil(256f/tileSize);
    var fixedPosition as RectangularPoint or Null = null;
    
    function setMode(_mode as Number) as Void {
        mode = _mode;
        Application.Properties.setValue("mode", mode);
    }
    
    function setUiMode(_uiMode as Number) as Void {
        uiMode = _uiMode;
        Application.Properties.setValue("uiMode", uiMode);
    }
    
    function setFixedPosition(lat as Float or Null, long as Float or Null) as Void {
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

        if (fixedLatitude != null && fixedLatitude == 0)
        {
            fixedLatitude = null;
        }
        if (fixedLongitude != null && fixedLongitude == 0)
        {
            fixedLongitude = null;
        }

        if (fixedLatitude == null || fixedLongitude == null)
        {
            fixedPosition = null;
            clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
            return;
        }

        // breadcrumb context might not be set yet
        fixedPosition = RectangularPoint.latLon2xy(lat, long, 0f);
        clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
    }
    
    function setZoomAtPaceMode(_zoomAtPaceMode as Number) as Void {
        zoomAtPaceMode = _zoomAtPaceMode;
        Application.Properties.setValue("zoomAtPaceMode", zoomAtPaceMode);
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
    }
    
    function setTileCacheSize(value as Number) as Void {
        tileCacheSize = value;
        Application.Properties.setValue("tileCacheSize", tileCacheSize);
    }
    
    function setMapEnabled(_mapEnabled as Boolean) as Void {
        mapEnabled = _mapEnabled;
        if (mapEnabled == null || !(mapEnabled instanceof Boolean))
        {
            mapEnabled = true;
        }
        Application.Properties.setValue("mapEnabled", mapEnabled);

        if (!mapEnabled)
        {
           clearTileCache();
           clearPendingWebRequests();
        }
    }

    function setRouteColour(value as Number) as Void {
        routeColour = value;
        Application.Properties.setValue("routeColour", routeColour.format("%X"));
    }
    
    function setTrackColour(value as Number) as Void {
        trackColour = value;
        Application.Properties.setValue("trackColour", trackColour.format("%X"));
    }
    
    function setUserColour(value as Number) as Void {
        userColour = value;
        Application.Properties.setValue("userColour", userColour.format("%X"));
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
    
    function setScale(_scale as Float or Null) as Void {
        scale = _scale;
        // be very careful about putting null into properties, it breaks everything
        if (scale == null)
        {
            Application.Properties.setValue("scale", 0);        
            return;
        }
        Application.Properties.setValue("scale", scale);
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

    // some times these parserswere throwing when it was an empty strings seem to result in, or wrong type
    // 
    // Error: Unhandled Exception
    // Exception: UnexpectedTypeException: Expected Number/Float/Long/Double/Char, given null/Number

    function parseColor(key as String, defaultValue as Number) as Number {
        var colorString = null;
        try {
            colorString = Application.Properties.getValue(key);
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

            return parseNumber(key, defaultValue);
                
        } catch (e) {
            System.println("Error parsing color: " + key + " " + colorString);
        }
        return defaultValue;
    }
    
    function parseNumber(key as String, defaultValue as Number) as Number {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
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
    
    function parseFloat(key as String, defaultValue as Float) as Float {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
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

    function parseOptionalFloat(key as String, defaultValue as Float or Null) as Float or Null {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
            if (value == null)
            {
                return null;
            }

            return parseFloat(key, defaultValue);
        } catch (e) {
            System.println("Error parsing optional float: " + key + " " + value);
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
        setRouteColour(settings.routeColour);
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

        // purge storage too on reset
        Application.Storage.clearValues();
        clearTileCache();
        clearPendingWebRequests();
        // load all the settings we just wrote
        loadSettings();
    }

    // Load the values initially from storage
    function loadSettings() as Void {
        Application.Properties.setValue("routes", [
            {
                "name" => "route1",
                "enabled" => false,
            },
            {
                "name" => "route2",
                "enabled" => true,
            }
        ]);
        var resetDefaults = Application.Properties.getValue("resetDefaults") as Boolean;
        if (resetDefaults)
        {
            resetDefaults();
            return;
        }

        System.println("loadSettings: Loading all settings");
        tileSize = parseNumber("tileSize", tileSize);
        System.println("tileSize: " + tileSize);
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
        mapEnabled = Application.Properties.getValue("mapEnabled") as Boolean;
        setMapEnabled(mapEnabled);
        trackColour = parseColor("trackColour", trackColour);
        routeColour = parseColor("routeColour", routeColour);
        elevationColour = parseColor("elevationColour", elevationColour);
        userColour = parseColor("userColour", userColour);
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
    }

    //Called on settings change
   function onSettingsChanged() as Void {
        System.println("onSettingsChanged: Setting Changed, loading");
        loadSettings();
    }
}