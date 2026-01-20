import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Attention;
import Toybox.System;

typedef Alert as interface {
    function text() as String;
    function onUpdate(dc as Dc) as Void;
    function alert() as WatchUi.DataFieldAlert;
};

class OffTrackAlert extends WatchUi.DataFieldAlert {
    function initialize() {
        WatchUi.DataFieldAlert.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        var halfWidth = dc.getWidth() * 0.5;
        var offTrackIcon =
            WatchUi.loadResource(Rez.Drawables.OffTrackIcon) as WatchUi.BitmapResource;
        dc.drawBitmap(0, 0, offTrackIcon);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            halfWidth,
            40,
            Graphics.FONT_SYSTEM_MEDIUM,
            text(),
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function text() as String {
        return "OFF TRACK";
    }

    function alert() as WatchUi.DataFieldAlert {
        return me;
    }
}

class WrongDirectionAlert extends WatchUi.DataFieldAlert {
    function initialize() {
        WatchUi.DataFieldAlert.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        // todo maybe save this as a bitmap to save space? are bitmaps more code-space efficient than the dc calls?

        // --- 1. Setup Drawing Variables ---
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        // Define the dimensions of the sign. Make it large and prominent.
        var rectWidth = dc.getWidth() * 0.75;
        var rectHeight = dc.getHeight() / 2;
        var rectX = centerX - rectWidth / 2;
        var rectY = centerY - rectHeight / 2;
        var radius = 10;

        // --- 2. Draw the Red Background Rectangle ---
        // Set the color to a vibrant red for immediate attention.
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(rectX, rectY, rectWidth, rectHeight, radius);

        // --- 3. Draw the "WRONG WAY" Text ---
        // Set the color to white for high contrast against the red background.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // white outline
        dc.setPenWidth(4);
        dc.drawRoundedRectangle(rectX, rectY, rectWidth, rectHeight, radius);

        // To ensure the text fits well on a watch screen, we'll split it into two lines.
        var text = "WRONG\nWAY";

        // Draw the text centered both horizontally and vertically within the alert space.
        dc.drawText(
            centerX,
            centerY,
            Graphics.FONT_SYSTEM_LARGE, // Use a large font for readability
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER // Center align text
        );
    }

    function text() as String {
        return "WRONG DIRECTION";
    }

    function alert() as WatchUi.DataFieldAlert {
        return me;
    }
}

class DirectionAlert extends WatchUi.DataFieldAlert {
    var direction as Number; // -180 to +180 deg
    var distanceM as Float;
    var distanceImperialUnits as Boolean;

    function initialize(direction as Number, distanceM as Float, distanceImperialUnits as Boolean) {
        WatchUi.DataFieldAlert.initialize();
        self.direction = direction;
        self.distanceM = distanceM;
        self.distanceImperialUnits = distanceImperialUnits;
    }

