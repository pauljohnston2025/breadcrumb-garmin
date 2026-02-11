import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Application;

typedef Renderable as interface {
    function rerender() as Void;
};

(:settingsView)
function startPicker(
    picker as
        SettingsFloatPicker or
            SettingsNumberPicker or
            SettingsColourPickerTransparency or
            TextEditorPicker
) as Void {
    WatchUi.pushView(
        new $.NumberPickerView(picker),
        new $.NumberPickerDelegate(picker),
        WatchUi.SLIDE_IMMEDIATE
    );
}

(:settingsView)
function safeSetSubLabel(
    menu as WatchUi.Menu2,
    id as Object,
    value as String or ResourceId
) as Void {
    var itemIndex = menu.findItemById(id);
    if (itemIndex <= -1) {
        return;
    }

    var item = menu.getItem(itemIndex);
    if (item == null) {
        return;
    }

    item.setSubLabel(value);
}

(:settingsView)
function safeSetLabel(menu as WatchUi.Menu2, id as Object, value as String or ResourceId) as Void {
    var itemIndex = menu.findItemById(id);
    if (itemIndex <= -1) {
        return;
    }

    var item = menu.getItem(itemIndex);
    if (item == null) {
        return;
    }

    item.setLabel(value);
}

(:settingsView)
function safeSetToggle(menu as WatchUi.Menu2, id as Object, value as Boolean) as Void {
    var itemIndex = menu.findItemById(id);
    if (itemIndex <= -1) {
        return;
    }

    var item = menu.getItem(itemIndex);
    if (item == null) {
        return;
    }

    if (item instanceof WatchUi.ToggleMenuItem) {
        item.setEnabled(value);
    }
}

// https://forums.garmin.com/developer/connect-iq/f/discussion/379406/vertically-center-icon-in-iconmenuitem-using-menu2#pifragment-1298=4
const iconMenuWidthPercent = 0.6;

(:settingsView)
class ColourIcon extends WatchUi.Drawable {
    var colour as Number;

    function initialize(colour as Number) {
        Drawable.initialize({});
        self.colour = colour;
    }

    function draw(dc as Graphics.Dc) {
        var iconWidthHeight;

        // Calculate Width Height of Icon based on drawing area
        if (dc.getHeight() > dc.getWidth()) {
            iconWidthHeight = iconMenuWidthPercent * dc.getHeight();
        } else {
            iconWidthHeight = iconMenuWidthPercent * dc.getWidth();
        }

        dc.setColor(colour, colour);
        dc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2, iconWidthHeight / 2f);
    }
}

(:settingsView)
function safeSetIcon(menu as WatchUi.Menu2, id as Object, value as WatchUi.Drawable) as Void {
    var itemIndex = menu.findItemById(id);
    if (itemIndex <= -1) {
        return;
    }

    var item = menu.getItem(itemIndex);
    if (item == null) {
        return;
    }

    // support was added for icons on menuitems in API Level 3.4.0 but IconMenuItem had it from API 3.0.0
    // MenuItem and IconMenuItem, they both support icons
    if (item has :setIcon) {
        item.setIcon(value);
    }
}

// https://forums.garmin.com/developer/connect-iq/f/discussion/304179/programmatically-set-the-state-of-togglemenuitem
(:settingsView)
class SettingsMain extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.settingsTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.generalSettingsTitle, null, :settingsMainGeneral, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.trackSettingsTitle, null, :settingsMainTrack, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.dataFieldSettingsTitle, null, :settingsMainDataField, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.zoomAtPaceTitle, null, :settingsMainZoomAtPace, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.routesTitle, null, :settingsMainRoutes, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.mapsettingsTitle, null, :settingsMainMap, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.offTrackAlertsGroupTitle, null, :settingsMainAlerts, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.coloursTitle, null, :settingsMainColours, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.debugSettingsTitle, null, :settingsMainDebug, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.clearStorage, null, :settingsMainClearStorage, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.returnToUserTitle, null, :settingsMainReturnToUser, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.resetDefaults, null, :settingsMainResetDefaults, {}));
        rerender();
    }

    function rerender() as Void {}
}

(:settingsView)
function getDataTypeString(type as Number) as ResourceId or String {
    switch (type) {
        case DATA_TYPE_NONE:
            return Rez.Strings.dataTypeNone;
        case DATA_TYPE_SCALE:
            return Rez.Strings.dataTypeScale;
        case DATA_TYPE_ALTITUDE:
            return Rez.Strings.dataTypeAltitude;
        case DATA_TYPE_AVERAGE_HEART_RATE:
            return Rez.Strings.dataTypeAvgHR;
        case DATA_TYPE_AVERAGE_SPEED:
            return Rez.Strings.dataTypeAvgSpeed;
        case DATA_TYPE_CURRENT_HEART_RATE:
            return Rez.Strings.dataTypeCurHR;
        case DATA_TYPE_CURRENT_SPEED:
            return Rez.Strings.dataTypeCurSpeed;
        case DATA_TYPE_ELAPSED_DISTANCE:
            return Rez.Strings.dataTypeDistance;
        case DATA_TYPE_ELAPSED_TIME:
            return Rez.Strings.dataTypeTime;
        case DATA_TYPE_TOTAL_ASCENT:
            return Rez.Strings.dataTypeAscent;
        case DATA_TYPE_TOTAL_DESCENT:
            return Rez.Strings.dataTypeDescent;
        case DATA_TYPE_AVERAGE_PACE:
            return Rez.Strings.dataTypeAvgPace;
        case DATA_TYPE_CURRENT_PACE:
            return Rez.Strings.dataTypeCurPace;
        default:
            return "";
    }
}

(:settingsView)
function getZoomAtPaceModeString(mode as Number) as ResourceId or String {
    switch (mode) {
        case ZOOM_AT_PACE_MODE_PACE:
            return Rez.Strings.zoomAtPaceModePace;
        case ZOOM_AT_PACE_MODE_STOPPED:
            return Rez.Strings.zoomAtPaceModeStopped;
        case ZOOM_AT_PACE_MODE_NEVER_ZOOM:
            return Rez.Strings.zoomAtPaceModeNever;
        case ZOOM_AT_PACE_MODE_ALWAYS_ZOOM:
            return Rez.Strings.zoomAtPaceModeAlways;
        case ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK:
            return Rez.Strings.zoomAtPaceModeRoutesWithoutTrack;
        default:
            return "";
    }
}

(:settingsView)
class SettingsZoomAtPace extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.zoomAtPaceTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.zoomAtPaceModeTitle, null, :settingsZoomAtPaceMode, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.metersAroundUser, null, :settingsZoomAtPaceUserMeters, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.zoomAtPaceSpeedMPS, null, :settingsZoomAtPaceMPS, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetSubLabel(
            me,
            :settingsZoomAtPaceMode,
            getZoomAtPaceModeString(settings.zoomAtPaceMode)
        );
        safeSetSubLabel(
            me,
            :settingsZoomAtPaceUserMeters,
            settings.metersAroundUser.toString() + "m"
        );
        safeSetSubLabel(
            me,
            :settingsZoomAtPaceMPS,
            settings.zoomAtPaceSpeedMPS.format("%.2f") + "m/s"
        );
    }
}

(:settingsView)
function getModeString(mode as Number) as ResourceId or String {
    switch (mode) {
        case MODE_NORMAL:
            return Rez.Strings.trackRouteMode;
        case MODE_ELEVATION:
            return Rez.Strings.elevationMode;
        case MODE_MAP_MOVE:
            return Rez.Strings.mapMove;
        case MODE_DEBUG:
            return Rez.Strings.debug;
        default:
            return "";
    }
}

(:settingsView)
function getUiModeString(mode as Number) as ResourceId or String {
    switch (mode) {
        case UI_MODE_SHOW_ALL:
            return Rez.Strings.uiModeShowAll;
        case UI_MODE_HIDDEN:
            return Rez.Strings.uiModeHidden;
        case UI_MODE_NONE:
            return Rez.Strings.uiModeNone;
        default:
            return "";
    }
}

(:settingsView)
function getElevationModeString(mode as Number) as ResourceId or String {
    switch (mode) {
        case ELEVATION_MODE_STACKED:
            return Rez.Strings.elevationModeStacked;
        case ELEVATION_MODE_ORDERED_ROUTES:
            return Rez.Strings.elevationModeOrderedRoutes;
        default:
            return "";
    }
}

