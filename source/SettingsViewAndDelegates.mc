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
class SettingsStringPicker extends MyTextPickerDelegate {
    private var callback as (Method(value as String) as Void);
    public var parent as Renderable;
    function initialize(
        callback as (Method(value as String) as Void),
        parent as Renderable,
        picker as TextPickerView
    ) {
        MyTextPickerDelegate.initialize(me.method(:onTextEntered), picker);
        self.callback = callback;
        self.parent = parent;
    }

    function onTextEntered(text as Lang.String) as Lang.Boolean {
        logT("onTextEntered: " + text);

        callback.invoke(text);
        parent.rerender();

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onCancel() as Boolean {
        logT("canceled");
        return true;
    }
}

(:settingsView)
function startPicker(
    picker as SettingsFloatPicker or SettingsColourPicker or SettingsNumberPicker
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
class SettingsMain extends Rez.Menus.SettingsMain {
    function initialize() {
        Rez.Menus.SettingsMain.initialize();
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var modeString = "";
        switch (settings.mode) {
            case MODE_NORMAL:
                modeString = Rez.Strings.trackRouteMode;
                break;
            case MODE_ELEVATION:
                modeString = Rez.Strings.elevationMode;
                break;
            case MODE_MAP_MOVE:
                modeString = Rez.Strings.mapMove;
                break;
            case MODE_DEBUG:
                modeString = Rez.Strings.debug;
                break;
        }
        safeSetSubLabel(me, :settingsMainMode, modeString);
        var uiModeString = "";
        switch (settings.uiMode) {
            case UI_MODE_SHOW_ALL:
                uiModeString = Rez.Strings.uiModeShowAll;
                break;
            case UI_MODE_HIDDEN:
                uiModeString = Rez.Strings.uiModeHidden;
                break;
            case UI_MODE_NONE:
                uiModeString = Rez.Strings.uiModeNone;
                break;
        }
        safeSetSubLabel(me, :settingsMainModeUiMode, uiModeString);
        var elevationModeString = "";
        switch (settings.elevationMode) {
            case ELEVATION_MODE_STACKED:
                elevationModeString = Rez.Strings.elevationModeStacked;
                break;
            case ELEVATION_MODE_ORDERED_ROUTES:
                elevationModeString = Rez.Strings.elevationModeOrderedRoutes;
                break;
        }
        safeSetSubLabel(me, :settingsMainModeElevationMode, elevationModeString);
        safeSetSubLabel(
            me,
            :settingsMainRecalculateIntervalS,
            settings.recalculateIntervalS.toString()
        );
        var renderModeString = "";
        switch (settings.renderMode) {
            case RENDER_MODE_BUFFERED_ROTATING:
                renderModeString = Rez.Strings.renderModeBufferedRotating;
                break;
            case RENDER_MODE_UNBUFFERED_ROTATING:
                renderModeString = Rez.Strings.renderModeUnbufferedRotating;
                break;
            case RENDER_MODE_BUFFERED_NO_ROTATION:
                renderModeString = Rez.Strings.renderModeBufferedNoRotating;
                break;
            case RENDER_MODE_UNBUFFERED_NO_ROTATION:
                renderModeString = Rez.Strings.renderModeNoBufferedNoRotating;
                break;
        }
        safeSetSubLabel(me, :settingsMainRenderMode, renderModeString);
        safeSetSubLabel(
            me,
            :settingsMainCenterUserOffsetY,
            settings.centerUserOffsetY.format("%.2f")
        );
        safeSetToggle(me, :settingsMainDisplayLatLong, settings.displayLatLong);
        safeSetSubLabel(me, :settingsMainMaxTrackPoints, settings.maxTrackPoints.toString());
        safeSetSubLabel(me, :settingsMainTopDataType, getDataTypeString(settings.topDataType));
        safeSetSubLabel(me, :settingsMainDataFieldTextSize, getFontSizeString(settings.dataFieldTextSize));
        safeSetSubLabel(
            me,
            :settingsMainBottomDataType,
            getDataTypeString(settings.bottomDataType)
        );
        safeSetSubLabel(
            me,
            :settingsMainUseTrackAsHeadingSpeedMPS,
            settings.useTrackAsHeadingSpeedMPS.format("%.2f") + "m/s"
        );
        safeSetSubLabel(
            me,
            :settingsMainMapMoveScreenSize,
            settings.mapMoveScreenSize.format("%.2f")
        );
        safeSetSubLabel(
            me,
            :settingsMainMinTrackPointDistanceM,
            settings.minTrackPointDistanceM.toString()
        );
        var trackPointReductionMethodString = "";
        switch (settings.trackPointReductionMethod) {
            case TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE:
                trackPointReductionMethodString = Rez.Strings.trackPointReductionMethodDownsample;
                break;
            case TRACK_POINT_REDUCTION_METHOD_REUMANN_WITKAM:
                trackPointReductionMethodString = Rez.Strings.trackPointReductionMethodReumannWitkam;
                break;
        }
        safeSetSubLabel(
            me,
            :settingsMainTrackPointReductionMethod,
            trackPointReductionMethodString
        );
    }
}

(:settingsView)
function getDataTypeString(type as Number) as ResourceId {
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
            return Rez.Strings.dataTypeNone;
    }
}

(:settingsView)
class SettingsZoomAtPace extends Rez.Menus.SettingsZoomAtPace {
    function initialize() {
        Rez.Menus.SettingsZoomAtPace.initialize();
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var modeString = "";
        switch (settings.zoomAtPaceMode) {
            case ZOOM_AT_PACE_MODE_PACE:
                modeString = Rez.Strings.zoomAtPaceModePace;
                break;
            case ZOOM_AT_PACE_MODE_STOPPED:
                modeString = Rez.Strings.zoomAtPaceModeStopped;
                break;
            case ZOOM_AT_PACE_MODE_NEVER_ZOOM:
                modeString = Rez.Strings.zoomAtPaceModeNever;
                break;
            case ZOOM_AT_PACE_MODE_ALWAYS_ZOOM:
                modeString = Rez.Strings.zoomAtPaceModeAlways;
                break;
            case ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK:
                modeString = Rez.Strings.zoomAtPaceModeRoutesWithoutTrack;
                break;
        }
        safeSetSubLabel(me, :settingsZoomAtPaceMode, modeString);
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
class SettingsMap extends Rez.Menus.SettingsMap {
    function initialize() {
        Rez.Menus.SettingsMap.initialize();
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
        var packingFormatString = "";
        switch (settings.packingFormat) {
            case 0:
                packingFormatString = Rez.Strings.packingFormatDefault;
                break;
            case 1:
                packingFormatString = Rez.Strings.packingFormatYUV;
                break;
            case 2:
                packingFormatString = Rez.Strings.packingFormatPNG;
                break;
            case 3:
                packingFormatString = Rez.Strings.packingFormatJPG;
                break;
        }
        safeSetSubLabel(me, :settingsMapPackingFormat, packingFormatString);
    }
}

(:settingsView)
class SettingsTileServer extends Rez.Menus.SettingsTileServer {
    function initialize() {
        Rez.Menus.SettingsTileServer.initialize();
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;

        var mapChoiceString = "";
        switch (settings.mapChoice) {
            case 0:
                mapChoiceString = Rez.Strings.custom;
                break;
            case 1:
                mapChoiceString = Rez.Strings.companionApp;
                break;
            case 2:
                mapChoiceString = Rez.Strings.openTopoMap;
                break;
            case 3:
                mapChoiceString = Rez.Strings.esriWorldImagery;
                break;
            case 4:
                mapChoiceString = Rez.Strings.esriWorldStreetMap;
                break;
            case 5:
                mapChoiceString = Rez.Strings.esriWorldTopoMap;
                break;
            case 6:
                mapChoiceString = Rez.Strings.esriWorldTransportation;
                break;
            case 7:
                mapChoiceString = Rez.Strings.esriWorldDarkGrayBase;
                break;
            case 8:
                mapChoiceString = Rez.Strings.esriWorldHillshade;
                break;
            case 9:
                mapChoiceString = Rez.Strings.esriWorldHillshadeDark;
                break;
            case 10:
                mapChoiceString = Rez.Strings.esriWorldLightGrayBase;
                break;
            case 11:
                mapChoiceString = Rez.Strings.esriUSATopoMaps;
                break;
            case 12:
                mapChoiceString = Rez.Strings.esriWorldOceanBase;
                break;
            case 13:
                mapChoiceString = Rez.Strings.esriWorldShadedRelief;
                break;
            case 14:
                mapChoiceString = Rez.Strings.esriNatGeoWorldMap;
                break;
            case 15:
                mapChoiceString = Rez.Strings.esriWorldNavigationCharts;
                break;
            case 16:
                mapChoiceString = Rez.Strings.esriWorldPhysicalMap;
                break;
            case 17:
                mapChoiceString = Rez.Strings.openStreetMapcyclosm;
                break;
            case 18:
                mapChoiceString = Rez.Strings.stadiaAlidadeSmooth;
                break;
            case 19:
                mapChoiceString = Rez.Strings.stadiaAlidadeSmoothDark;
                break;
            case 20:
                mapChoiceString = Rez.Strings.stadiaOutdoors;
                break;
            case 21:
                mapChoiceString = Rez.Strings.stadiaStamenToner;
                break;
            case 22:
                mapChoiceString = Rez.Strings.stadiaStamenTonerLite;
                break;
            case 23:
                mapChoiceString = Rez.Strings.stadiaStamenTerrain;
                break;
            case 24:
                mapChoiceString = Rez.Strings.stadiaStamenWatercolor;
                break;
            case 25:
                mapChoiceString = Rez.Strings.stadiaOSMBright;
                break;
            case 26:
                mapChoiceString = Rez.Strings.cartoVoyager;
                break;
            case 27:
                mapChoiceString = Rez.Strings.cartoDarkMatter;
                break;
            case 28:
                mapChoiceString = Rez.Strings.cartoDarkLightAll;
                break;
            case 29:
                mapChoiceString = Rez.Strings.mapyBasic;
                break;
            case 30:
                mapChoiceString = Rez.Strings.mapyOutdoor;
                break;
            case 31:
                mapChoiceString = Rez.Strings.mapyWinter;
                break;
            case 32:
                mapChoiceString = Rez.Strings.mapyAerial;
                break;
        }
        safeSetSubLabel(me, :settingsMapChoice, mapChoiceString);
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
class SettingsMapStorage extends Rez.Menus.SettingsMapStorage {
    function initialize() {
        Rez.Menus.SettingsMapStorage.initialize();
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

(:settingsView)
class SettingsMapDisabled extends Rez.Menus.SettingsMapDisabled {
    function initialize() {
        Rez.Menus.SettingsMapDisabled.initialize();
        rerender();
    }

    function rerender() as Void {
        safeSetToggle(me, :settingsMapEnabled, false);
    }
}

(:settingsView)
class SettingsAlerts extends Rez.Menus.SettingsAlerts {
    function initialize() {
        Rez.Menus.SettingsAlerts.initialize();
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
    var alertTypeString = "";
    switch (settings.alertType) {
        case ALERT_TYPE_TOAST:
            alertTypeString = Rez.Strings.alertTypeToast;
            break;
        case ALERT_TYPE_ALERT:
            alertTypeString = Rez.Strings.alertTypeAlert;
            break;
        case ALERT_TYPE_IMAGE:
            alertTypeString = Rez.Strings.alertTypeImage;
            break;
    }
    safeSetSubLabel(menu, :settingsAlertsAlertType, alertTypeString);
}

(:settingsView)
class SettingsAlertsDisabled extends Rez.Menus.SettingsAlertsDisabled {
    function initialize() {
        Rez.Menus.SettingsAlertsDisabled.initialize();
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        alertsCommon(me, settings);
    }
}

(:settingsView)
class SettingsColours extends Rez.Menus.SettingsColours {
    function initialize() {
        Rez.Menus.SettingsColours.initialize();
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetIcon(me, :settingsColoursTrackColour, new ColourIcon(settings.trackColour));
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
class SettingsDebug extends Rez.Menus.SettingsDebug {
    function initialize() {
        Rez.Menus.SettingsDebug.initialize();
        rerender();
    }

    function rerender() as Void {
        var settings = getApp()._breadcrumbContext.settings;
        safeSetIcon(me, :settingsDebugTileErrorColour, new ColourIcon(settings.tileErrorColour));
        safeSetToggle(me, :settingsDebugShowPoints, settings.showPoints);
        safeSetToggle(me, :settingsDebugDrawLineToClosestTrack, settings.drawLineToClosestTrack);
        safeSetToggle(me, :settingsDebugShowTileBorders, settings.showTileBorders);
        safeSetToggle(me, :settingsDebugShowErrorTileMessages, settings.showErrorTileMessages);
        safeSetToggle(
            me,
            :settingsDebugIncludeDebugPageInOnScreenUi,
            settings.includeDebugPageInOnScreenUi
        );
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
class SettingsRoute extends Rez.Menus.SettingsRoute {
    var settings as Settings;
    var routeId as Number;
    var parent as SettingsRoutes;
    function initialize(settings as Settings, routeId as Number, parent as SettingsRoutes) {
        Rez.Menus.SettingsRoute.initialize();
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

    function setColour(value as Number) as Void {
        settings.setRouteColour(routeId, value);
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

        for (var i = 0; i < settings.routeMax(); ++i) {
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
        if (itemId == :settingsMainMode) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsMode(),
                new $.SettingsModeDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainModeUiMode) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsUiMode(),
                new $.SettingsUiModeDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainModeElevationMode) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsElevationMode(),
                new $.SettingsElevationModeDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainRecalculateIntervalS) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setRecalculateIntervalS),
                    settings.recalculateIntervalS,
                    view
                )
            );
        } else if (itemId == :settingsMainRenderMode) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsRenderMode(),
                new $.SettingsRenderModeDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainCenterUserOffsetY) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setCenterUserOffsetY),
                    settings.centerUserOffsetY,
                    view
                )
            );
        } else if (itemId == :settingsMainDisplayLatLong) {
            settings.toggleDisplayLatLong();
            view.rerender();
        } else if (itemId == :settingsMainMaxTrackPoints) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setMaxTrackPoints),
                    settings.maxTrackPoints,
                    view
                )
            );
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
        } else if (itemId == :settingsMainTopDataType) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsDataFieldType(),
                new $.SettingsDataFieldTypeDelegate(view, settings.method(:setTopDataType)),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainBottomDataType) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsDataFieldType(),
                new $.SettingsDataFieldTypeDelegate(view, settings.method(:setBottomDataType)),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainDataFieldTextSize) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsFontSize(),
                new $.SettingsFontSizeDelegate(view, settings.method(:setDataFieldTextSize)),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsMainMinTrackPointDistanceM) {
            startPicker(
                new SettingsNumberPicker(
                    settings.method(:setMinTrackPointDistanceM),
                    settings.minTrackPointDistanceM,
                    view
                )
            );
        }else if (itemId == :settingsMainTrackPointReductionMethod) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsTrackPointReductionMethod(),
                new $.SettingsTrackPointReductionMethodDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        }else if (itemId == :settingsMainUseTrackAsHeadingSpeedMPS) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setUseTrackAsHeadingSpeedMPS),
                    settings.useTrackAsHeadingSpeedMPS,
                    view
                )
            );
        } else if (itemId == :settingsMainMapMoveScreenSize) {
            startPicker(
                new SettingsFloatPicker(
                    settings.method(:setMapMoveScreenSize),
                    settings.mapMoveScreenSize,
                    view
                )
            );
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

(:settingsView)
class SettingsModeDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsMain;
    function initialize(parent as SettingsMain) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsModeTrackRoute) {
            settings.setMode(MODE_NORMAL);
        } else if (itemId == :settingsModeElevation) {
            settings.setMode(MODE_ELEVATION);
        } else if (itemId == :settingsModeMapMove) {
            settings.setMode(MODE_MAP_MOVE);
        } else if (itemId == :settingsModeMapDebug) {
            settings.setMode(MODE_DEBUG);
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsMapChoiceDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsTileServer;
    function initialize(parent as SettingsTileServer) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId() as Object;
        switch (itemId) {
            case :settingsMapChoiceCustom:
                settings.setMapChoice(0);
                break;
            case :settingsMapChoiceCompanionApp:
                settings.setMapChoice(1);
                break;
            case :settingsMapChoiceOpenTopoMap:
                settings.setMapChoice(2);
                break;
            case :settingsMapChoiceEsriWorldImagery:
                settings.setMapChoice(3);
                break;
            case :settingsMapChoiceEsriWorldStreetMap:
                settings.setMapChoice(4);
                break;
            case :settingsMapChoiceEsriWorldTopoMap:
                settings.setMapChoice(5);
                break;
            case :settingsMapChoiceEsriWorldTransportation:
                settings.setMapChoice(6);
                break;
            case :settingsMapChoiceEsriWorldDarkGrayBase:
                settings.setMapChoice(7);
                break;
            case :settingsMapChoiceEsriWorldHillshade:
                settings.setMapChoice(8);
                break;
            case :settingsMapChoiceEsriWorldHillshadeDark:
                settings.setMapChoice(9);
                break;
            case :settingsMapChoiceEsriWorldLightGrayBase:
                settings.setMapChoice(10);
                break;
            case :settingsMapChoiceEsriUSATopoMaps:
                settings.setMapChoice(11);
                break;
            case :settingsMapChoiceEsriWorldOceanBase:
                settings.setMapChoice(12);
                break;
            case :settingsMapChoiceEsriWorldShadedRelief:
                settings.setMapChoice(13);
                break;
            case :settingsMapChoiceEsriNatGeoWorldMap:
                settings.setMapChoice(14);
                break;
            case :settingsMapChoiceEsriWorldNavigationCharts:
                settings.setMapChoice(15);
                break;
            case :settingsMapChoiceEsriWorldPhysicalMap:
                settings.setMapChoice(16);
                break;
            case :settingsMapChoiceOpenStreetMapcyclosm:
                settings.setMapChoice(17);
                break;
            case :settingsMapChoiceStadiaAlidadeSmooth:
                settings.setMapChoice(18);
                break;
            case :settingsMapChoiceStadiaAlidadeSmoothDark:
                settings.setMapChoice(19);
                break;
            case :settingsMapChoiceStadiaOutdoors:
                settings.setMapChoice(20);
                break;
            case :settingsMapChoiceStadiaStamenToner:
                settings.setMapChoice(21);
                break;
            case :settingsMapChoiceStadiaStamenTonerLite:
                settings.setMapChoice(22);
                break;
            case :settingsMapChoiceStadiaStamenTerrain:
                settings.setMapChoice(23);
                break;
            case :settingsMapChoiceStadiaStamenWatercolor:
                settings.setMapChoice(24);
                break;
            case :settingsMapChoiceStadiaOSMBright:
                settings.setMapChoice(25);
                break;
            case :settingsMapChoiceCartoVoyager:
                settings.setMapChoice(26);
                break;
            case :settingsMapChoiceCartoDarkMatter:
                settings.setMapChoice(27);
                break;
            case :settingsMapChoiceCartoDarkLightAll:
                settings.setMapChoice(28);
                break;
            case :settingsMapChoiceMapyBasic:
                settings.setMapChoice(29);
                break;
            case :settingsMapChoiceMapyOutdoor:
                settings.setMapChoice(30);
                break;
            case :settingsMapChoiceMapyWinter:
                settings.setMapChoice(31);
                break;
            case :settingsMapChoiceMapyAerial:
                settings.setMapChoice(32);
                break;
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsPackingFormatDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsMap;
    function initialize(parent as SettingsMap) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId() as Object;
        switch (itemId) {
            case :settingsPackingFormatDefault:
                settings.setPackingFormat(0);
                break;
            case :settingsPackingFormatYUV:
                settings.setPackingFormat(1);
                break;
            case :settingsPackingFormatPNG:
                settings.setPackingFormat(2);
                break;
            case :settingsPackingFormatJPG:
                settings.setPackingFormat(3);
                break;
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
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
class SettingsUiModeDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsMain;
    function initialize(parent as SettingsMain) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsUiModeShowall) {
            settings.setUiMode(UI_MODE_SHOW_ALL);
        } else if (itemId == :settingsUiModeHidden) {
            settings.setUiMode(UI_MODE_HIDDEN);
        } else if (itemId == :settingsUiModeNone) {
            settings.setUiMode(UI_MODE_NONE);
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsElevationModeDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsMain;
    function initialize(parent as SettingsMain) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsElevationModeStacked) {
            settings.setElevationMode(ELEVATION_MODE_STACKED);
        } else if (itemId == :settingsElevationModeOrderedRoutes) {
            settings.setElevationMode(ELEVATION_MODE_ORDERED_ROUTES);
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsAlertTypeDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsAlerts or SettingsAlertsDisabled;
    function initialize(parent as SettingsAlerts or SettingsAlertsDisabled) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsAlertTypeToast) {
            settings.setAlertType(ALERT_TYPE_TOAST);
        } else if (itemId == :settingsAlertTypeAlert) {
            settings.setAlertType(ALERT_TYPE_ALERT);
        } else if (itemId == :settingsAlertTypeImage) {
            settings.setAlertType(ALERT_TYPE_IMAGE);
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsRenderModeDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsMain;
    function initialize(parent as SettingsMain) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsRenderModeBufferedRotating) {
            settings.setRenderMode(RENDER_MODE_BUFFERED_ROTATING);
        } else if (itemId == :settingsRenderModeUnbufferedRotating) {
            settings.setRenderMode(RENDER_MODE_UNBUFFERED_ROTATING);
        } else if (itemId == :settingsRenderModeBufferedNoRotating) {
            settings.setRenderMode(RENDER_MODE_BUFFERED_NO_ROTATION);
        } else if (itemId == :settingsRenderModeNoBufferedNoRotating) {
            settings.setRenderMode(RENDER_MODE_UNBUFFERED_NO_ROTATION);
        }

        parent.rerender();
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
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsZoomAtPaceMode) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsZoomAtPaceMode(),
                new $.SettingsZoomAtPaceModeDelegate(view),
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
            var pickerView = new TextPickerView(
                "Route Name",
                "",
                0,
                256,
                settings.routeName(view.routeId)
            );
            var picker = new SettingsStringPicker(view.method(:setName), view, pickerView);
            WatchUi.pushView(pickerView, picker, WatchUi.SLIDE_IMMEDIATE);
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
                new SettingsColourPicker(view.method(:setColour), view.routeColour(), view)
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
        }
    }
}