    // Overrides the onUpdate function to draw a graphical turn indicator
    function onUpdate(dc as Dc) as Void {
        // This is very pretty, but runs out of memory when trying to create it on the sim :(
        // However on a real physical device it seems to work fine (though maybe thats where my random crashes are coming from)

        // --- 1. Setup Drawing Variables ---
        // Get the center of the screen
        var arrowVOffset = 30;
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2 - arrowVOffset;

        // Define the length of the lines for the turn indicator
        var lineLength = (dc.getHeight() * 0.75) / 2;

        // Set the color for the drawing
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        // Set the line width to make it more visible
        dc.setPenWidth(12);

        // --- 2. Draw the "Current Path" Line ---
        // This is a straight vertical line leading to the turn point (the center)
        dc.drawLine(centerX, centerY + lineLength, centerX, centerY);

        // --- 3. Calculate and Draw the "Turn" Line ---
        // Convert the incoming direction from degrees to radians for the math functions
        var angleRad = Math.toRadians(self.direction);

        // Calculate the end point of the turn line using sine and cosine.
        // We subtract from 'y' because in many screen coordinate systems,
        // the 'y' value increases as you go down the screen.
        var endX = centerX + lineLength * Math.sin(angleRad);
        var endY = centerY - lineLength * Math.cos(angleRad);

        dc.drawLine(centerX, centerY, endX, endY);

        // --- 4. Draw an Arrowhead on the Turn Line ---
        // This makes the direction of the turn clearer
        var arrowLength = 50; // Length of the arrowhead barbs
        var arrowAngle = Math.toRadians(40); // Angle of the barbs relative to the line

        // Calculate the coordinates for the two barbs of the arrowhead
        var arrowX1 = endX - arrowLength * Math.sin(angleRad - arrowAngle);
        var arrowY1 = endY + arrowLength * Math.cos(angleRad - arrowAngle);
        var arrowX2 = endX - arrowLength * Math.sin(angleRad + arrowAngle);
        var arrowY2 = endY + arrowLength * Math.cos(angleRad + arrowAngle);

        // Draw the two arrowhead lines
        dc.drawLine(endX, endY, arrowX1, arrowY1);
        dc.drawLine(endX, endY, arrowX2, arrowY2);

        // --- 5. Display the Distance Text ---
        // Keep the distance text, as it's still very useful information.
        // We'll place it neatly below the line drawing.
        var text = "";
        if (distanceImperialUnits) {
            var distanceFt = distanceM * 3.28084;
            text = distanceFt.format("%.0f") + "ft";
        } else {
            text = distanceM.format("%.0f") + "m";
        }

        dc.drawText(
            centerX,
            centerY + lineLength + 10, // Position text below the drawing
            Graphics.FONT_SYSTEM_MEDIUM,
            text,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function text() as String {
        var dirText = direction >= 0 ? "Right" : "Left";
        var distanceText = "";

        if (distanceImperialUnits) {
            var distanceFt = distanceM * 3.28084;
            distanceText = distanceFt.format("%.0f") + "ft";
        } else {
            distanceText = distanceM.format("%.0f") + "m";
        }

        return dirText + " Turn In " + distanceText + " " + absN(direction) + "°";
    }

    function alert() as WatchUi.DataFieldAlert {
        return me;
    }
}

// note to get this to work on the simulator need to modify simulator.json and
// add isTouchable this is already on edge devices with touch, but not the
// venu2s, even though I tested and it worked on the actual device
// AppData\Roaming\Garmin\ConnectIQ\Devices\venu2s\simulator.json
// "datafields": {
// 				"isTouchable": true,
//                 "datafields": [
// note: this only allows taps, cannot handle swipes/holds etc. (need to test on
// real device)
class BreadcrumbDataFieldView extends WatchUi.DataField {
    var offTrackInfo as OffTrackInfo = new OffTrackInfo(true, null, false);
    var _breadcrumbContext as BreadcrumbContext;
    var _scratchPadBitmap as BufferedBitmap?;
    var settings as Settings;
    var _cachedValues as CachedValues;
    var lastOffTrackAlertNotified as Number = 0;
    var lastOffTrackAlertChecked as Number = 0;
    var _computeCounter as Number = 0;
    var _lastFullRenderTime as Number = 0;
    var _lastFullRenderScale as Float = 0f;
    var FULL_RENDER_INTERVAL_S as Number = 5;
    var imageAlert as Alert? = null;
    var imageAlertShowAt as Number = 0;

    // Set the label of the data field here.
    function initialize(breadcrumbContext as BreadcrumbContext) {
        _breadcrumbContext = breadcrumbContext;
        _scratchPadBitmap = null;
        DataField.initialize();
        settings = _breadcrumbContext.settings;
        _cachedValues = _breadcrumbContext.cachedValues;
    }

    function rescale(scaleFactor as Float) as Void {
        var pointWeLeftTrack = offTrackInfo.pointWeLeftTrack;
        if (pointWeLeftTrack != null) {
            pointWeLeftTrack.rescaleInPlace(scaleFactor);
        }
    }

    // see onUpdate explanation for when each is called
    function onLayout(dc as Dc) as Void {
        // logE("width: " + dc.getWidth());
        // logE("height: " + dc.getHeight());
        // logE("screen width: " + System.getDeviceSettings().screenWidth.toFloat());
        // logE("screen height: " + System.getDeviceSettings().screenHeight.toFloat());
        try {
            // call parent so screen can be setup correctly or the screen can be slightly offset left/right/up/down.
            // Usually on a physical devices I see an offset to the right and down (leaving a black bar on the left and top), the venu3s simulator shows this.
            // The venu3 simulator is offset left and down, instead of right and down.
            // Sometimes there is no offset though, very confusing.
            // see code at the top of onUpdate, even just calling clear() with a colour does not remove the black bar offsets.
            View.onLayout(dc);
            actualOnLayout(dc);
        } catch (e) {
            logE("failed onLayout: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        }
    }

    function actualOnLayout(dc as Dc) as Void {
        // logD("onLayout");
        _cachedValues.setScreenSize(dc.getWidth(), dc.getHeight());
        var textDim = dc.getTextDimensions("1234", Graphics.FONT_XTINY);
        _breadcrumbContext.breadcrumbRenderer.setElevationAndUiData(textDim[0] * 1.0f);
        updateScratchPadBitmap();
    }

    function onWorkoutStarted() as Void {
        _breadcrumbContext.track.onStart();
    }

    function onTimerStart() as Void {
        _breadcrumbContext.track.onStartResume();
    }

    function compute(info as Activity.Info) as Void {
        try {
            actualCompute(info);
        } catch (e) {
            logE("failed compute: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        }
    }

    function showMyAlert(alert as Alert) as Void {
        try {
            System.println("" + Time.now().value() + " " + "showing my alert");

            try {
                if (Attention has :backlight) {
                    System.println("" + Time.now().value() + " " + "showing backlight");
                    // turn the screen on so we can see the alert, it does not always respond to us gesturing to see the alert (think gesture controls are suppressed during vibration)
                    // apparently this can throw an exception BacklightOnTooLongException 
                    // even if the backlight is already on this exception seems to be thrown on my venu2s 
                    // and if its off, well it can still throw, not catching this exception meant alerts would not show.
                    // Possibly a new firmware update has changed this behaviour, though i should have been try/catching anyway.
                    // Prefer to turn backlight on first so its ready for our alert.
                    Attention.backlight(true);
                }
            } catch (e) {
                logE("failed to turn on backlight: " + e.getErrorMessage());
                System.println(
                    "" +
                        Time.now().value() +
                        " " +
                        "failed to turn on backlight: " +
                        e.getErrorMessage()
                );
            }
            try {
                if (Attention has :vibrate) {
                    System.println("" + Time.now().value() + " " + "showing vibrate");
                    var vibeData = [
                        new Attention.VibeProfile(100, 500),
                        new Attention.VibeProfile(0, 150),
                        new Attention.VibeProfile(100, 500),
                        new Attention.VibeProfile(0, 150),
                        new Attention.VibeProfile(100, 500),
                    ];
                    // this is not documented that it throws, but got bit by the backlight, so protecting it too in order to always show our alerts
                    Attention.vibrate(vibeData);
                }
            } catch (e) {
                logE("failed to vibrate: " + e.getErrorMessage());
                System.println(
                    "" + Time.now().value() + " " + "failed to vibrate: " + e.getErrorMessage()
                );
            }
            System.println("" + Time.now().value() + " " + "about to show alert");

            // alert comes after we start the vibrate in case it throws
            // logD("trying to trigger alert");
            if (settings.alertType == ALERT_TYPE_ALERT) {
                // alerts are really annoying because users have to remember to enable them
                // and then some times ive noticed that they do not seem to work, or they are disabled and still lock out the screen
                // this is why we default to toasts, the vibration will still occur, and maybe should be a separate setting?
                showAlert(alert.alert());
            } else if (settings.alertType == ALERT_TYPE_IMAGE) {
                imageAlertShowAt = Time.now().value();
                imageAlert = alert;
            } else {
                WatchUi.showToast(alert.text(), {});
            }
        } catch (e) {
            logE("failed to show alert: " + e.getErrorMessage());
            System.println(
                "" + Time.now().value() + " " + "failed to show alert: " + e.getErrorMessage()
            );
        }
    }

    function showMyTrackAlert(epoch as Number, alert as Alert) as Void {
        lastOffTrackAlertNotified = epoch; // if showAlert fails, we will still have vibrated and turned the screen on
        showMyAlert(alert);
    }

    // see onUpdate explanation for when each is called
    function actualCompute(info as Activity.Info) as Void {
        _computeCounter++;

        // logD("compute");
        // temp hack for debugging in simulator (since it seems altitude does not work when playing activity data from gpx file)
        // var route = _breadcrumbContext.routes[0];
        // var nextPoint = route.coordinates.getPoint(_breadcrumbContext.track.coordinates.pointSize());
        // if (nextPoint != null)
        // {
        //     info.altitude = nextPoint.altitude;
        // }

        // make sure tile seed or anything else does not stop our computes completely
        var weReallyNeedACompute = _computeCounter > 3 * settings.recalculateIntervalS;
        if (!weReallyNeedACompute) {
            // store rotations and speed every time
            var rescaleOccurred = _cachedValues.onActivityInfo(info);
            if (rescaleOccurred) {
                // rescaling is an expensive operation, if we have multiple large routes rescale and then try and recalculate off track alerts (or anything else expensive)
                // we could hit watchdog errors. Best to not attempt anything else.
                logD("rescale occurred");
                return;
            }
            // this is here due to stack overflow bug when requests trigger the next request
            // only try 3 times, do not want to schedule heaps if they complete immediately, could hit watchdog
            // this should be minimal work, it only starts the web request, it should never complete straight away with data
            for (var i = 0; i < 3; ++i) {
                if (!_breadcrumbContext.webRequestHandler.startNextIfWeCan()) {
                    break;
                }
            }

            if (_cachedValues.stepCacheCurrentMapArea()) {
                return;
            }

            // perf only seed tiles when we need to (zoom level changes or user moves)
            // could possibly be moved into cached values when map data changes - though map data may not change but we nuked the pending web requests - safer here
            // or we have to do multiple seeds if pending web requests is low
            // needs to be before _computeCounter for when we load tiles from storage (we can only load 1 tile per second)
            if (_breadcrumbContext.mapRenderer.seedTiles()) {
                // we loaded a tile from storage, which could be a significantly costly task,
                // do not trip the watchdog, be safe and return
                // if tile cacheSize is not large enough, this could result in no tracking, since all tiles could potentially be pulled from storage
                // but black squares will appear on the screen, alerting the user that something is wrong
                return;
            }
        }

        // slow down the calls to onActivityInfo as its a heavy operation checking
        // the distance we don't really need data much faster than this anyway
        if (_computeCounter < settings.recalculateIntervalS) {
            return;
        }

        _computeCounter = 0;

        var settings = _breadcrumbContext.settings;
        var disableMapsFailureCount = settings.disableMapsFailureCount;
        if (
            disableMapsFailureCount != 0 &&
            _breadcrumbContext.webRequestHandler._errorCount > disableMapsFailureCount
        ) {
            logE("disabling maps, too many errors");
            settings.setMapEnabled(false);
        }

        var newPoint = _breadcrumbContext.track.pointFromActivityInfo(info);
        if (newPoint != null) {
            if (_cachedValues.currentScale != 0f) {
                newPoint.rescaleInPlace(_cachedValues.currentScale);
            }
            var trackAddRes = _breadcrumbContext.track.onActivityInfo(newPoint);
            var pointAdded = trackAddRes[0];
            var complexOperationHappened = trackAddRes[1];
            if (pointAdded && !complexOperationHappened) {
                // todo: PERF only update this if the new point added changed the bounding box
                // its pretty good atm though, only recalculates once every few seconds, and only
                // if a point is added
                _cachedValues.updateScaleCenterAndMap();
                var epoch = Time.now().value();
                if (epoch - settings.offTrackCheckIntervalS < lastOffTrackAlertChecked) {
                    return;
                }

                // Do not check again for this long, prevents the expensive off track calculation running constantly whilst we are on track.
                lastOffTrackAlertChecked = epoch;

                var lastPoint = _breadcrumbContext.track.lastPoint();
                if (lastPoint != null) {
                    if (
                        settings.enableOffTrackAlerts ||
                        settings.drawLineToClosestPoint ||
                        settings.drawLineToClosestTrack ||
                        settings.offTrackWrongDirection ||
                        settings.drawCheverons
                    ) {
                        handleOffTrackAlerts(epoch, lastPoint);
                    }

                    if (settings.turnAlertTimeS >= 0 || settings.minTurnAlertDistanceM >= 0) {
                        handleDirections(lastPoint);
                    }
                }
            }
        }
    }

    // new point is already pre scaled
    function handleDirections(newPoint as RectangularPoint) as Void {
        for (var i = 0; i < _breadcrumbContext.routes.size(); ++i) {
            var route = _breadcrumbContext.routes[i];
            if (!settings.routeEnabled(route.storageIndex)) {
                continue;
            }
            var res = route.checkDirections(
                newPoint,
                settings.turnAlertTimeS,
                settings.minTurnAlertDistanceM,
                _cachedValues
            );

            if (res != null) {
                showMyAlert(new DirectionAlert(res[0], res[1], settings.distanceImperialUnits));
                return;
            }
        }
    }

    // new point is already pre scaled
    function handleOffTrackAlerts(epoch as Number, newPoint as RectangularPoint) as Void {
        var atLeastOneEnabled = false;
        for (var i = 0; i < _breadcrumbContext.routes.size(); ++i) {
            var route = _breadcrumbContext.routes[i];
            if (!settings.routeEnabled(route.storageIndex)) {
                continue;
            }
            atLeastOneEnabled = true;
            var routeOffTrackInfo = route.checkOffTrack(
                newPoint,
                settings.offTrackAlertsDistanceM * _cachedValues.currentScale
            );

            if (routeOffTrackInfo.onTrack) {
                offTrackInfo = routeOffTrackInfo.clone(); // never store the point we got or rescales could occur twice on the same object
                if (settings.offTrackWrongDirection && offTrackInfo.wrongDirection) {
                    showMyTrackAlert(epoch, new WrongDirectionAlert());
                }

                return;
            }

            var pointWeLeftTrack = offTrackInfo.pointWeLeftTrack;
            var routePointWeLeftTrack = routeOffTrackInfo.pointWeLeftTrack;
            if (
                routePointWeLeftTrack != null &&
                (pointWeLeftTrack == null ||
                    pointWeLeftTrack.distanceTo(newPoint) >
                        routePointWeLeftTrack.distanceTo(newPoint))
            ) {
                offTrackInfo = routeOffTrackInfo.clone(); // never store the point we got or rescales could occur twice on the same object
            }
        }

        if (!atLeastOneEnabled) {
            // no routes are enabled - pretend we are ontrack
            offTrackInfo.onTrack = true;
            return;
        }

        offTrackInfo.onTrack = false; // use the last pointWeLeftTrack from when we were on track

        // do not trigger alerts often
        if (epoch - settings.offTrackAlertsMaxReportIntervalS < lastOffTrackAlertNotified) {
            return;
        }

        if (settings.enableOffTrackAlerts) {
            showMyTrackAlert(epoch, new OffTrackAlert());
        }
    }

    function onSettingsChanged() as Void {
        // they could have turned off off track alerts, changed the distance of anything, so let it all recalculate
        // or modified routes
        lastOffTrackAlertNotified = 0;
        lastOffTrackAlertChecked = 0;
        offTrackInfo = new OffTrackInfo(true, null, false);
        imageAlert = null;
        imageAlertShowAt = 0;
        // render mode could have changed
        updateScratchPadBitmap();
        resetRenderTime();
    }

    function resetRenderTime() as Void {
        _lastFullRenderTime = 0; // map panning needs to redraw map immediately
    }

    function updateScratchPadBitmap() as Void {
        try {
            if (
                settings.renderMode == RENDER_MODE_BUFFERED_ROTATING ||
                settings.renderMode == RENDER_MODE_BUFFERED_NO_ROTATION
            ) {
                // make sure we are at the correct size (settings/layout change at any point)
                // could optimise this to be done in cached values rather than every render
                var width = _cachedValues.maxVirtualScreenDim.toNumber();
                var height = _cachedValues.maxVirtualScreenDim.toNumber();
                if (
                    _scratchPadBitmap == null ||
                    _scratchPadBitmap.getWidth() != width ||
                    _scratchPadBitmap.getHeight() != height
                ) {
                    _scratchPadBitmap = null; // null out the old one first, otherwise we have 2 bit bitmaps allocated at the same time
                    // assuming garbage collection will run immediately, or when trying to allocate the next it will clean up the old one
                    _scratchPadBitmap = newBitmap(width, height);
                }
            } else {
                _scratchPadBitmap = null; // settigns have disabled it - clean up after ourselves on next render
            }
        } catch (e) {
            logE("failed to allocate buffered bitmap: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        }
    }

    // did some testing on real device
    // looks like when we are not on the data page onUpdate is not called, but compute is (as expected)
    // when we are on the data page and it is visible, onUpdate can be called many more times then compute (not just once a second)
    // in some other cases onUpdate is called interleaved with onCompute once a second each (think this might be when its the active screen but not currently renderring)
    // so we need to do all or heavy scaling code in compute, and make onUpdate just handle drawing, and possibly rotation (pre storing rotation could be slow/hard)
    function onUpdate(dc as Dc) as Void {
        // dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        // dc.clear();

        try {
            actualOnUpdate(dc);
        } catch (e) {
            logE("failed onUpdate: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        }

        // template code for 'complex datafield' has this, but I just get a black screen if I do it (think it's only for when using layouts, but im directly drawing to dc)
        // Call parent's onUpdate(dc) to redraw the layout
        // View.onUpdate(dc);
    }

    function actualOnUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var imageAlertLocal = imageAlert;
        if (imageAlertLocal != null) {
            var epoch = Time.now().value();
            if (epoch - imageAlertShowAt > 5 /*seconds*/) {
                imageAlert = null;
            } else {
                imageAlertLocal.onUpdate(dc);
                return;
            }
        }

        // logD("onUpdate");
        var renderer = _breadcrumbContext.breadcrumbRenderer;
        if (renderer.renderTileSeedUi(dc)) {
            return;
        }
        if (renderer.renderClearTrackUi(dc)) {
            return;
        }
        if (renderer.renderMapEnable(dc)) {
            return;
        }
        if (renderer.renderMapDisable(dc)) {
            return;
        }

        // mode should be stored here, but is needed for rendering the ui
        // should structure this way better, but oh well (renderer per mode etc.)
        if (settings.mode == MODE_ELEVATION) {
            renderElevation(dc);
            if (_breadcrumbContext.settings.uiMode == UI_MODE_SHOW_ALL) {
                renderer.renderUi(dc);
            }
            return;
        } else if (settings.mode == MODE_DEBUG) {
            renderDebug(dc);
            if (_breadcrumbContext.settings.uiMode == UI_MODE_SHOW_ALL) {
                renderer.renderUi(dc);
            }
            return;
        }

        if (settings.renderMode == RENDER_MODE_UNBUFFERED_ROTATING) {
            renderUnbufferedRotating(dc);
        } else {
            renderMain(dc);
        }

        var routes = _breadcrumbContext.routes;

        if (settings.displayRouteNames) {
            for (var i = 0; i < routes.size(); ++i) {
                var route = routes[i];
                if (!settings.routeEnabled(route.storageIndex)) {
                    continue;
                }
                var routeColour = settings.routeColour(route.storageIndex);
                if (
                    settings.renderMode == RENDER_MODE_BUFFERED_ROTATING ||
                    settings.renderMode == RENDER_MODE_UNBUFFERED_ROTATING
                ) {
                    renderer.renderTrackName(dc, route, routeColour);
                } else {
                    renderer.renderTrackNameUnrotated(dc, route, routeColour);
                }
            }
        }

        // move based on the last scale we drew
        if (_breadcrumbContext.settings.uiMode == UI_MODE_SHOW_ALL) {
            renderer.renderUi(dc);
        }

        renderer.renderDataFields(dc);

        var lastPoint = _breadcrumbContext.track.lastPoint();
        if (lastPoint != null) {
            renderer.renderUser(dc, lastPoint);
        }

        if (settings.mapEnabled) {
            var attrib = settings.getAttribution();
            if (attrib != null) {
                try {
                    dc.drawBitmap2(
                        _cachedValues.xHalfPhysical - attrib.getWidth() / 2,
                        _cachedValues.physicalScreenHeight - 25,
                        attrib,
                        {
                            :tintColor => settings.uiColour,
                        }
                    );
                } catch (e) {
                    var message = e.getErrorMessage();
                    logE("failed drawBitmap2 (attribution): " + message);
                    ++$.globalExceptionCounter;
                    incNativeColourFormatErrorIfMessageMatches(message);
                }
            }
        }
    }

    function renderMain(dc as Dc) as Void {
        // _renderCounter++;
        // // slow down the calls to onUpdate as its a heavy operation, we will only render every second time (effectively 2 seconds)
        // // this should save some battery, and hopefully the screen stays as the old renderred value
        // // this will mean that we will need to wait this long for the inital render too
        // // perhaps we could base it on speed or 'user is looking at watch'
        // // and have a touch override?
        // if (_renderCounter != 2) {
        //   View.onUpdate(dc);
        //   return;
        // }

        // _renderCounter = 0;
        // looks like view must do a render (not doing a render causes flashes), perhaps we can store our rendered state to a buffer to load from?

        var routes = _breadcrumbContext.routes;
        var track = _breadcrumbContext.track;

        if (
            settings.renderMode == RENDER_MODE_BUFFERED_ROTATING ||
            settings.renderMode == RENDER_MODE_BUFFERED_NO_ROTATION
        ) {
            if (_scratchPadBitmap == null) {
                // we somehow have not allocated it yet, eg. onLayout could be called but throw because the bitmap is not available yet
                // we should probably track this and auto magically switch modes
                updateScratchPadBitmap();
            }
            var scratchPadBitmapLocal = _scratchPadBitmap;
            if (scratchPadBitmapLocal == null) {
                // if its still null, we were unable to create the bitmap in the graphics pool
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
                dc.clear();
                dc.drawText(
                    _cachedValues.xHalfPhysical,
                    _cachedValues.yHalfPhysical,
                    Graphics.FONT_XTINY,
                    "COULD NOT ALLOCATE BUFFER\nSWITCH RENDER MODE",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
                return; // should never happen, but be safe
            }

            // only render once to buffer then back off for a bit
            // need to force rerender on scale change
            var epoch = Time.now().value();
            if (
                epoch - _lastFullRenderTime > settings.recalculateIntervalS ||
                _lastFullRenderScale != _cachedValues.currentScale
            ) {
                // FULL_RENDER_INTERVAL_S is only to take into account user moving (which we are also backing off)
                // if they stop and scale changes we will redraw immediately
                // if they rotate we will draw rotations straight away
                _lastFullRenderTime = epoch;
                _lastFullRenderScale = _cachedValues.currentScale;
                var scratchPadBitmapDc = scratchPadBitmapLocal.getDc();
                rederUnrotated(scratchPadBitmapDc, routes, track);
            }

            try {
                if (settings.renderMode == RENDER_MODE_BUFFERED_ROTATING) {
                    dc.drawBitmap2(0, 0, scratchPadBitmapLocal, {
                        // :bitmapX =>
                        // :bitmapY =>
                        // :bitmapWidth =>
                        // :bitmapHeight =>
                        // :tintColor =>
                        // :filterMode =>
                        :transform => _cachedValues.rotationMatrix,
                    });
                } else {
                    // todo make buffered no rotation mode have a smaller buffer size (we can draw to it the same as dc if its set to the physical screen size)
                    dc.drawBitmap(
                        _cachedValues.bufferedBitmapOffsetX,
                        _cachedValues.bufferedBitmapOffsetY,
                        scratchPadBitmapLocal
                    );
                }
            } catch (e) {
                var message = e.getErrorMessage();
                logE("failed drawBitmap2 (view class): " + message);
                ++$.globalExceptionCounter;
                incNativeColourFormatErrorIfMessageMatches(message);
            }
            return;
        }

        // RENDER_MODE_UNBUFFERED_NO_ROTATION
        rederUnrotated(dc, routes, track);
    }

    (:noUnbufferedRotations)
    function renderUnbufferedRotating(dc as Dc) as Void {}

    (:unbufferedRotations)
    function renderUnbufferedRotating(dc as Dc) as Void {
        var routes = _breadcrumbContext.routes;
        var track = _breadcrumbContext.track;

        var mapRenderer = _breadcrumbContext.mapRenderer;
        var renderer = _breadcrumbContext.breadcrumbRenderer;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        mapRenderer.renderMap(dc);
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (!settings.routeEnabled(route.storageIndex)) {
                continue;
            }
            var routeColour = settings.routeColour(route.storageIndex);
            renderer.renderTrack(dc, route, routeColour, true);
            if (settings.showPoints) {
                renderer.renderTrackPoints(dc, route, Graphics.COLOR_ORANGE);
            }
            if (settings.drawCheverons) {
                renderer.renderTrackCheverons(dc, route, routeColour);
            }
            if (settings.showDirectionPoints || settings.showDirectionPointTextUnderIndex > 0) {
                renderer.renderTrackDirectionPoints(dc, route, Graphics.COLOR_PURPLE);
            }
        }
        renderer.renderTrack(dc, track, settings.trackColour, false);
        if (settings.showPoints) {
            renderer.renderTrackPoints(dc, track, Graphics.COLOR_ORANGE);
        }
        renderOffTrackPoint(dc);
    }

    function rederUnrotated(
        dc as Dc,
        routes as Array<BreadcrumbTrack>,
        track as BreadcrumbTrack
    ) as Void {
        var renderer = _breadcrumbContext.breadcrumbRenderer;
        var mapRenderer = _breadcrumbContext.mapRenderer;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        mapRenderer.renderMapUnrotated(dc);
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (!settings.routeEnabled(route.storageIndex)) {
                continue;
            }
            var routeColour = settings.routeColour(route.storageIndex);
            renderer.renderTrackUnrotated(dc, route, routeColour, true);
            if (settings.showPoints) {
                renderer.renderTrackPointsUnrotated(dc, route, Graphics.COLOR_ORANGE);
            }
            if (settings.drawCheverons) {
                renderer.renderTrackCheveronsUnrotated(dc, route, routeColour);
            }
            if (settings.showDirectionPoints || settings.showDirectionPointTextUnderIndex > 0) {
                renderer.renderTrackDirectionPointsUnrotated(dc, route, Graphics.COLOR_PURPLE);
            }
        }
        renderer.renderTrackUnrotated(dc, track, settings.trackColour, false);
        if (settings.showPoints) {
            renderer.renderTrackPointsUnrotated(dc, track, Graphics.COLOR_ORANGE);
        }

        renderOffTrackPointUnrotated(dc);
    }

    (:noUnbufferedRotations)
    function renderOffTrackPoint(dc as Dc) as Void {}

    (:unbufferedRotations)
    function renderOffTrackPoint(dc as Dc) as Void {
        var lastPoint = _breadcrumbContext.track.lastPoint();
        var renderer = _breadcrumbContext.breadcrumbRenderer;
        var pointWeLeftTrack = offTrackInfo.pointWeLeftTrack;
        if (lastPoint != null) {
            // only ever not null if feature enabled
            if (
                !offTrackInfo.onTrack &&
                pointWeLeftTrack != null &&
                settings.drawLineToClosestPoint
            ) {
                // points need to be scaled and rotated :(
                renderer.renderLineFromLastPointToRoute(
                    dc,
                    lastPoint,
                    pointWeLeftTrack,
                    Graphics.COLOR_RED
                );
            }

            // debug draw line to point
            if (settings.drawLineToClosestTrack) {
                if (offTrackInfo.onTrack && pointWeLeftTrack != null) {
                    // points need to be scaled and rotated :(
                    renderer.renderLineFromLastPointToRoute(
                        dc,
                        lastPoint,
                        pointWeLeftTrack,
                        Graphics.COLOR_PURPLE
                    );
                }
            }
        }
    }

    function renderOffTrackPointUnrotated(dc as Dc) as Void {
        var lastPoint = _breadcrumbContext.track.lastPoint();
        var renderer = _breadcrumbContext.breadcrumbRenderer;
        var pointWeLeftTrack = offTrackInfo.pointWeLeftTrack;
        if (lastPoint != null) {
            // only ever not null if feature enabled

            if (
                !offTrackInfo.onTrack &&
                pointWeLeftTrack != null &&
                settings.drawLineToClosestPoint
            ) {
                // points need to be scaled and rotated :(
                renderer.renderLineFromLastPointToRouteUnrotated(
                    dc,
                    lastPoint,
                    pointWeLeftTrack,
                    Graphics.COLOR_RED
                );
            }

            // debug draw line to point
            if (settings.drawLineToClosestTrack) {
                if (offTrackInfo.onTrack && pointWeLeftTrack != null) {
                    // points need to be scaled and rotated :(
                    renderer.renderLineFromLastPointToRouteUnrotated(
                        dc,
                        lastPoint,
                        pointWeLeftTrack,
                        Graphics.COLOR_PURPLE
                    );
                }
            }
        }
    }

    function renderDebug(dc as Dc) as Void {
        var epoch = Time.now().value();
        dc.setColor(settings.debugColour, Graphics.COLOR_BLACK);
        dc.clear();
        // its only a debug menu that should probably be optimised out in release, hard code to venu2s screen coordinates
        // it is actually pretty nice info, best guess on string sizes down the screen
        var fieldCount = 14;
        var y = 5;
        var bottomSpacing = 5; // physical devices seem to clip the bottom of the datafield
        var spacing = (dc.getHeight() - y - bottomSpacing).toFloat() / fieldCount;
        var x = _cachedValues.xHalfPhysical;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "except: " +
                $.globalExceptionCounter +
                " ncf: " +
                $.sourceMustBeNativeColorFormatCounter,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "pendingWeb: " +
                _breadcrumbContext.webRequestHandler.pending.size() +
                " t: " +
                _breadcrumbContext.webRequestHandler.pendingTransmit.size(),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "outstanding: " +
                _breadcrumbContext.webRequestHandler._outstandingCount +
                " web: " +
                _breadcrumbContext.webRequestHandler.outstandingHashes.size(),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "lastAlert: " +
                (epoch - lastOffTrackAlertNotified) +
                "s check: " +
                (epoch - lastOffTrackAlertChecked) +
                "s",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        var combined = "lastWebRes: " + _breadcrumbContext.webRequestHandler._lastResult;

        if (settings.storageMapTilesOnly) {
            combined = "<storage only>";
        }

        combined +=
            "  tiles: " +
            _breadcrumbContext.tileCache._internalCache.size() +
            " s: " +
            _breadcrumbContext.tileCache._storageTileCache._totalTileCount;

        dc.drawText(x, y, Graphics.FONT_XTINY, combined, Graphics.TEXT_JUSTIFY_CENTER);
        y += spacing;
        var pagesStr = "ps: ";
        for (var i = 0; i < _breadcrumbContext.tileCache._storageTileCache._pageSizes.size(); i++) {
            if (i != 0) {
                pagesStr += ", ";
            }
            pagesStr += _breadcrumbContext.tileCache._storageTileCache._pageSizes[i];
        }
        dc.drawText(x, y, Graphics.FONT_XTINY, pagesStr, Graphics.TEXT_JUSTIFY_CENTER);
        y += spacing;
        var distToLastStr = "NA";
        var lastPoint = _breadcrumbContext.track.lastPoint();
        var pointWeLeftTrack = offTrackInfo.pointWeLeftTrack;
        if (lastPoint != null && pointWeLeftTrack != null) {
            var distMeters = pointWeLeftTrack.distanceTo(lastPoint);
            if (_cachedValues.currentScale != 0f) {
                distMeters = distMeters / _cachedValues.currentScale;
            }

            if (settings.distanceImperialUnits) {
                var distanceFt = distMeters * 3.28084;
                distToLastStr = distanceFt.format("%.0f") + "ft";
            } else {
                distToLastStr = distMeters.format("%.0f") + "m";
            }
        }
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "pts: " +
                _breadcrumbContext.track.coordinates.pointSize() +
                " onTrack: " +
                (offTrackInfo.onTrack ? "Y" : "N") +
                " dist: " +
                distToLastStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        var needsComma = false;
        var directionIndexesStr = "";
        var coordsIndexesStr = "";
        var routesPtsStr = "";
        var dirPtsStr = "";
        for (var i = 0; i < _breadcrumbContext.routes.size(); ++i) {
            var route = _breadcrumbContext.routes[i];
            if (!settings.routeEnabled(route.storageIndex)) {
                continue;
            }

            if (needsComma) {
                directionIndexesStr += ", ";
                coordsIndexesStr += ", ";
                routesPtsStr += ", ";
                dirPtsStr += ", ";
            }

            needsComma = true;
            var dirCoordIndexStr = "na";
            if (
                route.lastDirectionIndex > 0 &&
                route.lastDirectionIndex < route.directions.pointSize()
            ) {
                dirCoordIndexStr =
                    route.directions._internalArrayBuffer[route.lastDirectionIndex] & 0xffff;
            }
            directionIndexesStr += +route.lastDirectionIndex + "(" + dirCoordIndexStr + ")";
            coordsIndexesStr += route.lastClosePointIndex;
            routesPtsStr += route.coordinates.pointSize();
            dirPtsStr += route.directions.pointSize();
        }
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "route pts: " + routesPtsStr + " dir: " + dirPtsStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "ci: " + coordsIndexesStr + " di: " + directionIndexesStr,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "tileLayer: " +
                _cachedValues.tileZ +
                " atMin: " +
                (_cachedValues.atMinTileLayer() ? "Y" : "N") +
                " atMax: " +
                (_cachedValues.atMaxTileLayer() ? "Y" : "N"),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "webErr: " +
                _breadcrumbContext.webRequestHandler._errorCount +
                " webOk: " +
                _breadcrumbContext.webRequestHandler._successCount,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        var hits = _breadcrumbContext.tileCache._hits.toFloat();
        var misses = _breadcrumbContext.tileCache._misses;
        var total = hits + misses;
        var percentage = 0;
        if (total > 0) {
            // do not divide by 0 my good friends
            percentage = (hits * 100) / total;
        }
        var currentSpeedMPS = 0f;
        var info = Activity.getActivityInfo();
        if (info != null && info.currentSpeed != null) {
            currentSpeedMPS = info.currentSpeed as Float;
        }
        var cacheHits =
            "cacheHits: " +
            percentage.format("%.1f") +
            "% s: " +
            currentSpeedMPS.format("%.1f") +
            "m/s";
        dc.drawText(x, y, Graphics.FONT_XTINY, cacheHits, Graphics.TEXT_JUSTIFY_CENTER);
        y += spacing;
        dc.drawText(
            x,
            y,
            Graphics.FONT_XTINY,
            "mem: " +
                (System.getSystemStats().usedMemory / 1024f).format("%.1f") +
                "K f: " +
                (System.getSystemStats().freeMemory / 1024f).format("%.1f") +
                "K",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        y += spacing;
        // _lastFullRenderTime only updates when rendering the track (debug screen does not use it, so it just counts up whilst on the debug page)
        // dc.drawText(x, y, Graphics.FONT_XTINY, "last buff render: " + (epoch - _lastFullRenderTime) + "s", Graphics.TEXT_JUSTIFY_CENTER);
        // y+=spacing;
        // could do as a ratio for a single field
        // auto
        var scale = _cachedValues.scale;
        if (scale != null) {
            dc.drawText(
                x,
                y,
                Graphics.FONT_XTINY,
                "scale: " + scale.format("%.2f"),
                Graphics.TEXT_JUSTIFY_CENTER
            );
        } else {
            dc.drawText(x, y, Graphics.FONT_XTINY, "scale: Auto", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function renderElevation(dc as Dc) as Void {
        if (settings.elevationMode == ELEVATION_MODE_STACKED) {
            renderElevationStacked(dc);
            return;
        }

        renderElevationOrderedRoutes(dc);
    }

    function renderElevationStacked(dc as Dc) as Void {
        var routes = _breadcrumbContext.routes;
        var track = _breadcrumbContext.track;
        var renderer = _breadcrumbContext.breadcrumbRenderer;

        var elevationScale = renderer.getElevationScale(track, routes);
        var hScale = elevationScale[0];
        var vScale = elevationScale[1];
        var startAt = elevationScale[2];
        var hScalePPM = elevationScale[3];

        var lastPoint = track.lastPoint();
        var elevationText = "";

        if (lastPoint == null) {
            elevationText = "";
        } else {
            if (settings.elevationImperialUnits) {
                var elevationFt = lastPoint.altitude * 3.28084;
                elevationText = elevationFt.format("%.0f") + "ft";
            } else {
                elevationText = lastPoint.altitude.format("%.0f") + "m";
            }
        }

        renderer.renderElevationChart(
            dc,
            hScalePPM,
            vScale,
            startAt,
            track.distanceTotal,
            elevationText
        );
        if (routes.size() != 0) {
            for (var i = 0; i < routes.size(); ++i) {
                var route = routes[i];
                if (!settings.routeEnabled(route.storageIndex)) {
                    continue;
                }
                renderer.renderTrackElevation(
                    dc,
                    renderer._xElevationStart,
                    route,
                    settings.routeColour(route.storageIndex),
                    hScale,
                    vScale,
                    startAt
                );
            }
        }
        renderer.renderTrackElevation(
            dc,
            renderer._xElevationStart,
            track,
            settings.trackColour,
            hScale,
            vScale,
            startAt
        );
    }

    function renderElevationOrderedRoutes(dc as Dc) as Void {
        var routes = _breadcrumbContext.routes;
        var track = _breadcrumbContext.track;
        var renderer = _breadcrumbContext.breadcrumbRenderer;

        var elevationScale = renderer.getElevationScaleOrderedRoutes(track, routes);
        var hScale = elevationScale[0];
        var vScale = elevationScale[1];
        var startAt = elevationScale[2];
        var hScalePPM = elevationScale[3];

        var lastPoint = track.lastPoint();
        var elevationText = "";

        if (lastPoint == null) {
            elevationText = "";
        } else {
            if (settings.elevationImperialUnits) {
                var elevationFt = lastPoint.altitude * 3.28084;
                elevationText = elevationFt.format("%.0f") + "ft";
            } else {
                elevationText = lastPoint.altitude.format("%.0f") + "m";
            }
        }

        var elevationStartX = renderer._xElevationStart;

        renderer.renderElevationChart(
            dc,
            hScalePPM,
            vScale,
            startAt,
            track.distanceTotal,
            elevationText
        );
        if (routes.size() != 0) {
            for (var i = 0; i < routes.size(); ++i) {
                var route = routes[i];
                if (!settings.routeEnabled(route.storageIndex)) {
                    continue;
                }
                elevationStartX = renderer.renderTrackElevation(
                    dc,
                    elevationStartX,
                    route,
                    settings.routeColour(route.storageIndex),
                    hScale,
                    vScale,
                    startAt
                );
            }
        }
        renderer.renderTrackElevation(
            dc,
            renderer._xElevationStart,
            track,
            settings.trackColour,
            hScale,
            vScale,
            startAt
        );
    }
}