(:settingsView)
function getRenderModeString(mode as Number) as ResourceId or String {
    switch (mode) {
        case RENDER_MODE_BUFFERED_ROTATING:
            return Rez.Strings.renderModeBufferedRotating;
        case RENDER_MODE_UNBUFFERED_ROTATING:
            return Rez.Strings.renderModeUnbufferedRotating;
        case RENDER_MODE_BUFFERED_NO_ROTATION:
            return Rez.Strings.renderModeBufferedNoRotating;
        case RENDER_MODE_UNBUFFERED_NO_ROTATION:
            return Rez.Strings.renderModeNoBufferedNoRotating;
        default:
            return "";
    }
}

(:settingsView)
class SettingsGeneral extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.generalSettingsTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.modeDisplayOrderTitle, null, :settingsGeneralModeDisplayOrder, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.modeTitle, null, :settingsGeneralMode, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.uiModeTitle, null, :settingsGeneralModeUiMode, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.elevationModeTitle, null, :settingsGeneralModeElevationMode, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.recalculateIntervalSTitle, null, :settingsGeneralRecalculateIntervalS, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.renderModeTitle, null, :settingsGeneralRenderMode, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.centerUserOffsetYTitle, null, :settingsGeneralCenterUserOffsetY, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.displayLatLongTitle, null, :settingsGeneralDisplayLatLong, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.mapMoveScreenSizeTitle, null, :settingsGeneralMapMoveScreenSize, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;

        safeSetSubLabel(
            me,
            :settingsGeneralModeDisplayOrder,
            Settings.encodeCSV(settings.modeDisplayOrder)
        );
        safeSetSubLabel(me, :settingsGeneralMode, getModeString(settings.mode));
        safeSetSubLabel(me, :settingsGeneralModeUiMode, getUiModeString(settings.uiMode));
        safeSetSubLabel(
            me,
            :settingsGeneralModeElevationMode,
            getElevationModeString(settings.elevationMode)
        );
        safeSetSubLabel(
            me,
            :settingsGeneralRecalculateIntervalS,
            settings.recalculateIntervalS.toString()
        );
        safeSetSubLabel(me, :settingsGeneralRenderMode, getRenderModeString(settings.renderMode));
        safeSetSubLabel(
            me,
            :settingsGeneralCenterUserOffsetY,
            settings.centerUserOffsetY.format("%.2f")
        );
        safeSetToggle(me, :settingsGeneralDisplayLatLong, settings.displayLatLong);
        safeSetSubLabel(
            me,
            :settingsGeneralMapMoveScreenSize,
            settings.mapMoveScreenSize.format("%.2f")
        );
    }
}

(:settingsView)
function getTrackPointReductionMethodString(mode as Number) as ResourceId or String {
    switch (mode) {
        case TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE:
            return Rez.Strings.trackPointReductionMethodDownsample;
        case TRACK_POINT_REDUCTION_METHOD_REUMANN_WITKAM:
            return Rez.Strings.trackPointReductionMethodReumannWitkam;
        default:
            return "";
    }
}

(:settingsView)
class SettingsTrack extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.trackSettingsTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.maxTrackPointsTitle, null, :settingsTrackMaxTrackPoints, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.trackStyleTitle, null, :settingsTrackTrackStyle, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.trackWidthTitle, null, :settingsTrackTrackWidth, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.minTrackPointDistanceMTitle, null, :settingsTrackMinTrackPointDistanceM, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.trackPointReductionMethodTitle, null, :settingTrackTrackPointReductionMethod, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.useTrackAsHeadingSpeedMPSTitle, null, :settingsTrackUseTrackAsHeadingSpeedMPS, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetSubLabel(me, :settingsTrackMaxTrackPoints, settings.maxTrackPoints.toString());
        safeSetSubLabel(me, :settingsTrackTrackStyle, getTrackStyleString(settings.trackStyle));
        safeSetSubLabel(me, :settingsTrackTrackWidth, settings.trackWidth.toString() + "px");
        safeSetSubLabel(
            me,
            :settingsTrackMinTrackPointDistanceM,
            settings.minTrackPointDistanceM.toString()
        );
        safeSetSubLabel(
            me,
            :settingTrackTrackPointReductionMethod,
            getTrackPointReductionMethodString(settings.trackPointReductionMethod)
        );
        safeSetSubLabel(
            me,
            :settingsTrackUseTrackAsHeadingSpeedMPS,
            settings.useTrackAsHeadingSpeedMPS.format("%.2f") + "m/s"
        );
    }
}

(:settingsView)
class SettingsDataField extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.dataFieldSettingsTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.topDataTypeTitle, null, :settingsDataFieldTopDataType, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.bottomDataTypeTitle, null, :settingsDataFieldBottomDataType, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.dataFieldTextSizeTitle, null, :settingsDataFieldTextSize, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetSubLabel(me, :settingsDataFieldTopDataType, getDataTypeString(settings.topDataType));
        safeSetSubLabel(
            me,
            :settingsDataFieldTextSize,
            getFontSizeString(settings.dataFieldTextSize)
        );
        safeSetSubLabel(
            me,
            :settingsDataFieldBottomDataType,
            getDataTypeString(settings.bottomDataType)
        );
    }
}

(:settingsView)
function getPackingFormatString(mode as Number) as ResourceId or String {
    switch (mode) {
        case Communications.PACKING_FORMAT_DEFAULT:
            return Rez.Strings.packingFormatDefault;
        case Communications.PACKING_FORMAT_YUV:
            return Rez.Strings.packingFormatYUV;
        case Communications.PACKING_FORMAT_PNG:
            return Rez.Strings.packingFormatPNG;
        case Communications.PACKING_FORMAT_JPG:
            return Rez.Strings.packingFormatJPG;
        default:
            return "";
    }
}

(:settingsView)
class SettingsMap extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.mapsettingsTitle});
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.mapEnabledTitle, null, :settingsMapEnabled, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.tileServerSettingsTitle, null, :settingsMapTileServerSettings, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.mapStorageSettingsTitle, null, :settingsMapStorageSettings, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.tileCacheSizeTitle, null, :settingsMapTileCacheSize, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.tileCachePaddingTitle, null, :settingsMapTileCachePadding, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.maxPendingWebRequests, null, :settingsMapMaxPendingWebRequests, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.disableMapsFailureCountTitleShort, null, :settingsMapDisableMapsFailureCount, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.httpErrorTileTTLSTitle, null, :settingsMapHttpErrorTileTTLS, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.errorTileTTLSTitle, null, :settingsMapErrorTileTTLS, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.fixedLatitude, null, :settingsMapFixedLatitude, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.fixedLongitude, null, :settingsMapFixedLongitude, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.scaleRestrictedToTileLayersTitle, null, :settingsMapScaleRestrictedToTileLayers, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.packingFormatTitle, null, :settingsMapPackingFormat, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.useDrawBitmapTitle, null, :settingsMapUseDrawBitmap, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.attribution, null, :settingsMapAttribution, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetToggle(me, :settingsMapEnabled, true);

        safeSetSubLabel(me, :settingsMapTileCacheSize, settings.tileCacheSize.toString());
        safeSetSubLabel(me, :settingsMapTileCachePadding, settings.tileCachePadding.toString());
        safeSetSubLabel(
            me,
            :settingsMapMaxPendingWebRequests,
            settings.maxPendingWebRequests.toString()
        );
        safeSetSubLabel(
            me,
            :settingsMapDisableMapsFailureCount,
            settings.disableMapsFailureCount.toString()
        );
        var fixedLatitude = settings.fixedLatitude;
        var latString = fixedLatitude == null ? "Disabled" : fixedLatitude.format("%.5f");
        safeSetSubLabel(me, :settingsMapFixedLatitude, latString);
        var fixedLongitude = settings.fixedLongitude;
        var longString = fixedLongitude == null ? "Disabled" : fixedLongitude.format("%.5f");
        safeSetSubLabel(me, :settingsMapFixedLongitude, longString);
        safeSetToggle(
            me,
            :settingsMapScaleRestrictedToTileLayers,
            settings.scaleRestrictedToTileLayers()
        );
        safeSetSubLabel(me, :settingsMapHttpErrorTileTTLS, settings.httpErrorTileTTLS.toString());
        safeSetSubLabel(me, :settingsMapErrorTileTTLS, settings.errorTileTTLS.toString());
        safeSetToggle(me, :settingsMapUseDrawBitmap, settings.useDrawBitmap);
        safeSetSubLabel(
            me,
            :settingsMapPackingFormat,
            getPackingFormatString(settings.packingFormat)
        );
    }
}