(:settingsView)
class SettingsZoomAtPaceModeDelegate extends WatchUi.Menu2InputDelegate {
    var parent as SettingsZoomAtPace;
    function initialize(parent as SettingsZoomAtPace) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsZoomAtPaceModePace) {
            settings.setZoomAtPaceMode(ZOOM_AT_PACE_MODE_PACE);
        } else if (itemId == :settingsZoomAtPaceModeStopped) {
            settings.setZoomAtPaceMode(ZOOM_AT_PACE_MODE_STOPPED);
        } else if (itemId == :settingsZoomAtPaceModeNever) {
            settings.setZoomAtPaceMode(ZOOM_AT_PACE_MODE_NEVER_ZOOM);
        } else if (itemId == :settingsZoomAtPaceModeAlways) {
            settings.setZoomAtPaceMode(ZOOM_AT_PACE_MODE_ALWAYS_ZOOM);
        } else if (itemId == :settingsZoomAtPaceModeRoutesWithoutTrack) {
            settings.setZoomAtPaceMode(ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK);
        }

        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
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
                new $.Rez.Menus.SettingsPackingFormat(),
                new $.SettingsPackingFormatDelegate(view),
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
}

(:settingsView)
class SettingsTileServerDelegate extends WatchUi.Menu2InputDelegate {
    var view as SettingsTileServer;
    function initialize(view as SettingsTileServer) {
        WatchUi.Menu2InputDelegate.initialize();
        me.view = view;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var itemId = item.getId();
        if (itemId == :settingsMapChoice) {
            WatchUi.pushView(
                new $.Rez.Menus.SettingsMapChoice(),
                new $.SettingsMapChoiceDelegate(view),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (itemId == :settingsTileUrl) {
            var pickerView = new TextPickerView("Tile Url", "", 0, 256, settings.tileUrl);
            var picker = new SettingsStringPicker(settings.method(:setTileUrl), view, pickerView);
            WatchUi.pushView(pickerView, picker, WatchUi.SLIDE_IMMEDIATE);
        } else if (itemId == :settingsAuthToken) {
            var pickerView = new TextPickerView("Auth Token", "", 0, 256, settings.authToken);
            var picker = new SettingsStringPicker(settings.method(:setAuthToken), view, pickerView);
            WatchUi.pushView(pickerView, picker, WatchUi.SLIDE_IMMEDIATE);
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
            new $.Rez.Menus.SettingsAlertType(),
            new $.SettingsAlertTypeDelegate(view),
            WatchUi.SLIDE_IMMEDIATE
        );
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
                new SettingsColourPicker(
                    settings.method(:setTrackColour),
                    settings.trackColour,
                    view
                )
            );
        } else if (itemId == :settingsColoursDefaultRouteColour) {
            startPicker(
                new SettingsColourPicker(
                    settings.method(:setDefaultRouteColour),
                    settings.defaultRouteColour,
                    view
                )
            );
        } else if (itemId == :settingsColoursElevationColour) {
            startPicker(
                new SettingsColourPicker(
                    settings.method(:setElevationColour),
                    settings.elevationColour,
                    view
                )
            );
        } else if (itemId == :settingsColoursUserColour) {
            startPicker(
                new SettingsColourPicker(settings.method(:setUserColour), settings.userColour, view)
            );
        } else if (itemId == :settingsColoursNormalModeColour) {
            startPicker(
                new SettingsColourPicker(
                    settings.method(:setNormalModeColour),
                    settings.normalModeColour,
                    view
                )
            );
        } else if (itemId == :settingsColoursUiColour) {
            startPicker(
                new SettingsColourPicker(settings.method(:setUiColour), settings.uiColour, view)
            );
        } else if (itemId == :settingsColoursDebugColour) {
            startPicker(
                new SettingsColourPicker(
                    settings.method(:setDebugColour),
                    settings.debugColour,
                    view
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
                new SettingsColourPicker(
                    settings.method(:setTileErrorColour),
                    settings.tileErrorColour,
                    view
                )
            );
        } else if (itemId == :settingsDebugShowPoints) {
            settings.toggleShowPoints();
            view.rerender();
        } else if (itemId == :settingsDebugDrawLineToClosestTrack) {
            settings.toggleDrawLineToClosestTrack();
            view.rerender();
        } else if (itemId == :settingsDebugShowTileBorders) {
            settings.toggleShowTileBorders();
            view.rerender();
        } else if (itemId == :settingsDebugShowErrorTileMessages) {
            settings.toggleShowErrorTileMessages();
            view.rerender();
        } else if (itemId == :settingsDebugIncludeDebugPageInOnScreenUi) {
            settings.toggleIncludeDebugPageInOnScreenUi();
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
class SettingsDataFieldTypeDelegate extends WatchUi.Menu2InputDelegate {
    private var callback as (Method(value as Number) as Void);
    var parent as SettingsMain;
    function initialize(parent as SettingsMain, _callback as (Method(value as Number) as Void)) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
        me.callback = _callback;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var itemId = item.getId();
        if (itemId == :settingsDataTypeNone) {
            callback.invoke(DATA_TYPE_NONE);
        } else if (itemId == :settingsDataTypeScale) {
            callback.invoke(DATA_TYPE_SCALE);
        } else if (itemId == :settingsDataTypeAltitude) {
            callback.invoke(DATA_TYPE_ALTITUDE);
        } else if (itemId == :settingsDataTypeAvgHR) {
            callback.invoke(DATA_TYPE_AVERAGE_HEART_RATE);
        } else if (itemId == :settingsDataTypeAvgSpeed) {
            callback.invoke(DATA_TYPE_AVERAGE_SPEED);
        } else if (itemId == :settingsDataTypeCurHR) {
            callback.invoke(DATA_TYPE_CURRENT_HEART_RATE);
        } else if (itemId == :settingsDataTypeCurSpeed) {
            callback.invoke(DATA_TYPE_CURRENT_SPEED);
        } else if (itemId == :settingsDataTypeDistance) {
            callback.invoke(DATA_TYPE_ELAPSED_DISTANCE);
        } else if (itemId == :settingsDataTypeTime) {
            callback.invoke(DATA_TYPE_ELAPSED_TIME);
        } else if (itemId == :settingsDataTypeAscent) {
            callback.invoke(DATA_TYPE_TOTAL_ASCENT);
        } else if (itemId == :settingsDataTypeDescent) {
            callback.invoke(DATA_TYPE_TOTAL_DESCENT);
        } else if (itemId == :settingsDataTypeAvgPace) {
            callback.invoke(DATA_TYPE_AVERAGE_PACE);
        } else if (itemId == :settingsDataTypeCurPace) {
            callback.invoke(DATA_TYPE_CURRENT_PACE);
        }
        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
function getFontSizeString(font as Number) as ResourceId {
    switch (font) {
        case Graphics.FONT_XTINY: return Rez.Strings.fontXTiny;
        case Graphics.FONT_TINY: return Rez.Strings.fontTiny;
        case Graphics.FONT_SMALL: return Rez.Strings.fontSmall;
        case Graphics.FONT_MEDIUM: return Rez.Strings.fontMedium;
        case Graphics.FONT_LARGE: return Rez.Strings.fontLarge;
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
        default: return Rez.Strings.fontMedium;
    }
}

(:settingsView)
class SettingsFontSizeDelegate extends WatchUi.Menu2InputDelegate {
    private var callback as (Method(value as Number) as Void);
    private var parent as SettingsMain;

    function initialize(parent as SettingsMain, _callback as (Method(value as Number) as Void)) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
        me.callback = _callback;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var itemId = item.getId();

        // Map the symbol ID back to the Graphics Font constant
        var fontValue = Graphics.FONT_MEDIUM; // Default

        if (itemId == :fontXTiny) {
            fontValue = Graphics.FONT_XTINY;
        } else if (itemId == :fontTiny) {
            fontValue = Graphics.FONT_TINY;
        } else if (itemId == :fontSmall) {
            fontValue = Graphics.FONT_SMALL;
        } else if (itemId == :fontMedium) {
            fontValue = Graphics.FONT_MEDIUM;
        } else if (itemId == :fontLarge) {
            fontValue = Graphics.FONT_LARGE;
        }
        /* else if (itemId == :fontNumMild) {
            fontValue = Graphics.FONT_NUMBER_MILD;
        } else if (itemId == :fontNumMedium) {
            fontValue = Graphics.FONT_NUMBER_MEDIUM;
        } else if (itemId == :fontNumHot) {
            fontValue = Graphics.FONT_NUMBER_HOT;
        } else if (itemId == :fontNumThaiHot) {
            fontValue = Graphics.FONT_NUMBER_THAI_HOT;
        } else if (itemId == :fontSysXTiny) {
            fontValue = Graphics.FONT_SYSTEM_XTINY;
        }
         else if (itemId == :fontSysTiny) {
            fontValue = Graphics.FONT_SYSTEM_TINY;
        } else if (itemId == :fontSysSmall) {
            fontValue = Graphics.FONT_SYSTEM_SMALL;
        } else if (itemId == :fontSysMedium) {
            fontValue = Graphics.FONT_SYSTEM_MEDIUM;
        } else if (itemId == :fontSysLarge) {
            fontValue = Graphics.FONT_SYSTEM_LARGE;
        }*/

        callback.invoke(fontValue);
        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
class SettingsTrackPointReductionMethodDelegate extends WatchUi.Menu2InputDelegate {
    private var parent as SettingsMain;

    function initialize(parent as SettingsMain) {
        WatchUi.Menu2InputDelegate.initialize();
        me.parent = parent;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var itemId = item.getId();

        var settings = getApp()._breadcrumbContext.settings;
        var value = TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE;

        if (itemId == :trackPointReductionMethodDownsample) {
            value = TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE;
        } else if (itemId == :trackPointReductionMethodReumannWitkam) {
            value = TRACK_POINT_REDUCTION_METHOD_REUMANN_WITKAM;
        } 

        settings.setTrackPointReductionMethod(value);
        parent.rerender();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