(:settingsView)
function getMapChoiceString(mapChoice as Number) as ResourceId {
    switch (mapChoice) {
        case 0:
            return Rez.Strings.custom;
        case 1:
            return Rez.Strings.companionApp;
        case 2:
            return Rez.Strings.openTopoMap;
        case 3:
            return Rez.Strings.esriWorldImagery;
        case 4:
            return Rez.Strings.esriWorldStreetMap;
        case 5:
            return Rez.Strings.esriWorldTopoMap;
        case 6:
            return Rez.Strings.esriWorldTransportation;
        case 7:
            return Rez.Strings.esriWorldDarkGrayBase;
        case 8:
            return Rez.Strings.esriWorldHillshade;
        case 9:
            return Rez.Strings.esriWorldHillshadeDark;
        case 10:
            return Rez.Strings.esriWorldLightGrayBase;
        case 11:
            return Rez.Strings.esriUSATopoMaps;
        case 12:
            return Rez.Strings.esriWorldOceanBase;
        case 13:
            return Rez.Strings.esriWorldShadedRelief;
        case 14:
            return Rez.Strings.esriNatGeoWorldMap;
        case 15:
            return Rez.Strings.esriWorldNavigationCharts;
        case 16:
            return Rez.Strings.esriWorldPhysicalMap;
        case 17:
            return Rez.Strings.openStreetMapcyclosm;
        case 18:
            return Rez.Strings.stadiaAlidadeSmooth;
        case 19:
            return Rez.Strings.stadiaAlidadeSmoothDark;
        case 20:
            return Rez.Strings.stadiaOutdoors;
        case 21:
            return Rez.Strings.stadiaStamenToner;
        case 22:
            return Rez.Strings.stadiaStamenTonerLite;
        case 23:
            return Rez.Strings.stadiaStamenTerrain;
        case 24:
            return Rez.Strings.stadiaStamenWatercolor;
        case 25:
            return Rez.Strings.stadiaOSMBright;
        case 26:
            return Rez.Strings.cartoVoyager;
        case 27:
            return Rez.Strings.cartoDarkMatter;
        case 28:
            return Rez.Strings.cartoDarkLightAll;
        case 29:
            return Rez.Strings.mapyBasic;
        case 30:
            return Rez.Strings.mapyOutdoor;
        case 31:
            return Rez.Strings.mapyWinter;
        case 32:
            return Rez.Strings.mapyAerial;
        default:
            return Rez.Strings.custom;
    }
}

(:settingsView)
class SettingsTileServer extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.tileServerSettingsTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.mapChoice, null, :settingsMapChoice, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.tileUrlTitle, null, :settingsTileUrl, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.authTokenTitle, null, :settingsAuthToken, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.layerTileSize, null, :settingsMapTileSize, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.scaledTileSizeTitle, null, :settingsMapScaledTileSize, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.tileLayerMaxTitle, null, :settingsMapTileLayerMax, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.tileLayerMinTitle, null, :settingsMapTileLayerMin, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.fullTileSizeTitle, null, :settingsMapFullTileSize, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;

        safeSetSubLabel(me, :settingsMapChoice, getMapChoiceString(settings.mapChoice));
        safeSetSubLabel(me, :settingsTileUrl, settings.tileUrl);
        safeSetSubLabel(me, :settingsAuthToken, settings.authToken);
        safeSetSubLabel(me, :settingsMapTileSize, settings.tileSize.toString());
        safeSetSubLabel(me, :settingsMapFullTileSize, settings.fullTileSize.toString());
        safeSetSubLabel(me, :settingsMapScaledTileSize, settings.scaledTileSize.toString());
        safeSetSubLabel(me, :settingsMapTileLayerMax, settings.tileLayerMax.toString());
        safeSetSubLabel(me, :settingsMapTileLayerMin, settings.tileLayerMin.toString());
    }
}

(:settingsView)
class SettingsMapStorage extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.mapStorageSettingsTitle});
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.cacheTilesInStorageTitle, null, :settingsMapStorageCacheTilesInStorage, false, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.storageMapTilesOnlyTitle, null, :settingsMapStorageStorageMapTilesOnly, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.storageTileCacheSizeTitle, null, :settingsMapStorageStorageTileCacheSize, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.storageTileCachePageCountTitle, null, :settingsMapStorageStorageTileCachePageCount, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.storageSeedBoundingBoxTitle, null, :settingsMapStorageStorageSeedBoundingBox, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.storageSeedRouteDistanceMTitle, null, :settingsMapStorageStorageSeedRouteDistanceM, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.cacheCurrentArea, null, :settingsMapStorageCacheCurrentArea, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.cancelCacheDownload, null, :settingsMapStorageCancelCacheDownload, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.clearCachedTiles, null, :settingsMapStorageClearCachedTiles, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetToggle(me, :settingsMapStorageCacheTilesInStorage, settings.cacheTilesInStorage);
        safeSetToggle(me, :settingsMapStorageStorageMapTilesOnly, settings.storageMapTilesOnly);
        safeSetSubLabel(
            me,
            :settingsMapStorageStorageTileCacheSize,
            settings.storageTileCacheSize.toString()
        );
        safeSetSubLabel(
            me,
            :settingsMapStorageStorageTileCachePageCount,
            settings.storageTileCachePageCount.toString()
        );
        safeSetToggle(
            me,
            :settingsMapStorageStorageSeedBoundingBox,
            settings.storageSeedBoundingBox
        );
        safeSetSubLabel(
            me,
            :settingsMapStorageStorageSeedRouteDistanceM,
            settings.storageSeedRouteDistanceM.format("%.2f")
        );
        var cacheSize =
            "" +
            getApp()._breadcrumbContext.tileCache._storageTileCache._totalTileCount +
            "/" +
            settings.storageTileCacheSize;
        safeSetSubLabel(me, :settingsMapStorageCacheCurrentArea, cacheSize);
    }
}

function alertsCommonMenu(menu as WatchUi.Menu2) as Void
{
    menu.addItem(new WatchUi.MenuItem(Rez.Strings.offTrackAlertsDistanceMTitle, null, :settingsAlertsOffTrackDistanceM, {}));
    menu.addItem(new WatchUi.MenuItem(Rez.Strings.offTrackCheckIntervalSTitle, null, :settingsAlertsOffTrackCheckIntervalS, {}));
    menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.drawLineToClosestPointTitle, null, :settingsAlertsDrawLineToClosestPoint, false, {}));
    menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.drawCheveronsTitle, null, :settingsAlertsDrawCheverons, false, {}));
    menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.offTrackWrongDirectionTitle, null, :settingsAlertsOffTrackWrongDirection, false, {}));
    menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.enableOffTrackAlertsTitle, null, :settingsAlertsEnabled, false, {}));
    menu.addItem(new WatchUi.MenuItem(Rez.Strings.turnAlertTimeSTitle, null, :settingsAlertsTurnAlertTimeS, {}));
    menu.addItem(new WatchUi.MenuItem(Rez.Strings.minTurnAlertDistanceMTitle, null, :settingsAlertsMinTurnAlertDistanceM, {}));
    menu.addItem(new WatchUi.MenuItem(Rez.Strings.alertTypeTitle, null, :settingsAlertsAlertType, {}));
}

(:settingsView)
class SettingsMapDisabled extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.mapsettingsTitle});
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.mapEnabledTitle, null, :settingsMapEnabled, false, {}));
        rerender();
    }

    function rerender() as Void {
        safeSetToggle(me, :settingsMapEnabled, false);
    }
}

(:settingsView)
class SettingsAlerts extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.offTrackAlertsGroupTitle});
        alertsCommonMenu(self);
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        alertsCommon(me, settings);
        safeSetSubLabel(
            me,
            :settingsAlertsOffTrackAlertsMaxReportIntervalS,
            settings.offTrackAlertsMaxReportIntervalS.toString()
        );
    }
}

(:settingsView)
function getAlertTypeString(mode as Number) as ResourceId or String {
    switch (mode) {
        case ALERT_TYPE_TOAST:
            return Rez.Strings.alertTypeToast;
        case ALERT_TYPE_ALERT:
            return Rez.Strings.alertTypeAlert;
        case ALERT_TYPE_IMAGE:
            return Rez.Strings.alertTypeImage;
        default:
            return "";
    }
}

(:settingsView)
function alertsCommon(menu as WatchUi.Menu2, settings as Settings) as Void {
    safeSetSubLabel(
        menu,
        :settingsAlertsOffTrackDistanceM,
        settings.offTrackAlertsDistanceM.toString()
    );
    safeSetSubLabel(
        menu,
        :settingsAlertsOffTrackCheckIntervalS,
        settings.offTrackCheckIntervalS.toString()
    );
    safeSetToggle(menu, :settingsAlertsDrawLineToClosestPoint, settings.drawLineToClosestPoint);
    safeSetToggle(menu, :settingsAlertsDrawCheverons, settings.drawCheverons);
    safeSetToggle(menu, :settingsAlertsOffTrackWrongDirection, settings.offTrackWrongDirection);
    safeSetToggle(menu, :settingsAlertsEnabled, settings.enableOffTrackAlerts);
    safeSetSubLabel(menu, :settingsAlertsTurnAlertTimeS, settings.turnAlertTimeS.toString());
    safeSetSubLabel(
        menu,
        :settingsAlertsMinTurnAlertDistanceM,
        settings.minTurnAlertDistanceM.toString()
    );
    safeSetSubLabel(menu, :settingsAlertsAlertType, getAlertTypeString(settings.alertType));
}

(:settingsView)
class SettingsAlertsDisabled extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.offTrackAlertsGroupTitle});
        alertsCommonMenu(self);
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        alertsCommon(me, settings);
    }
}

(:settingsView)
class SettingsColours extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.coloursTitle});
        addItem(new WatchUi.IconMenuItem(Rez.Strings.trackColourTitle, null, :settingsColoursTrackColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.trackColour2Title, null, :settingsColoursTrackColour2, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.defaultRouteColourTitle, null, :settingsColoursDefaultRouteColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.elevationColourTitle, null, :settingsColoursElevationColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.userColour, null, :settingsColoursUserColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.normalModeColour, null, :settingsColoursNormalModeColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.uiColour, null, :settingsColoursUiColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.debugColour, null, :settingsColoursDebugColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetIcon(me, :settingsColoursTrackColour, new ColourIcon(settings.trackColour));
        safeSetIcon(me, :settingsColoursTrackColour2, new ColourIcon(settings.trackColour2));
        safeSetIcon(
            me,
            :settingsColoursDefaultRouteColour,
            new ColourIcon(settings.defaultRouteColour)
        );
        safeSetIcon(me, :settingsColoursUserColour, new ColourIcon(settings.userColour));
        safeSetIcon(me, :settingsColoursElevationColour, new ColourIcon(settings.elevationColour));
        safeSetIcon(
            me,
            :settingsColoursNormalModeColour,
            new ColourIcon(settings.normalModeColour)
        );
        safeSetIcon(me, :settingsColoursUiColour, new ColourIcon(settings.uiColour));
        safeSetIcon(me, :settingsColoursDebugColour, new ColourIcon(settings.debugColour));
    }
}

(:settingsView)
class SettingsDebug extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>Rez.Strings.debugSettingsTitle});
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.drawLineToClosestTrackTitle, null, :settingsDebugDrawLineToClosestTrack, false, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.showTileBordersTitle, null, :settingsDebugShowTileBorders, false, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.showErrorTileMessagesTitle, null, :settingsDebugShowErrorTileMessages, false, {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.tileErrorColourTitle, null, :settingsDebugTileErrorColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.drawHitBoxesTitle, null, :settingsDebugDrawHitBoxes, false, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.showDirectionPointsTitle, null, :settingsDebugShowDirectionPoints, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.showDirectionPointTextUnderIndexTitle, null, :settingsDebugShowDirectionPointTextUnderIndex, {}));
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetIcon(me, :settingsDebugTileErrorColour, new ColourIcon(settings.tileErrorColour));
        safeSetToggle(me, :settingsDebugDrawLineToClosestTrack, settings.drawLineToClosestTrack);
        safeSetToggle(me, :settingsDebugShowTileBorders, settings.showTileBorders);
        safeSetToggle(me, :settingsDebugShowErrorTileMessages, settings.showErrorTileMessages);
        safeSetToggle(me, :settingsDebugDrawHitBoxes, settings.drawHitBoxes);
        safeSetToggle(me, :settingsDebugShowDirectionPoints, settings.showDirectionPoints);
        safeSetSubLabel(
            me,
            :settingsDebugShowDirectionPointTextUnderIndex,
            settings.showDirectionPointTextUnderIndex.toString()
        );
    }
}

(:settingsView)
class SettingsRoute extends WatchUi.Menu2 {
    var settings as Settings;
    var routeId as Number;
    var parent as SettingsRoutes;
    function initialize(settings as Settings, routeId as Number, parent as SettingsRoutes) {
        Menu2.initialize({:title=>Rez.Strings.routesTitle});
        addItem(new WatchUi.MenuItem(Rez.Strings.routeName, null, :settingsRouteName, {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.routeEnabled, null, :settingsRouteEnabled, false, {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.routeColourTitle, null, :settingsRouteColour, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.IconMenuItem(Rez.Strings.routeColour2Title, null, :settingsRouteColour2, new ColourIcon(Graphics.COLOR_BLACK), {}));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.routeReversed, null, :settingsRouteReversed, false, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.routeStyleTitle, null, :settingsRouteStyle, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.routeWidthTitle, null, :settingsRouteWidth, {}));
        addItem(new WatchUi.MenuItem(Rez.Strings.routeDelete, null, :settingsRouteDelete, {}));
        self.settings = settings;
        self.routeId = routeId;
        self.parent = parent;
        rerender();
    }

    function rerender() as Void {
        var name = settings.routeName(routeId);
        setTitle(name);
        safeSetSubLabel(me, :settingsRouteName, name);
        safeSetToggle(me, :settingsRouteEnabled, settings.routeEnabled(routeId));
        safeSetIcon(me, :settingsRouteColour, new ColourIcon(settings.routeColour(routeId)));
        safeSetIcon(me, :settingsRouteColour2, new ColourIcon(settings.routeColour2(routeId)));
        safeSetSubLabel(me, :settingsRouteStyle, getTrackStyleString(settings.routeStyle(routeId)));
        safeSetSubLabel(me, :settingsRouteWidth, settings.routeWidth(routeId).toString() + "px");
        safeSetToggle(me, :settingsRouteReversed, settings.routeReversed(routeId));
        parent.rerender();
    }

    function setName(value as String) as Void {
        settings.setRouteName(routeId, value);
    }

    function setEnabled(value as Boolean) as Void {
        settings.setRouteEnabled(routeId, value);
    }

    function setReversed(value as Boolean) as Void {
        settings.setRouteReversed(routeId, value);
    }

    function routeEnabled() as Boolean {
        return settings.routeEnabled(routeId);
    }

    function routeReversed() as Boolean {
        return settings.routeReversed(routeId);
    }

    function routeColour() as Number {
        return settings.routeColour(routeId);
    }

    function routeColour2() as Number {
        return settings.routeColour2(routeId);
    }

    function setColour(value as Number) as Void {
        settings.setRouteColour(routeId, value);
    }

    function setColour2(value as Number) as Void {
        settings.setRouteColour2(routeId, value);
    }

    function setStyle(value as Number) as Void {
        settings.setRouteStyle(routeId, value);
    }

    function setWidth(value as Number) as Void {
        settings.setRouteWidth(routeId, value);
    }
}

(:settingsView)
class SettingsRoutes extends WatchUi.Menu2 {
    var settings as Settings;
    function initialize(settings as Settings) {
        WatchUi.Menu2.initialize({
            :title => Rez.Strings.routesTitle,
        });
        me.settings = settings;
        setup();
        rerender();
    }

    function setup() as Void {
        addItem(
            new ToggleMenuItem(
                Rez.Strings.routesEnabled,
                "", // sublabel
                :settingsRoutesEnabled,
                settings.routesEnabled,
                {}
            )
        );
        if (!settings.routesEnabled) {
            return;
        }

        addItem(
            new ToggleMenuItem(
                Rez.Strings.displayRouteNamesTitle,
                "", // sublabel
                :settingsDisplayRouteNames,
                settings.displayRouteNames,
                {}
            )
        );

        addItem(
            new MenuItem(
                Rez.Strings.routeMax,
                settings.routeMax().toString(),
                :settingsDisplayRouteMax,
                {}
            )
        );

        addItem(
            new MenuItem(
                Rez.Strings.clearRoutes,
                "", // sublabel
                :settingsRoutesClearAll,
                {}
            )
        );

        // don't use route max, sometimes it gets out of sync, we want to pull in all the routes so we can remove them
        for (var i = 0; i < settings.routes.size(); ++i) {
            var routeIndex = settings.getRouteIndexById(i);
            if (routeIndex == null) {
                // do not show routes that are not in the settings array
                // but still show disabled routes that are in the array
                continue;
            }
            var routeName = settings.routeName(i);
            var enabledStr = settings.routeEnabled(i) ? "Enabled" : "Disabled";
            var reversedStr = settings.routeReversed(i) ? "Reversed" : "Forward";
            addItem(
                // do not be tempted to switch this to a menuitem (IconMenuItem is supported since API 3.0.0, MenuItem only supports icons from API 3.4.0)
                new IconMenuItem(
                    routeName.equals("") ? "<unlabeled>" : routeName,
                    enabledStr + " " + reversedStr,
                    i,
                    new ColourIcon(settings.routeColour(i)),
                    {
                        // only get left or right, no center :(
                        :alignment => MenuItem.MENU_ITEM_LABEL_ALIGN_LEFT,
                    }
                )
            );
        }
    }

    function rerender() as Void {
        safeSetToggle(me, :settingsRoutesEnabled, settings.routesEnabled);
        safeSetToggle(me, :settingsDisplayRouteNames, settings.displayRouteNames);
        safeSetSubLabel(me, :settingsDisplayRouteMax, settings.routeMax().toString());
        for (var i = 0; i < settings.routeMax(); ++i) {
            var routeName = settings.routeName(i);
            safeSetLabel(me, i, routeName.equals("") ? "<unlabeled>" : routeName);
            safeSetIcon(me, i, new ColourIcon(settings.routeColour(i)));
            safeSetSubLabel(me, i, settings.routeEnabled(i) ? "Enabled" : "Disabled");
        }
    }
}

(:settingsView)
class SettingsMainDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsMain;
    function initialize(view as SettingsMain) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsMainGeneral) {
            var view = new $.SettingsGeneral();
            WatchUi.pushView(view, new $.SettingsGeneralDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainTrack) {
            var view = new $.SettingsTrack();
            WatchUi.pushView(view, new $.SettingsTrackDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainDataField) {
            var view = new $.SettingsDataField();
            WatchUi.pushView(view, new $.SettingsDataFieldDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainZoomAtPace) {
            var view = new $.SettingsZoomAtPace();
            WatchUi.pushView(view, new $.SettingsZoomAtPaceDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainRoutes) {
            var view = new $.SettingsRoutes(settings);
            WatchUi.pushView(
                view,
                new $.SettingsRoutesDelegate(view, settings),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainMap) {
            if (settings.mapEnabled) {
                var view = new SettingsMap();
                WatchUi.pushView(view, new $.SettingsMapDelegate(view), WatchUi.SLIDE_IMMEDIATE);
                return;
            }
            var disabledView = new SettingsMapDisabled();
            WatchUi.pushView(
                disabledView,
                new $.SettingsMapDisabledDelegate(disabledView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainAlerts) {
            if (settings.offTrackWrongDirection || settings.enableOffTrackAlerts) {
                var view = new SettingsAlerts();
                WatchUi.pushView(view, new $.SettingsAlertsDelegate(view), WatchUi.SLIDE_IMMEDIATE);
                return;
            }
            var disabledView = new SettingsAlertsDisabled();
            WatchUi.pushView(
                disabledView,
                new $.SettingsAlertsDisabledDelegate(disabledView),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainColours) {
            var view = new SettingsColours();
            WatchUi.pushView(view, new $.SettingsColoursDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainDebug) {
            var view = new SettingsDebug();
            WatchUi.pushView(view, new $.SettingsDebugDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainClearStorage) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.clearStorage) as String
            );
            WatchUi.pushView(dialog, new ClearStorageDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainReturnToUser) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.returnToUserTitle) as String
            );
            WatchUi.pushView(dialog, new ReturnToUserDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMainResetDefaults) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.resetDefaults) as String
            );
            WatchUi.pushView(dialog, new ResetSettingsDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

(:settingsView)
class ResetSettingsDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        WatchUi.ConfirmationDelegate.initialize();
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getApp()._breadcrumbContext.settings.resetDefaults();
        }

        return true; // we always handle it
    }
}

(:settingsView)
class ReturnToUserDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        WatchUi.ConfirmationDelegate.initialize();
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getApp()._breadcrumbContext.cachedValues.returnToUser();
        }

        return true; // we always handle it
    }
}

(:settingsView)
class ClearStorageDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        WatchUi.ConfirmationDelegate.initialize();
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            Application.Storage.clearValues(); // purge the storage, but we have to clean up all our classes that load from storage too
            getApp()._breadcrumbContext.tileCache._storageTileCache.reset(); // reload our tile storage class
            getApp()._breadcrumbContext.tileCache.clearValues(); // also clear the tile cache, it case it pulled from our storage
            getApp()._breadcrumbContext.clearRoutes(); // also clear the routes to mimic storage being removed
            getApp()._breadcrumbContext.settings.storageCleared();
        }

        return true; // we always handle it
    }
}

(:settingsView)
class ClearCachedTilesDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        WatchUi.ConfirmationDelegate.initialize();
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getApp()._breadcrumbContext.tileCache._storageTileCache.clearValues();
            getApp()._breadcrumbContext.tileCache.clearValues(); // also clear the tile cache, in case it pulled from our storage

            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop confirmation
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop map storage view
            var view = new $.SettingsMapStorage();
            WatchUi.pushView(view, new $.SettingsMapStorageDelegate(view), WatchUi.SLIDE_IMMEDIATE); // replace with new updated map storage view
            WatchUi.pushView(new DummyView(), null, WatchUi.SLIDE_IMMEDIATE); // push dummy view for the confirmation to pop
        }

        return true; // we always handle it
    }
}

(:settingsView)
class StartCachedTilesDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        WatchUi.ConfirmationDelegate.initialize();
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getApp()._breadcrumbContext.cachedValues.startCacheCurrentMapArea();
        }

        return true; // we always handle it
    }
}

(:settingsView)
class DeleteRouteDelegate extends WatchUi.ConfirmationDelegate {
    var routeId as Number;
    var settings as Settings;
    function initialize(_routeId as Number, _settings as Settings) {
        WatchUi.ConfirmationDelegate.initialize();
        routeId = _routeId;
        settings = _settings;
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getApp()._breadcrumbContext.clearRoute(routeId);

            // WARNING: this is a massive hack, probably dependant on platform
            // just poping the vew and replacing does not work, because the confirmation is still active whilst we are in this function
            // so we need to pop the confirmation too
            // but the confirmation is also about to call WatchUi.popView()
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop confirmation
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop route view
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop routes view
            var view = new $.SettingsRoutes(settings);
            WatchUi.pushView(
                view,
                new $.SettingsRoutesDelegate(view, settings),
                WatchUi.SLIDE_IMMEDIATE
            ); // replace with new updated routes view
            WatchUi.pushView(new DummyView(), null, WatchUi.SLIDE_IMMEDIATE); // push dummy view for the confirmation to pop
        }

        return true; // we always handle it
    }
}

class SettingsMapAttributionDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        WatchUi.Menu2InputDelegate.initialize();
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var itemId = item.getId() as Object;
        switch (itemId) {
            case :settingsMapAttributionOpenTopoMap:
                Communications.openWebPage("https://opentopomap.org/about", {}, {});
                break;
            case :settingsMapAttributionGoogle:
                Communications.openWebPage("https://cloud.google.com/maps-platform/terms", {}, {});
                break;
            case :settingsMapAttributionEsri:
                Communications.openWebPage("https://www.esri.com", {}, {});
                break;
            case :settingsMapAttributionOpenStreetmap:
                Communications.openWebPage("https://openstreetmap.org/copyright", {}, {});
                break;
            case :settingsMapAttributionStadia:
                Communications.openWebPage("https://stadiamaps.com/", {}, {});
                break;
            case :settingsMapAttributionOpenMapTiles:
                Communications.openWebPage("https://openmaptiles.org/", {}, {});
                break;
            case :settingsMapAttributionCarto:
                Communications.openWebPage("https://carto.com/attributions/", {}, {});
                break;
            case :settingsMapAttributionMapy:
                Communications.openWebPage("https://mapy.com/", {}, {});
                break;
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsZoomAtPaceDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsZoomAtPace;
    function initialize(view as SettingsZoomAtPace) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getZoomAtPaceModeStringL(value as Number) as ResourceId or String {
        return getZoomAtPaceModeString(value);
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsZoomAtPaceMode) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.zoomAtPaceModeTitle,
                    method(:getZoomAtPaceModeStringL),
                    settings.zoomAtPaceMode,
                    ZOOM_AT_PACE_MODE_MAX
                ),
                new $.EnumDelegate(settings.method(:setZoomAtPaceMode), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsZoomAtPaceUserMeters) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setMetersAroundUser),
                    settings.metersAroundUser,
                    view
                )
            );
        } else if (itemId == :settingsZoomAtPaceMPS) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setZoomAtPaceSpeedMPS),
                    settings.zoomAtPaceSpeedMPS,
                    view
                )
            );
        }
    }
}

(:settingsView)
class SettingsGeneralDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsGeneral;
    function initialize(view as SettingsGeneral) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getModeStringL(value as Number) as ResourceId or String {
        return getModeString(value);
    }

    public function getUiModeStringL(value as Number) as ResourceId or String {
        return getUiModeString(value);
    }

    public function getElevationModeStringL(value as Number) as ResourceId or String {
        return getElevationModeString(value);
    }

    public function getRenderModeStringL(value as Number) as ResourceId or String {
        return getRenderModeString(value);
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();

        if (itemId == :settingsGeneralModeDisplayOrder) {
            startPicker(
                new TextEditorPicker(
                    settings.method(:setModeDisplayOrder),
                    Settings.encodeCSV(settings.modeDisplayOrder),
                    view
                )
            );
        } else if (itemId == :settingsGeneralMode) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.modeTitle,
                    method(:getModeStringL),
                    settings.mode,
                    MODE_MAX
                ),
                new $.EnumDelegate(settings.method(:setMode), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsGeneralModeUiMode) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.uiModeTitle,
                    method(:getUiModeStringL),
                    settings.uiMode,
                    UI_MODE_MAX
                ),
                new $.EnumDelegate(settings.method(:setUiMode), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsGeneralModeElevationMode) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.elevationModeTitle,
                    method(:getElevationModeStringL),
                    settings.elevationMode,
                    ELEVATION_MODE_MAX
                ),
                new $.EnumDelegate(settings.method(:setElevationMode), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsGeneralRecalculateIntervalS) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setRecalculateIntervalS),
                    settings.recalculateIntervalS,
                    view
                )
            );
        } else if (itemId == :settingsGeneralRenderMode) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.renderModeTitle,
                    method(:getRenderModeStringL),
                    settings.renderMode,
                    RENDER_MODE_MAX
                ),
                new $.EnumDelegate(settings.method(:setRenderMode), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsGeneralCenterUserOffsetY) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setCenterUserOffsetY),
                    settings.centerUserOffsetY,
                    view
                )
            );
        } else if (itemId == :settingsGeneralDisplayLatLong) {
            settings.toggleDisplayLatLong();
            view.rerender();
        } else if (itemId == :settingsGeneralMapMoveScreenSize) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setMapMoveScreenSize),
                    settings.mapMoveScreenSize,
                    view
                )
            );
        }
    }
}

(:settingsView)
class SettingsTrackDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsTrack;
    function initialize(view as SettingsTrack) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getTrackStyleStringL(value as Number) as ResourceId or String {
        return getTrackStyleString(value);
    }

    public function getTrackPointReductionMethodStringL(value as Number) as ResourceId or String {
        return getTrackPointReductionMethodString(value);
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();

        if (itemId == :settingsTrackMaxTrackPoints) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setMaxTrackPoints),
                    settings.maxTrackPoints,
                    view
                )
            );
        } else if (itemId == :settingsTrackTrackStyle) {
            // Push the style picker
            var menu = new EnumMenu(
                Rez.Strings.trackStyleTitle,
                method(:getTrackStyleStringL),
                settings.trackStyle,
                TRACK_STYLE_MAX
            );
            var delegate = new $.EnumDelegate(settings.method(:setTrackStyle), view);
            WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsTrackTrackWidth) {
            startPicker(
                new SettingsNumberPicker(settings.method(:setTrackWidth), settings.trackWidth, view)
            );
        } else if (itemId == :settingsTrackMinTrackPointDistanceM) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setMinTrackPointDistanceM),
                    settings.minTrackPointDistanceM,
                    view
                )
            );
        } else if (itemId == :settingTrackTrackPointReductionMethod) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.trackPointReductionMethodTitle,
                    method(:getTrackPointReductionMethodStringL),
                    settings.trackPointReductionMethod,
                    TRACK_POINT_REDUCTION_METHOD_MAX
                ),
                new $.EnumDelegate(settings.method(:setTrackPointReductionMethod), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsTrackUseTrackAsHeadingSpeedMPS) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setUseTrackAsHeadingSpeedMPS),
                    settings.useTrackAsHeadingSpeedMPS,
                    view
                )
            );
        }
    }
}

(:settingsView)
class SettingsDataFieldDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsDataField;
    function initialize(view as SettingsDataField) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getDataTypeStringL(value as Number) as ResourceId or String {
        return getDataTypeString(value);
    }
    public function getFontSizeStringL(value as Number) as ResourceId or String {
        return getFontSizeString(value);
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();

        if (itemId == :settingsDataFieldTopDataType) {
            WatchUi.pushView(
                new EnumMenu(
                    "Data Type",
                    method(:getDataTypeStringL),
                    settings.topDataType,
                    DATA_TYPE_MAX
                ),
                new $.EnumDelegate(settings.method(:setTopDataType), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsDataFieldBottomDataType) {
            WatchUi.pushView(
                new EnumMenu(
                    "Data Type",
                    method(:getDataTypeStringL),
                    settings.bottomDataType,
                    DATA_TYPE_MAX
                ),
                new $.EnumDelegate(settings.method(:setBottomDataType), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsDataFieldTextSize) {
            WatchUi.pushView(
                new EnumMenu(
                    "Font Size",
                    method(:getFontSizeStringL),
                    settings.dataFieldTextSize,
                    5
                ),
                new $.EnumDelegate(settings.method(:setDataFieldTextSize), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }
}

(:settingsView)
class SettingsRoutesDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsRoutes;
    var settings as Settings;
    function initialize(view as SettingsRoutes, settings as Settings) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
        me.settings = settings;
    }

    function setRouteMax(value as Number) as Void {
        settings.setRouteMax(value);
        // reload our ui, so any route changes are cleared
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // remove the number picker view
        reloadView();
        WatchUi.pushView(new DummyView(), null, WatchUi.SLIDE_IMMEDIATE); // push dummy view for the number picker to remove
    }

    function reloadView() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        var view = new $.SettingsRoutes(settings);
        WatchUi.pushView(
            view,
            new $.SettingsRoutesDelegate(view, settings),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var itemId = item.getId();
        if (itemId == :settingsRoutesEnabled) {
            settings.toggleRoutesEnabled();
            reloadView();
        } else if (itemId == :settingsDisplayRouteNames) {
            settings.toggleDisplayRouteNames();
            view.rerender();
        } else if (itemId == :settingsDisplayRouteMax) {
            startPicker(new SettingsNumberPicker(method(:setRouteMax), settings.routeMax(), view));
        } else if (itemId == :settingsRoutesClearAll) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.clearRoutes1) as String
            );
            WatchUi.pushView(dialog, new ClearRoutesDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }

        // itemId should now be the route storageIndex = routeId
        if (itemId instanceof Number) {
            var thisView = new $.SettingsRoute(settings, itemId, view);
            WatchUi.pushView(
                thisView,
                new $.SettingsRouteDelegate(thisView, settings),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }
}

(:settingsView)
class SettingsRouteDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsRoute;
    var settings as Settings;
    function initialize(view as SettingsRoute, settings as Settings) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
        me.settings = settings;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var itemId = item.getId();
        if (itemId == :settingsRouteName) {
            startPicker(
                new TextEditorPicker(view.method(:setName), settings.routeName(view.routeId), view)
            );
        } else if (itemId == :settingsRouteEnabled) {
            if (view.routeEnabled()) {
                view.setEnabled(false);
            } else {
                view.setEnabled(true);
            }
            view.rerender();
        } else if (itemId == :settingsRouteReversed) {
            if (view.routeReversed()) {
                view.setReversed(false);
            } else {
                view.setReversed(true);
            }
            view.rerender();
        } else if (itemId == :settingsRouteColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    view.method(:setColour),
                    view.routeColour(),
                    view,
                    false
                )
            );
        } else if (itemId == :settingsRouteColour2) {
            startPicker(
                new SettingsColourPickerTransparency(
                    view.method(:setColour2),
                    view.routeColour2(),
                    view,
                    true
                )
            );
        } else if (itemId == :settingsRouteDelete) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.routeDelete) as String
            );
            WatchUi.pushView(
                dialog,
                new DeleteRouteDelegate(view.routeId, settings),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsRouteStyle) {
            var menu = new EnumMenu(
                Rez.Strings.trackStyleTitle,
                method(:getTrackStyleStringL),
                view.settings.routeStyle(view.routeId),
                TRACK_STYLE_MAX
            );
            var delegate = new $.EnumDelegate(view.method(:setStyle), view);
            WatchUi.pushView(menu, delegate, WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsRouteWidth) {
            startPicker(
                new SettingsNumberPicker(
                    view.method(:setWidth),
                    view.settings.routeWidth(view.routeId),
                    view
                )
            );
        }
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getTrackStyleStringL(value as Number) as ResourceId or String {
        return getTrackStyleString(value);
    }
}

(:settingsView)
class SettingsMapDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsMap;
    function initialize(view as SettingsMap) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsMapEnabled) {
            settings.setMapEnabled(false);
            var view = new SettingsMapDisabled();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.pushView(
                view,
                new $.SettingsMapDisabledDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMapTileCacheSize) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setTileCacheSize),
                    settings.tileCacheSize,
                    view
                )
            );
        } else if (itemId == :settingsMapTileCachePadding) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setTileCachePadding),
                    settings.tileCachePadding,
                    view
                )
            );
        } else if (itemId == :settingsMapMaxPendingWebRequests) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setMaxPendingWebRequests),
                    settings.maxPendingWebRequests,
                    view
                )
            );
        } else if (itemId == :settingsMapDisableMapsFailureCount) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setDisableMapsFailureCount),
                    settings.disableMapsFailureCount,
                    view
                )
            );
        } else if (itemId == :settingsMapHttpErrorTileTTLS) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setHttpErrorTileTTLS),
                    settings.httpErrorTileTTLS,
                    view
                )
            );
        } else if (itemId == :settingsMapErrorTileTTLS) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setErrorTileTTLS),
                    settings.errorTileTTLS,
                    view
                )
            );
        } else if (itemId == :settingsMapFixedLatitude) {
            var fixedLatitude = settings.fixedLatitude;
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setFixedLatitude),
                    fixedLatitude != null ? fixedLatitude : 0f,
                    view
                )
            );
        } else if (itemId == :settingsMapFixedLongitude) {
            var fixedLongitude = settings.fixedLongitude;
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setFixedLongitude),
                    fixedLongitude != null ? fixedLongitude : 0f,
                    view
                )
            );
        } else if (itemId == :settingsMapScaleRestrictedToTileLayers) {
            settings.toggleScaleRestrictedToTileLayers();
            view.rerender();
        } else if (itemId == :settingsMapAttribution) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsMapAttribution(),
                new $.SettingsMapAttributionDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMapUseDrawBitmap) {
            settings.toggleUseDrawBitmap();
            view.rerender();
        } else if (itemId == :settingsMapPackingFormat) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.packingFormatTitle,
                    method(:getPackingFormatStringL),
                    settings.packingFormat,
                    4
                ),
                new $.EnumDelegate(settings.method(:setPackingFormat), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMapStorageSettings) {
            var view = new SettingsMapStorage();
            WatchUi.pushView(view, new $.SettingsMapStorageDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMapTileServerSettings) {
            var view = new SettingsTileServer();
            WatchUi.pushView(view, new $.SettingsTileServerDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getPackingFormatStringL(value as Number) as ResourceId or String {
        return getPackingFormatString(value);
    }
}

(:settingsView)
class SettingsTileServerDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsTileServer;
    function initialize(view as SettingsTileServer) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }

    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getMapChoiceStringL(value as Number) as ResourceId or String {
        return getMapChoiceString(value);
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsMapChoice) {
            WatchUi.pushView(
                new EnumMenu(
                    Rez.Strings.mapChoice,
                    method(:getMapChoiceStringL),
                    settings.mapChoice,
                    33
                ),
                new $.EnumDelegate(settings.method(:setMapChoice), view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsTileUrl) {
            startPicker(new TextEditorPicker(settings.method(:setTileUrl), settings.tileUrl, view));
        } else if (itemId == :settingsAuthToken) {
            startPicker(
                new TextEditorPicker(settings.method(:setAuthToken), settings.authToken, view)
            );
        } else if (itemId == :settingsMapTileSize) {
            startPicker(
                new SettingsNumberPicker(settings.method(:setTileSize), settings.tileSize, view)
            );
        } else if (itemId == :settingsMapFullTileSize) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setFullTileSize),
                    settings.fullTileSize,
                    view
                )
            );
        } else if (itemId == :settingsMapScaledTileSize) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setScaledTileSize),
                    settings.scaledTileSize,
                    view
                )
            );
        } else if (itemId == :settingsMapTileLayerMax) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setTileLayerMax),
                    settings.tileLayerMax,
                    view
                )
            );
        } else if (itemId == :settingsMapTileLayerMin) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setTileLayerMin),
                    settings.tileLayerMin,
                    view
                )
            );
        }
    }
}

(:settingsView)
class SettingsMapStorageDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsMapStorage;
    function initialize(view as SettingsMapStorage) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsMapStorageCacheTilesInStorage) {
            settings.toggleCacheTilesInStorage();
            view.rerender();
        } else if (itemId == :settingsMapStorageStorageMapTilesOnly) {
            settings.toggleStorageMapTilesOnly();
            view.rerender();
        } else if (itemId == :settingsMapStorageStorageSeedBoundingBox) {
            settings.toggleStorageSeedBoundingBox();
            view.rerender();
        } else if (itemId == :settingsMapStorageStorageTileCacheSize) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setStorageTileCacheSize),
                    settings.storageTileCacheSize,
                    view
                )
            );
        } else if (itemId == :settingsMapStorageStorageTileCachePageCount) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setStorageTileCachePageCount),
                    settings.storageTileCachePageCount,
                    view
                )
            );
        } else if (itemId == :settingsMapStorageStorageSeedRouteDistanceM) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setStorageSeedRouteDistanceM),
                    settings.storageSeedRouteDistanceM,
                    view
                )
            );
        } else if (itemId == :settingsMapStorageCacheCurrentArea) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.startTileCache1) as String
            );
            WatchUi.pushView(dialog, new StartCachedTilesDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMapStorageCancelCacheDownload) {
            getApp()._breadcrumbContext.cachedValues.cancelCacheCurrentMapArea();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsMapStorageClearCachedTiles) {
            var dialog = new WatchUi.Confirmation(
                WatchUi.loadResource(Rez.Strings.clearCachedTiles) as String
            );
            WatchUi.pushView(dialog, new ClearCachedTilesDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

(:settingsView)
class SettingsMapDisabledDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsMapDisabled;
    function initialize(view as SettingsMapDisabled) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsMapEnabled) {
            settings.setMapEnabled(true);
            var view = new SettingsMap();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.pushView(view, new $.SettingsMapDelegate(view), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

(:settingsView)
function checkAlertViewDisplay(
    oldView as SettingsAlerts or SettingsAlertsDisabled,
    settings as Settings
) as Void {
    if (
        oldView instanceof SettingsAlerts &&
        !settings.offTrackWrongDirection &&
        !settings.enableOffTrackAlerts
    ) {
        var view = new SettingsAlertsDisabled();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(view, new $.SettingsAlertsDisabledDelegate(view), WatchUi.SLIDE_IMMEDIATE);
    } else if (
        oldView instanceof SettingsAlertsDisabled &&
        (settings.offTrackWrongDirection || settings.enableOffTrackAlerts)
    ) {
        var view = new SettingsAlerts();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.pushView(view, new $.SettingsAlertsDelegate(view), WatchUi.SLIDE_IMMEDIATE);
    } else {
        oldView.rerender();
    }
}

(:settingsView)
function onSelectAlertCommon(
    itemId as Object?,
    settings as Settings,
    view as SettingsAlerts or SettingsAlertsDisabled
) as Void {
    if (itemId == :settingsAlertsDrawLineToClosestPoint) {
        settings.toggleDrawLineToClosestPoint();
        view.rerender();
    } else if (itemId == :settingsAlertsEnabled) {
        settings.toggleEnableOffTrackAlerts();
        checkAlertViewDisplay(view, settings);
    } else if (itemId == :settingsAlertsOffTrackWrongDirection) {
        settings.toggleOffTrackWrongDirection();
        checkAlertViewDisplay(view, settings);
    } else if (itemId == :settingsAlertsDrawCheverons) {
        settings.toggleDrawCheverons();
        view.rerender();
    } else if (itemId == :settingsAlertsOffTrackDistanceM) {
        startPicker(
            new SettingsNumberPicker(
                settings.method(:setOffTrackAlertsDistanceM),
                settings.offTrackAlertsDistanceM,
                view
            )
        );
    } else if (itemId == :settingsAlertsTurnAlertTimeS) {
        startPicker(
            new SettingsNumberPicker(
                settings.method(:setTurnAlertTimeS),
                settings.turnAlertTimeS,
                view
            )
        );
    } else if (itemId == :settingsAlertsMinTurnAlertDistanceM) {
        startPicker(
            new SettingsNumberPicker(
                settings.method(:setMinTurnAlertDistanceM),
                settings.minTurnAlertDistanceM,
                view
            )
        );
    } else if (itemId == :settingsAlertsOffTrackCheckIntervalS) {
        startPicker(
            new SettingsNumberPicker(
                settings.method(:setOffTrackCheckIntervalS),
                settings.offTrackCheckIntervalS,
                view
            )
        );
    } else if (itemId == :settingsAlertsAlertType) {
        WatchUi.pushView(
            new EnumMenu(
                Rez.Strings.alertTypeTitle,
                (new GetAlertTypeStringLProxy()).method(:getAlertTypeStringL),
                settings.alertType,
                ALERT_TYPE_MAX
            ),
            new $.EnumDelegate(settings.method(:setAlertType), view),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class GetAlertTypeStringLProxy {
    // compiler complains it cannot find the global ones
    // even $.method(:...) does not seem to work
    public function getAlertTypeStringL(value as Number) as ResourceId or String {
        return getAlertTypeString(value);
    }
}

(:settingsView)
class SettingsAlertsDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsAlerts;
    function initialize(view as SettingsAlerts) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();

        if (itemId == :settingsAlertsOffTrackAlertsMaxReportIntervalS) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setOffTrackAlertsMaxReportIntervalS),
                    settings.offTrackAlertsMaxReportIntervalS,
                    view
                )
            );
            return;
        }

        onSelectAlertCommon(itemId, settings, view);
    }
}

(:settingsView)
class SettingsAlertsDisabledDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsAlertsDisabled;
    function initialize(view as SettingsAlertsDisabled) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        onSelectAlertCommon(itemId, settings, view);
    }
}

(:settingsView)
class DummyView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }
}

(:settingsView)
class ClearRoutesDelegate extends WatchUi.ConfirmationDelegate {
    var settings as Settings;
    function initialize() {
        WatchUi.ConfirmationDelegate.initialize();
        self.settings = getApp()._breadcrumbContext.settings;
    }
    function onResponse(response as Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            getApp()._breadcrumbContext.clearRoutes();

            // WARNING: this is a massive hack, probably dependant on platform
            // just poping the vew and replacing does not work, because the confirmation is still active whilst we are in this function
            // so we need to pop the confirmation too
            // but the confirmation is also about to call WatchUi.popView()
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop confirmation
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); // pop routes view
            var view = new $.SettingsRoutes(settings);
            WatchUi.pushView(
                view,
                new $.SettingsRoutesDelegate(view, settings),
                WatchUi.SLIDE_IMMEDIATE
            ); // replace with new updated routes view
            WatchUi.pushView(new DummyView(), null, WatchUi.SLIDE_IMMEDIATE); // push dummy view for the confirmation to pop
        }

        return true; // we always handle it
    }
}

(:settingsView)
class SettingsColoursDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsColours;
    function initialize(view as SettingsColours) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsColoursTrackColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setTrackColour),
                    settings.trackColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsColoursTrackColour2) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setTrackColour2),
                    settings.trackColour2,
                    view,
                    true
                )
            );
        } else if (itemId == :settingsColoursDefaultRouteColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setDefaultRouteColour),
                    settings.defaultRouteColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsColoursElevationColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setElevationColour),
                    settings.elevationColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsColoursUserColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setUserColour),
                    settings.userColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsColoursNormalModeColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setNormalModeColour),
                    settings.normalModeColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsColoursUiColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setUiColour),
                    settings.uiColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsColoursDebugColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setDebugColour),
                    settings.debugColour,
                    view,
                    false
                )
            );
        }
    }
}

(:settingsView)
class SettingsDebugDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsDebug;
    function initialize(view as SettingsDebug) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsDebugTileErrorColour) {
            startPicker(
                new SettingsColourPickerTransparency(
                    settings.method(:setTileErrorColour),
                    settings.tileErrorColour,
                    view,
                    false
                )
            );
        } else if (itemId == :settingsDebugDrawLineToClosestTrack) {
            settings.toggleDrawLineToClosestTrack();
            view.rerender();
        } else if (itemId == :settingsDebugShowTileBorders) {
            settings.toggleShowTileBorders();
            view.rerender();
        } else if (itemId == :settingsDebugShowErrorTileMessages) {
            settings.toggleShowErrorTileMessages();
            view.rerender();
        } else if (itemId == :settingsDebugDrawHitBoxes) {
            settings.toggleDrawHitBoxes();
            view.rerender();
        } else if (itemId == :settingsDebugShowDirectionPoints) {
            settings.toggleShowDirectionPoints();
            view.rerender();
        } else if (itemId == :settingsDebugShowDirectionPointTextUnderIndex) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setShowDirectionPointTextUnderIndex),
                    settings.showDirectionPointTextUnderIndex,
                    view
                )
            );
        }
    }
}

(:settingsView)
function getFontSizeString(font as Number) as ResourceId or String {
    switch (font) {
        case Graphics.FONT_XTINY:
            return Rez.Strings.fontXTiny;
        case Graphics.FONT_TINY:
            return Rez.Strings.fontTiny;
        case Graphics.FONT_SMALL:
            return Rez.Strings.fontSmall;
        case Graphics.FONT_MEDIUM:
            return Rez.Strings.fontMedium;
        case Graphics.FONT_LARGE:
            return Rez.Strings.fontLarge;
        // numbers cannot be used because we add letters too, and the numbers fonts only renders numbers
        // case Graphics.FONT_NUMBER_MILD: return Rez.Strings.fontNumMild;
        // case Graphics.FONT_NUMBER_MEDIUM: return Rez.Strings.fontNumMedium;
        // case Graphics.FONT_NUMBER_HOT: return Rez.Strings.fontNumHot;
        // case Graphics.FONT_NUMBER_THAI_HOT: return Rez.Strings.fontNumThaiHot;
        // <!-- System Fonts seem to be almost the same, so save the space for the strings and code-->
        // case Graphics.FONT_SYSTEM_XTINY: return Rez.Strings.fontSysXTiny;
        // case Graphics.FONT_SYSTEM_TINY: return Rez.Strings.fontSysTiny;
        // case Graphics.FONT_SYSTEM_SMALL: return Rez.Strings.fontSysSmall;
        // case Graphics.FONT_SYSTEM_MEDIUM: return Rez.Strings.fontSysMedium;
        // case Graphics.FONT_SYSTEM_LARGE: return Rez.Strings.fontSysLarge;
        default:
            return "";
    }
}

(:settingsView)
function getTrackStyleString(style as Number) as ResourceId {
    switch (style) {
        case TRACK_STYLE_LINE:
            return Rez.Strings.trackStyleLine;
        case TRACK_STYLE_DASHED:
            return Rez.Strings.trackStyleDashed;
        case TRACK_STYLE_POINTS:
            return Rez.Strings.trackStylePoints;
        case TRACK_STYLE_POINTS_INTERPOLATED:
            return Rez.Strings.trackStylePointsInterp;
        case TRACK_STYLE_BOXES:
            return Rez.Strings.trackStyleBoxes;
        case TRACK_STYLE_BOXES_INTERPOLATED:
            return Rez.Strings.trackStyleBoxesInterp;
        case TRACK_STYLE_FILLED_SQUARE:
            return Rez.Strings.trackStyleFilledSquare;
        case TRACK_STYLE_FILLED_SQUARE_INTERPOLATED:
            return Rez.Strings.trackStyleFilledSquareInterp;
        case TRACK_STYLE_POINTS_OUTLINE:
            return Rez.Strings.trackStylePointsOutline;
        case TRACK_STYLE_POINTS_OUTLINE_INTERPOLATED:
            return Rez.Strings.trackStylePointsOutlineInterp;
        // --- Texture Styles ---
        case TRACK_STYLE_CHECKERBOARD:
            return Rez.Strings.trackStyleChecker;
        case TRACK_STYLE_HAZARD:
            return Rez.Strings.trackStyleHazard;
        case TRACK_STYLE_DOT_MATRIX:
            return Rez.Strings.trackStyleMatrix;
        case TRACK_STYLE_POLKA_DOT:
            return Rez.Strings.trackStylePolka;
        case TRACK_STYLE_DIAMOND:
            return Rez.Strings.trackStyleDiamond;
        default:
            return Rez.Strings.trackStyleLine;
    }
}

class EnumMenu extends WatchUi.Menu2 {
    function initialize(
        title as String or ResourceId,
        callback as (Method(value as Number) as ResourceId or String),
        current as Number,
        max as Number
    ) {
        Menu2.initialize({ :title => title });
        for (var i = 0; i < max; i++) {
            var label = callback.invoke(i);
            if (label.equals("")) {
                continue;
            }
            var isSelected = i == current;
            addItem(new MenuItem(label, isSelected ? "Selected" : "", i, {}));
        }
    }
}

(:settingsView)
class EnumDelegate extends WatchUi.Menu2InputDelegate {
    private var callback as (Method(value as Number) as Void);
    private var parent as Renderable;

    function initialize(callback as (Method(value as Number) as Void), parent as Renderable) {
        Menu2InputDelegate.initialize();
        self.callback = callback;
        self.parent = parent;
    }

    function onSelect(item as MenuItem) as Void {
        callback.invoke(item.getId() as Number);
        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
