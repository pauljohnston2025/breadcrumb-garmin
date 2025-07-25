import Toybox.Application;
import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Activity;

// An iterator that walks along a line segment, yielding one point at a time.
(:storage)
class SegmentPointIterator {
    private var _x1 as Float;
    private var _y1 as Float;
    private var _x2 as Float;
    private var _y2 as Float;
    private var _stepDistance as Float;

    // State variables
    private var _totalDistance as Float;
    private var _dirX as Float;
    private var _dirY as Float;
    private var _distanceTraveled as Float;
    private var _isFinished as Boolean;

    // Constructor
    function initialize(
        x1 as Float,
        y1 as Float,
        x2 as Float,
        y2 as Float,
        stepDistanceM as Float
    ) {
        _x1 = x1;
        _y1 = y1;
        _x2 = x2;
        _y2 = y2;
        _stepDistance = stepDistanceM;

        var dx = _x2 - _x1;
        var dy = _y2 - _y1;
        _totalDistance = Math.sqrt(dx * dx + dy * dy).toFloat();

        if (_totalDistance > 0) {
            _dirX = dx / _totalDistance;
            _dirY = dy / _totalDistance;
        } else {
            _dirX = 0f;
            _dirY = 0f;
        }

        _distanceTraveled = 0f;
        _isFinished = false;
    }

    // Returns the next point [x, y] on the segment, or null if finished.
    function next() as [Float, Float]? {
        if (_isFinished) {
            return null;
        }

        var point;
        if (_distanceTraveled >= _totalDistance) {
            // We have reached or passed the end. Return the exact end point.
            point = [_x2, _y2];
            _isFinished = true;
        } else {
            // Calculate the current point based on distance traveled.
            var currentX = _x1 + _distanceTraveled * _dirX;
            var currentY = _y1 + _distanceTraveled * _dirY;
            point = [currentX, currentY];

            // Advance our state for the next call.
            _distanceTraveled += _stepDistance;
        }

        return point;
    }
}

// https://developer.garmin.com/connect-iq/reference-guides/monkey-c-reference/
// Monkey C is a message-passed language. When a function is called, the virtual machine searches a hierarchy at runtime in the following order to find the function:
// Instance members of the class
// Members of the superclass
// Static members of the class
// Members of the parent module, and the parent modules up to the global namespace
// Members of the superclass’s parent module up to the global namespace
class CachedValues {
    private var _settings as Settings;

    // cache some important maths to make everything faster
    // things set to -1 are updated on the first layout/calcualte call

    // updated when settings change
    var smallTilesPerScaledTile as Number = -1;
    var smallTilesPerFullTile as Number = -1;
    // updated when user manually pans around screen
    var fixedPosition as RectangularPoint?; // NOT SCALED - raw meters
    var scale as Float? = null; // fixed map scale, when manually zooming or panning around map
    var scaleCanInc as Boolean = true;
    var scaleCanDec as Boolean = true;

    // updated whenever we change zoom level (speed changes, zoom at pace mode etc.)
    var centerPosition as RectangularPoint = new RectangularPoint(0f, 0f, 0f); // scaled to pixels
    var currentScale as Float = 0.0; // pixels per meter so <pixel count> / _currentScale = meters  or  meters * _currentScale = pixels
    // will be changed whenever scale is adjusted, falls back to metersAroundUser when no scale
    var mapMoveDistanceM as Float = -1f;

    // updated whenever we get new activity data with a new heading
    var rotationRad as Float = 0.0; // heading in radians
    var rotateCos as Float = Math.cos(rotationRad).toFloat();
    var rotateSin as Float = Math.sin(rotationRad).toFloat();
    var currentSpeed as Float = -1f;
    var elapsedDistanceM as Float = 0f;
    var currentlyZoomingAroundUser as Boolean = false;

    // updated whenever onlayout changes (audit usages, these should not need to be floats, but sometimes are used to do float math)
    // default to full screen guess
    var physicalScreenWidth as Float = System.getDeviceSettings().screenWidth.toFloat();
    var physicalScreenHeight as Float = System.getDeviceSettings().screenHeight.toFloat();
    var minPhysicalScreenDim as Float = minF(physicalScreenWidth, physicalScreenHeight);
    var maxPhysicalScreenDim as Float = maxF(physicalScreenWidth, physicalScreenHeight);
    var xHalfPhysical as Float = physicalScreenWidth / 2f;
    var yHalfPhysical as Float = physicalScreenHeight / 2f;
    var virtualScreenWidth as Float = System.getDeviceSettings().screenWidth.toFloat();
    var virtualScreenHeight as Float = System.getDeviceSettings().screenHeight.toFloat();
    var minVirtualScreenDim as Float = minF(virtualScreenWidth, virtualScreenHeight);
    var maxVirtualScreenDim as Float = maxF(virtualScreenWidth, virtualScreenHeight);
    var bufferedBitmapOffsetX as Float = -(maxVirtualScreenDim - physicalScreenWidth) / 2f;
    var bufferedBitmapOffsetY as Float = 0f; // only neeed for buffered rotation mode, with user offset values less than 0.5
    var rotateAroundScreenX as Float = physicalScreenWidth / 2f;
    var rotateAroundScreenY as Float = physicalScreenHeight / 2f;
    var rotateAroundScreenXOffsetFactoredIn as Float = rotateAroundScreenX - bufferedBitmapOffsetX;
    var rotateAroundScreenYOffsetFactoredIn as Float = rotateAroundScreenY;
    var mapScreenWidth as Float = physicalScreenWidth;
    var mapScreenHeight as Float = physicalScreenHeight;
    var mapBitmapOffsetX as Float = 0f;
    var mapBitmapOffsetY as Float = 0f;
    var rotateAroundMinScreenDim as Float = minPhysicalScreenDim;
    var rotateAroundMaxScreenDim as Float = maxPhysicalScreenDim;
    var rotationMatrix as AffineTransform = new AffineTransform();

    // map related fields updated whenever scale changes
    var mapDataCanBeUsed as Boolean = false;
    var earthsCircumference as Float = 40075016.686f;
    var originShift as Float = earthsCircumference / 2.0; // Half circumference of Earth
    var tileZ as Number = -1;
    var tileScaleFactor as Float = -1f;
    var tileScalePixelSize as Number = -1;
    var tileOffsetX as Number = -1;
    var tileOffsetY as Number = -1;
    var tileCountX as Number = -1;
    var tileCountY as Number = -1;
    var firstTileX as Number = -1;
    var firstTileY as Number = -1;

    // todo store all these in a 'seeding' class so the variables are not using memory when the seeding is not happening
    var seedingZ as Number = -1; // -1 means not seeding
    var seedingRectanglarTopLeft as RectangularPoint = new RectangularPoint(0f, 0f, 0f);
    var seedingRectanglarBottomRight as RectangularPoint = new RectangularPoint(0f, 0f, 0f);
    var seedingUpToTileX as Number = 0;
    var seedingUpToTileY as Number = 0;
    var seedingRouteLeftRightValid as Boolean = false;
    var seedingUpToRoute as Number = 0;
    var seedingUpToRoutePoint as Number = 0;
    var seedingUpToRoutePointPartial as SegmentPointIterator? = null;
    var seedingTilesOnThisLayer as Number = NUMBER_MAX;
    var seedingTilesProgressForThisLayer as Number = 0;
    var seedingMapCacheDistanceM as Float = -1f;
    var seedingInProgressTiles as Array<TileKey> = [];
    var seedingFirstTileX as Number = 0;
    var seedingFirstTileY as Number = 0;
    var seedingLastTileX as Number = 0;
    var seedingLastTileY as Number = 0;

    function atMinTileLayer() as Boolean {
        return tileZ == _settings.tileLayerMin;
    }

    function atMaxTileLayer() as Boolean {
        return tileZ == _settings.tileLayerMax;
    }

    function initialize(settings as Settings) {
        self._settings = settings;
    }

    function setup() as Void {
        smallTilesPerScaledTile = Math.ceil(
            _settings.scaledTileSize / _settings.tileSize.toFloat()
        ).toNumber();
        smallTilesPerFullTile = Math.ceil(
            _settings.fullTileSize / _settings.tileSize.toFloat()
        ).toNumber();
        fixedPosition = null;
        // will be changed whenever scale is adjusted, falls back to metersAroundUser when no scale
        mapMoveDistanceM = _settings.metersAroundUser.toFloat() * _settings.mapMoveScreenSize;
        seedingMapCacheDistanceM = _settings.metersAroundUser.toFloat() * 0.5;
        recalculateAll();
    }

    function calcOuterBoundingBoxFromTrackAndRoutes(
        routes as Array<BreadcrumbTrack>,
        trackBoundingBox as [Float, Float, Float, Float]?
    ) as [Float, Float, Float, Float] {
        var scaleDivisor = currentScale;
        if (currentScale == 0f) {
            scaleDivisor = 1; // use raw coordinates
        }

        // we need to make a new object, otherwise we will modify the one thats passed in
        var outerBoundingBox = BOUNDING_BOX_DEFAULT();
        if (trackBoundingBox != null) {
            outerBoundingBox[0] = trackBoundingBox[0] / scaleDivisor;
            outerBoundingBox[1] = trackBoundingBox[1] / scaleDivisor;
            outerBoundingBox[2] = trackBoundingBox[2] / scaleDivisor;
            outerBoundingBox[3] = trackBoundingBox[3] / scaleDivisor;
        }

        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (!_settings.routeEnabled(route.storageIndex)) {
                continue;
            }
            outerBoundingBox[0] = minF(route.boundingBox[0] / scaleDivisor, outerBoundingBox[0]);
            outerBoundingBox[1] = minF(route.boundingBox[1] / scaleDivisor, outerBoundingBox[1]);
            outerBoundingBox[2] = maxF(route.boundingBox[2] / scaleDivisor, outerBoundingBox[2]);
            outerBoundingBox[3] = maxF(route.boundingBox[3] / scaleDivisor, outerBoundingBox[3]);
        }

        return outerBoundingBox;
    }

    /** returns true if a rescale occurred */
    function updateScaleCenterAndMap() as Boolean {
        var newScale = getNewScaleAndUpdateCenter();
        var rescaleOccurred = handleNewScale(newScale);
        if (_settings.mapEnabled) {
            updateMapData();
        }
        if (currentScale != 0f) {
            mapMoveDistanceM =
                (rotateAroundMaxScreenDim * _settings.mapMoveScreenSize) / currentScale;
            seedingMapCacheDistanceM = (rotateAroundMaxScreenDim * 0.5) / currentScale;
        }
        return rescaleOccurred;
    }

    /** returns the new scale */
    function getNewScaleAndUpdateCenter() as Float {
        if (currentlyZoomingAroundUser) {
            var renderDistanceM = _settings.metersAroundUser;
            if (!calcCenterPoint()) {
                var lastPoint = getApp()._breadcrumbContext.track.coordinates.lastPoint();
                if (lastPoint != null) {
                    centerPosition = lastPoint;
                    return calculateScale(renderDistanceM.toFloat());
                }
                // we are zooming around the user, but we do not have a last track point
                // resort to using bounding box
                var boundingBox = calcOuterBoundingBoxFromTrackAndRoutes(
                    getApp()._breadcrumbContext.routes,
                    null
                );
                calcCenterPointForBoundingBox(boundingBox);
                return calculateScale(renderDistanceM.toFloat());
            }

            return calculateScale(renderDistanceM.toFloat());
        }

        var boundingBox = calcOuterBoundingBoxFromTrackAndRoutes(
            getApp()._breadcrumbContext.routes,
            // if no roues we will try and render the track instead
            _settings.zoomAtPaceMode == ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK &&
                getApp()._breadcrumbContext.routes.size() != 0
                ? null
                : optionalTrackBoundingBox()
        );
        calcCenterPointForBoundingBox(boundingBox);
        return getNewScaleFromBoundingBox(boundingBox);
    }

    function optionalTrackBoundingBox() as [Float, Float, Float, Float]? {
        return getApp()._breadcrumbContext.track.coordinates.lastPoint() == null
            ? null
            : getApp()._breadcrumbContext.track.boundingBox;
    }

    // needs to be called whenever the screen moves to a new bounding box
    function updateMapData() as Void {
        if (currentScale == 0f || smallTilesPerScaledTile == 0) {
            // do not divide by zero my good friends
            // we do not have a scale calculated yet
            return;
        }

        var centerPositionRaw = centerPosition.rescale(1 / currentScale);

        // 2 to 15 see https://opentopomap.org/#map=2/-43.2/305.9
        var desiredResolution = 1 / currentScale;
        var z = calculateTileLevel(desiredResolution);
        tileZ = minN(maxN(z, _settings.tileLayerMin), _settings.tileLayerMax); // cap to our limits

        var tileWidthM = (
            earthsCircumference /
            Math.pow(2, tileZ) /
            smallTilesPerScaledTile
        ).toFloat();
        var halfScreenWidthM = mapScreenWidth / 2.0f / currentScale;
        var halfScreenHeightM = mapScreenHeight / 2.0f / currentScale;

        // where the screen corner starts
        var screenLeftM = centerPositionRaw.x - halfScreenWidthM;
        var screenTopM = centerPositionRaw.y + halfScreenHeightM;

        // find which tile we are closest to
        var mapBitmapOffsetXM = mapBitmapOffsetX / currentScale;
        var mapBitmapOffsetYM = mapBitmapOffsetY / currentScale;
        firstTileX = ((screenLeftM + originShift - mapBitmapOffsetXM) / tileWidthM).toNumber();
        firstTileY = ((originShift - screenTopM - mapBitmapOffsetYM) / tileWidthM).toNumber();

        // remember, lat/long is a different coordinate system (the lower we are the more negative we are)
        //  x calculations are the same - more left = more negative
        //  tile inside graph
        // 90
        //    | 0,0 1,0   tile
        //    | 0,1 1,1
        //    |____________________
        //  -180,-90              180
        var firstTileLeftM = firstTileX * tileWidthM - originShift;
        var firstTileTopM = originShift - firstTileY * tileWidthM;

        // var screenToTilePixelRatio = minScreenDim / _settings.tileSize;
        // var screenToTileMRatio = minScreenDimM / tileWidthM;
        // var scaleFactor = screenToTilePixelRatio / screenToTileMRatio; // we need to stretch or shrink the tiles by this much
        // simplification of above calculation
        tileScaleFactor = (currentScale * tileWidthM) / _settings.tileSize;
        // eg. tile = 10m screen = 10m tile = 256pixel screen = 360pixel scaleFactor = 1.4 each tile pixel needs to become 1.4 sceen pixels
        // eg. 2
        //     tile = 20m screen = 10m tile = 256pixel screen = 360pixel scaleFactor = 2.8 we only want to render half the tile, so we only have half the pixels
        //     screenToTileMRatio = 0.5 screenToTilePixelRatio = 1.4
        // eg. 3
        //     tile = 10m screen = 20m tile = 256pixel screen = 360pixel scaleFactor = 0.7 we need 2 tiles, each tile pixel needs to be squashed into screen pixels
        //     screenToTileMRatio = 2 screenToTilePixelRatio = 1.4
        //

        // how many pixels on the screen the tile should take up this can be smaller or larger than the actual tile,
        // depending on if we scale up or down
        // find the closest pixel size
        tileScalePixelSize = Math.round(_settings.tileSize * tileScaleFactor).toNumber();

        // find the closest pixel size
        tileOffsetX = Math.round(
            (firstTileLeftM - screenLeftM) * currentScale + mapBitmapOffsetX
        ).toNumber();
        tileOffsetY = Math.round(
            (screenTopM - firstTileTopM) * currentScale + mapBitmapOffsetY
        ).toNumber();

        tileCountX = Math.ceil((-tileOffsetX + mapScreenWidth) / tileScalePixelSize).toNumber();
        tileCountY = Math.ceil((-tileOffsetY + mapScreenHeight) / tileScalePixelSize).toNumber();
        mapDataCanBeUsed = true;
    }

    /** returns true if a rescale occurred */
    function onActivityInfo(activityInfo as Activity.Info) as Boolean {
        // System.println(
        //     "store heading, current speed etc. so we can know how to render the "
        //     + "map");
        // garmin might already do this for us? the docs say
        // track:
        // The current track in radians.
        // Track is the direction of travel in radians based on GPS movement. If supported by the device, this provides compass orientation when stopped.
        // currentHeading :
        // The true north referenced heading in radians.
        // This provides compass orientation if it is supported by the device.
        // based on some of the posts here, its better to use currentHeading if we want our compas to work whilst not moving, and track is only supported on some devices
        // https://forums.garmin.com/developer/connect-iq/f/discussion/258978/currentheading
        var currentHeading = activityInfo.currentHeading;
        if (activityInfo has :track) {
            var track = activityInfo.track;
            if (currentHeading == null && track != null) {
                currentHeading = track;
            }
        }

        if (currentHeading != null) {
            rotationRad = currentHeading;
            rotateCos = Math.cos(rotationRad).toFloat();
            rotateSin = Math.sin(rotationRad).toFloat();
        }
        var _currentSpeed = activityInfo.currentSpeed;
        if (_currentSpeed != null) {
            currentSpeed = _currentSpeed;
        }

        updateRotationMatrix();

        var _elapsedDistance = activityInfo.elapsedDistance;
        if (_elapsedDistance != null) {
            elapsedDistanceM = _elapsedDistance;
        }

        // we are either in 2 cases
        // if we are moving at some pace check the mode we are in to determine if we
        // zoom in or out
        // or we are not at speed, so invert logic (this allows us to zoom in when
        // stopped, and zoom out when running) mostly useful for cheking close route
        // whilst stopped but also allows quick zoom in before setting manual zoom
        // (rather than having to manually zoom in from the outer level) once zoomed
        // in we lock onto the user position anyway
        var weShouldZoomAroundUser =
            (scale != null &&
                _settings.zoomAtPaceMode != ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK) ||
            (currentSpeed > _settings.zoomAtPaceSpeedMPS &&
                _settings.zoomAtPaceMode == ZOOM_AT_PACE_MODE_PACE) ||
            (currentSpeed <= _settings.zoomAtPaceSpeedMPS &&
                _settings.zoomAtPaceMode == ZOOM_AT_PACE_MODE_STOPPED) ||
            _settings.zoomAtPaceMode == ZOOM_AT_PACE_MODE_ALWAYS_ZOOM;
        if (currentlyZoomingAroundUser != weShouldZoomAroundUser) {
            currentlyZoomingAroundUser = weShouldZoomAroundUser;
            updateUserRotationElements();
            var ret = updateScaleCenterAndMap();
            _settings.clearPendingWebRequests();
            getApp()._view.resetRenderTime();
            return ret;
        }

        return false;
    }

    function setScreenSize(width as Number, height as Number) as Void {
        physicalScreenWidth = width.toFloat();
        physicalScreenHeight = height.toFloat();
        minPhysicalScreenDim = minF(physicalScreenWidth, physicalScreenHeight);
        maxPhysicalScreenDim = maxF(physicalScreenWidth, physicalScreenHeight);
        xHalfPhysical = physicalScreenWidth / 2f;
        yHalfPhysical = physicalScreenHeight / 2f;

        updateVirtualScreenSize();
        updateScaleCenterAndMap();
    }

    function updateVirtualScreenSize() as Void {
        virtualScreenWidth = physicalScreenWidth; // always the same, just using naming for consistency
        if (
            _settings.renderMode == RENDER_MODE_BUFFERED_ROTATING ||
            _settings.renderMode == RENDER_MODE_UNBUFFERED_ROTATING
        ) {
            if (_settings.centerUserOffsetY >= 0.5) {
                virtualScreenHeight = physicalScreenHeight * _settings.centerUserOffsetY * 2;
            } else {
                virtualScreenHeight =
                    (physicalScreenHeight - physicalScreenHeight * _settings.centerUserOffsetY) * 2;
            }
        } else {
            virtualScreenHeight = physicalScreenHeight;
        }

        minVirtualScreenDim = minF(virtualScreenWidth, virtualScreenHeight);
        maxVirtualScreenDim = maxF(virtualScreenWidth, virtualScreenHeight);

        updateUserRotationElements();
    }

    function updateUserRotationElements() as Void {
        if (currentlyZoomingAroundUser) {
            rotateAroundScreenX = virtualScreenWidth / 2f;
            rotateAroundScreenY = physicalScreenHeight * _settings.centerUserOffsetY;
            rotateAroundMinScreenDim = minVirtualScreenDim;
            rotateAroundMaxScreenDim = maxVirtualScreenDim;
            mapScreenWidth = rotateAroundMaxScreenDim;
            mapScreenHeight = rotateAroundMaxScreenDim;

            if (
                _settings.renderMode == RENDER_MODE_UNBUFFERED_NO_ROTATION ||
                _settings.renderMode == RENDER_MODE_BUFFERED_NO_ROTATION
            ) {
                // attempt to reduce the number of map tiles needed in render modes without roatations
                // rotation mode still needs all the map tiles, since it could rotate to any of them at any point
                // RENDER_MODE_BUFFERED_ROTATING is a pretty rarely used mode, so not sure its worth this.
                // we do not modify virtual screen size, since that would mean the buffered bitmap would change size and need updating too. We could do it for RENDER_MODE_UNBUFFERED_ROTATING only.
                mapScreenWidth = physicalScreenWidth;
                mapScreenHeight = physicalScreenHeight;
            }
        } else {
            rotateAroundScreenX = xHalfPhysical;
            rotateAroundScreenY = yHalfPhysical;
            rotateAroundMinScreenDim = minPhysicalScreenDim;
            rotateAroundMaxScreenDim = maxPhysicalScreenDim;
            mapScreenWidth = physicalScreenWidth;
            mapScreenHeight = physicalScreenHeight;
        }

        mapBitmapOffsetX = 0f;
        mapBitmapOffsetY = 0f;

        if (_settings.renderMode == RENDER_MODE_BUFFERED_NO_ROTATION) {
            // draw it top left, so we can make our map tiles less (and possibly reduce the whole bitmap size)
            bufferedBitmapOffsetX = 0f;
            bufferedBitmapOffsetY = 0f;

            rotateAroundScreenXOffsetFactoredIn = rotateAroundScreenX - bufferedBitmapOffsetX;
            rotateAroundScreenYOffsetFactoredIn = rotateAroundScreenY - bufferedBitmapOffsetY;

            if (currentlyZoomingAroundUser) {
                mapBitmapOffsetY = rotateAroundScreenY - yHalfPhysical;
            }
        } else if (_settings.renderMode == RENDER_MODE_BUFFERED_ROTATING) {
            bufferedBitmapOffsetX = -(rotateAroundMaxScreenDim - physicalScreenWidth) / 2f;
            bufferedBitmapOffsetY = -(rotateAroundMaxScreenDim - physicalScreenHeight);
            rotateAroundScreenXOffsetFactoredIn = rotateAroundScreenX - bufferedBitmapOffsetX;
            rotateAroundScreenYOffsetFactoredIn = rotateAroundScreenY - bufferedBitmapOffsetY;

            if (_settings.centerUserOffsetY >= 0.5 && currentlyZoomingAroundUser) {
                rotateAroundScreenYOffsetFactoredIn = rotateAroundScreenY; // draw straight to the buffered canvas, since the canvas top matches our top
            }
        } else if (_settings.renderMode == RENDER_MODE_UNBUFFERED_ROTATING) {
            // unbuffered mode -> draws straight to dc
            rotateAroundScreenXOffsetFactoredIn = rotateAroundScreenX;
            rotateAroundScreenYOffsetFactoredIn = rotateAroundScreenY;
            bufferedBitmapOffsetX = rotateAroundScreenX;
            bufferedBitmapOffsetY = rotateAroundScreenY;

            if (currentlyZoomingAroundUser) {
                bufferedBitmapOffsetX = -(rotateAroundMaxScreenDim - physicalScreenWidth) / 2f;
                bufferedBitmapOffsetY = -(rotateAroundMaxScreenDim - physicalScreenHeight);
                // dirty hacks, using bufferedBitmapOffsetX for map rednerer to do the tile offsets
                // if we use just mapBitmapOffsetX/mapBitmapOffsetY we get clipping
                bufferedBitmapOffsetX = rotateAroundScreenX - bufferedBitmapOffsetX;
                bufferedBitmapOffsetY = rotateAroundScreenY - bufferedBitmapOffsetY;

                if (_settings.centerUserOffsetY >= 0.5) {
                    bufferedBitmapOffsetY = rotateAroundScreenY;
                }
            }
        } else {
            // RENDER_MODE_UNBUFFERED_NO_ROTATION
            // unbuffered mode -> draws straight to dc
            if (currentlyZoomingAroundUser) {
                mapBitmapOffsetY = rotateAroundScreenY - yHalfPhysical;
            }

            rotateAroundScreenXOffsetFactoredIn = rotateAroundScreenX;
            rotateAroundScreenYOffsetFactoredIn = rotateAroundScreenY;
        }

        updateRotationMatrix();
    }

    function updateRotationMatrix() as Void {
        rotationMatrix = new AffineTransform();
        rotationMatrix.translate(rotateAroundScreenX, rotateAroundScreenY); // move to center
        rotationMatrix.rotate(-rotationRad); // rotate
        rotationMatrix.translate(
            -rotateAroundScreenXOffsetFactoredIn,
            -rotateAroundScreenYOffsetFactoredIn
        ); // move back to position
    }

    function calculateScale(maxDistanceM as Float) as Float {
        if (_settings.scaleRestrictedToTileLayers() && _settings.mapEnabled) {
            return tileLayerScale(maxDistanceM);
        }
        return calculateScaleStandard(maxDistanceM);
    }

    function calculateScaleStandard(maxDistanceM as Float) as Float {
        if (scale != null) {
            return scale;
        }

        return calcScaleForScreenMeters(maxDistanceM);
    }

    function calcScaleForScreenMeters(maxDistanceM as Float) as Float {
        // we want the whole map to be show on the screen, we have 360 pixels on the
        // venu 2s
        // but this would only work for sqaures, so 0.75 fudge factor for circle
        // watch face
        return (rotateAroundMinScreenDim / maxDistanceM) * 0.75;
    }

    function nextTileLayerScale(direction as Number) as Float {
        var scaleL = scale;
        if (smallTilesPerFullTile == 0 || scaleL == null || scaleL == 0f) {
            return 0f;
        }

        var currentZ = calculateTileLevel(1 / scaleL);
        currentZ = minN(maxN(currentZ, _settings.tileLayerMin), _settings.tileLayerMax); // cap to our limits, otherwise we can decreent/increment outside the range if we are already at a bad scale
        var nextZ = currentZ + direction;

        nextZ = minN(maxN(nextZ, _settings.tileLayerMin), _settings.tileLayerMax); // cap to our limits
        var tileWidthM2 = earthsCircumference / Math.pow(2, nextZ) / smallTilesPerFullTile;
        var ret = (_settings.tileSize / tileWidthM2).toFloat();
        // atMinTileLayer = ret == _settings.tileLayerMin;
        // atMaxTileLayer = ret == _settings.tileLayerMax;
        return ret;
    }

    function tileLayerScale(maxDistanceM as Float) as Float {
        var perfectScale = calculateScaleStandard(maxDistanceM);

        if (perfectScale == 0f || smallTilesPerFullTile == 0) {
            return perfectScale; // do not divide by 0
        }

        // only allow map tile scale levels so that we can render the tiles without any gaps, and at the correct size
        // todo cache these calcs, it is for the slower devices after all
        var desiredResolution = 1 / perfectScale;
        var z = calculateTileLevel(desiredResolution);
        z = minN(maxN(z, _settings.tileLayerMin), _settings.tileLayerMax); // cap to our limits

        // we want these ratios to be the same
        // var minScreenDimM = _minScreenDim / currentScale;
        // var screenToTileMRatio = minScreenDimM / tileWidthM;
        // var screenToTilePixelRatio = minScreenDim / _settings.tileSize;
        var tileWidthM2 = earthsCircumference / Math.pow(2, z) / smallTilesPerFullTile;
        //  var screenToTilePixelRatio = _minScreenDim / settings.tileSize;

        // note: this gets as close as it can to the zoom level, some route clipping might occur
        // we have to go to the largertile sizes so that we can see the whole route
        return (_settings.tileSize / tileWidthM2).toFloat();
    }

    /** returns the new scale */
    function getNewScaleFromBoundingBox(outerBoundingBox as [Float, Float, Float, Float]) as Float {
        var xDistanceM = outerBoundingBox[2] - outerBoundingBox[0];
        var yDistanceM = outerBoundingBox[3] - outerBoundingBox[1];

        var maxDistanceM = maxF(xDistanceM, yDistanceM);

        if (maxDistanceM == 0f) {
            // show 1m of space to avaoid division by 0
            maxDistanceM = 1f;
        }

        return calculateScale(maxDistanceM);
    }

    /** returns true if the scale changed */
    function handleNewScale(newScale as Float) as Boolean {
        if (abs(currentScale - newScale) < 0.000001) {
            // ignore any minor scale changes, esp if the scale is the same but float == does not work
            return false;
        }

        if (newScale == 0f) {
            return false; // dont allow silly scales
        }

        var scaleFactor = newScale;
        if (currentScale != null && currentScale != 0f) {
            // adjsut by old scale
            scaleFactor = newScale / currentScale;
        }

        var routes = getApp()._breadcrumbContext.routes;
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            route.rescale(scaleFactor); // rescale all routes, even if they are not enabled
        }
        getApp()._breadcrumbContext.track.rescale(scaleFactor);
        getApp()._view.rescale(scaleFactor);
        centerPosition.rescaleInPlace(scaleFactor);

        currentScale = newScale;
        return true;
    }

    function recalculateAll() as Void {
        System.println("recalculating all cached values from settings/routes change");
        smallTilesPerScaledTile = Math.ceil(
            _settings.scaledTileSize / _settings.tileSize.toFloat()
        ).toNumber();
        smallTilesPerFullTile = Math.ceil(
            _settings.fullTileSize / _settings.tileSize.toFloat()
        ).toNumber();
        updateFixedPositionFromSettings();
        updateVirtualScreenSize();
        updateScaleCenterAndMap();
    }

    function updateFixedPositionFromSettings() as Void {
        var fixedLatitude = _settings.fixedLatitude;
        var fixedLongitude = _settings.fixedLongitude;
        if (fixedLatitude == null || fixedLongitude == null) {
            fixedPosition = null;
        } else {
            fixedPosition = RectangularPoint.latLon2xy(fixedLatitude, fixedLongitude, 0f);
        }
    }

    // Desired resolution (meters per pixel)
    function calculateTileLevel(desiredResolution as Float) as Number {
        var zF = Math.log(
            earthsCircumference / (_settings.tileSize * desiredResolution) / smallTilesPerFullTile,
            2
        );

        return Math.round(zF).toNumber();
    }

    function moveLatLong(
        xMoveUnrotated as Float,
        yMoveUnrotated as Float,
        xMoveRotated as Float,
        yMoveRotated as Float
    ) as [Float, Float]? {
        var fixedPositionL = fixedPosition;
        if (fixedPositionL == null) {
            // never happens, but appease the compiler
            logE("unreachable, fixedPositionL is null");
            return null;
        }
        if (
            _settings.renderMode == RENDER_MODE_UNBUFFERED_NO_ROTATION ||
            _settings.renderMode == RENDER_MODE_BUFFERED_NO_ROTATION
        ) {
            return RectangularPoint.xyToLatLon(
                fixedPositionL.x + xMoveUnrotated,
                fixedPositionL.y + yMoveUnrotated
            );
        }

        return RectangularPoint.xyToLatLon(
            fixedPositionL.x + xMoveRotated,
            fixedPositionL.y + yMoveRotated
        );
    }

    function moveFixedPositionUp() as Void {
        setPositionAndScaleIfNotSet();

        var latlong = moveLatLong(
            0f,
            mapMoveDistanceM,
            rotateSin * mapMoveDistanceM,
            rotateCos * mapMoveDistanceM
        );
        if (latlong != null) {
            _settings.setFixedPositionRaw(latlong[0], latlong[1]);
        }
        updateFixedPositionFromSettings();
        updateScaleCenterAndMap();
        getApp()._view.resetRenderTime();
    }

    function moveFixedPositionDown() as Void {
        setPositionAndScaleIfNotSet();
        var latlong = moveLatLong(
            0f,
            -mapMoveDistanceM,
            -rotateSin * mapMoveDistanceM,
            -rotateCos * mapMoveDistanceM
        );
        if (latlong != null) {
            _settings.setFixedPositionRaw(latlong[0], latlong[1]);
        }
        updateFixedPositionFromSettings();
        updateScaleCenterAndMap();
        getApp()._view.resetRenderTime();
    }

    function moveFixedPositionLeft() as Void {
        setPositionAndScaleIfNotSet();
        var latlong = moveLatLong(
            -mapMoveDistanceM,
            0f,
            -rotateCos * mapMoveDistanceM,
            rotateSin * mapMoveDistanceM
        );
        if (latlong != null) {
            _settings.setFixedPositionRaw(latlong[0], latlong[1]);
        }
        updateFixedPositionFromSettings();
        updateScaleCenterAndMap();
        getApp()._view.resetRenderTime();
    }

    function moveFixedPositionRight() as Void {
        setPositionAndScaleIfNotSet();
        var latlong = moveLatLong(
            mapMoveDistanceM,
            0f,
            rotateCos * mapMoveDistanceM,
            -rotateSin * mapMoveDistanceM
        );
        if (latlong != null) {
            _settings.setFixedPositionRaw(latlong[0], latlong[1]);
        }
        updateFixedPositionFromSettings();
        updateScaleCenterAndMap();
        getApp()._view.resetRenderTime();
    }

    function calcCenterPoint() as Boolean {
        if (fixedPosition != null) {
            if (currentScale == 0f) {
                centerPosition = fixedPosition.clone();
            } else {
                centerPosition = fixedPosition.rescale(currentScale);
            }

            return true;
        }

        // when the scale is locked, we need to be where the user is, otherwise we
        // could see a blank part of the map, when we are zoomed in and have no
        // context
        if (
            scale != null &&
            _settings.zoomAtPaceMode != ZOOM_AT_PACE_MODE_SHOW_ROUTES_WITHOUT_TRACK
        ) {
            // the hacks begin
            var lastPoint = getApp()._breadcrumbContext.track.coordinates.lastPoint();
            if (lastPoint != null) {
                centerPosition = lastPoint;
                return true;
            }
        }

        return false;
    }

    function calcCenterPointForBoundingBox(boundingBox as [Float, Float, Float, Float]) as Void {
        if (calcCenterPoint()) {
            return;
        }

        centerPosition = new RectangularPoint(
            boundingBox[0] + (boundingBox[2] - boundingBox[0]) / 2.0,
            boundingBox[1] + (boundingBox[3] - boundingBox[1]) / 2.0,
            0.0f
        );

        if (currentScale != 0f) {
            centerPosition.rescaleInPlace(currentScale);
        }
    }

    function setPositionAndScaleIfNotSet() as Void {
        // we need to set a fixed scale so that a user moving does not change the zoom level randomly whilst they are viewing a map and panning
        if (scale == null) {
            var scaleToSet = currentScale;
            if (currentScale == 0f) {
                scaleToSet = calculateScale(_settings.metersAroundUser.toFloat());
            }
            setScale(scaleToSet);
        }
        fixedPosition = getScreenCenter();
        // System.println("new fixed pos: " + fixedPosition);
    }

    function getScreenCenter() as RectangularPoint {
        var divisor = currentScale;
        if (divisor == 0f) {
            // we should always have a current scale at this point, since we manually set scale (or we are caching map tiles)
            System.println("Warning: current scale was somehow not set");
            divisor = 1f;
        }

        var lastRenderedLatLongCenter = null;
        lastRenderedLatLongCenter = RectangularPoint.xyToLatLon(
            centerPosition.x / divisor,
            centerPosition.y / divisor
        );

        var fixedLatitude = _settings.fixedLatitude;
        var fixedLongitude = _settings.fixedLongitude;
        if (fixedLatitude == null) {
            fixedLatitude = lastRenderedLatLongCenter == null ? 0f : lastRenderedLatLongCenter[0];
        }

        if (fixedLongitude == null) {
            fixedLongitude = lastRenderedLatLongCenter == null ? 0f : lastRenderedLatLongCenter[1];
        }
        var center = RectangularPoint.latLon2xy(fixedLatitude, fixedLongitude, 0f);
        if (center != null) {
            return center;
        }

        return new RectangularPoint(0f, 0f, 0f); // highly unlikely code path
    }

    function returnToUser() as Void {
        _settings.setFixedPosition(null, null, true);
        setScale(null);
    }

    function setScale(_scale as Float?) as Void {
        scale = _scale;
        // be very careful about putting null into properties, it breaks everything
        if (scale == null) {
            _settings.clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
            updateScaleCenterAndMap();
            // this is not the best guess, but will onyl require the user to tap zoom once to see that it cannot zoom
            // getScaleDecIncAmount() only works when the scale is not null. We could update it to use the currentScale if scale is null?
            // they are not acutally in a user scale in this case though, so makes sense to show that we are tracking the users desired zoom instead of ours
            scaleCanInc = true;
            scaleCanDec = true;
            getApp()._view.resetRenderTime();
            return;
        }

        _settings.clearPendingWebRequests(); // we want the new position to render faster, that might be the same position, which is fine they queue up pretty quick
        updateScaleCenterAndMap();
        getApp()._view.resetRenderTime();
    }

    function cancelCacheCurrentMapArea() as Void {
        seedingZ = -1;
        seedingRectanglarTopLeft = new RectangularPoint(0f, 0f, 0f);
        seedingRectanglarBottomRight = new RectangularPoint(0f, 0f, 0f);
        seedingUpToTileX = 0;
        seedingUpToTileY = 0;
        seedingFirstTileX = 0;
        seedingFirstTileY = 0;
        seedingLastTileX = 0;
        seedingLastTileY = 0;
        seedingRouteLeftRightValid = false;
        seedingUpToRoute = 0;
        seedingUpToRoutePoint = 0;
        seedingUpToRoutePointPartial = null;
        seedingTilesOnThisLayer = NUMBER_MAX;
        seedingTilesProgressForThisLayer = 0;
        seedingInProgressTiles = [];
    }

    (:noStorage)
    function startCacheCurrentMapArea() as Void {}
    (:storage)
    function startCacheCurrentMapArea() as Void {
        if (!_settings.mapEnabled) {
            return;
        }

        var tileCache = getApp()._breadcrumbContext.tileCache;
        // If we do not clear the in memory tile cache the image tiles sometimes cause us to crash.
        // Think its because the graphics pool runs out of memory, and makeImageRequest fails with
        // Error: System Error
        // Details: failed inside handle_image_callback
        tileCache.clearValuesWithoutStorage();

        if (_settings.storageSeedBoundingBox) {
            var centerRectangular = getScreenCenter();
            seedingRectanglarTopLeft = new RectangularPoint(
                centerRectangular.x - seedingMapCacheDistanceM,
                centerRectangular.y + seedingMapCacheDistanceM,
                0f
            );
            seedingRectanglarBottomRight = new RectangularPoint(
                centerRectangular.x + seedingMapCacheDistanceM,
                centerRectangular.y - seedingMapCacheDistanceM,
                0f
            );
        }

        // start at max, and move towards min.
        // It's slower to do the lower layers first, but means if we run out of storage the higher layers will still be cached, so we will get a better experiece.
        // Rather than having all the fine details, but no overview, we at least get the overview tiles. Users can set tileLayerMin and tileLayerMax if they would prefer to cache only a single layer.
        seedingZ = _settings.tileLayerMax;
        // todo store current x and y for the for loop, also need to store the max/min tile coords
        // seedingX = ...
        // seedingY = ...
    }

    function seeding() as Boolean {
        return seedingZ >= 0 || seedingInProgressTiles.size() != 0;
    }

    (:noStorage)
    function stepCacheCurrentMapArea() as Boolean {
        return false;
    }
    (:storage)
    function stepCacheCurrentMapArea() as Boolean {
        if (!seeding()) {
            return false;
        }

        if (
            seedingZ >= _settings.tileLayerMin &&
            ((_settings.storageSeedBoundingBox && seedNextTilesToStorageBoundingBox()) ||
                (!_settings.storageSeedBoundingBox && seedNextTilesToStorageAlongRoute()))
        ) {
            seedingZ--;
            seedingUpToTileX = 0;
            seedingUpToTileY = 0;
            seedingFirstTileX = 0;
            seedingFirstTileY = 0;
            seedingLastTileX = 0;
            seedingLastTileY = 0;
            seedingRouteLeftRightValid = false;
            seedingUpToRoute = 0;
            seedingUpToRoutePoint = 0;
            seedingUpToRoutePointPartial = null;
            seedingInProgressTiles = [];
        }

        if (seedingInProgressTiles.size() != 0) {
            // keep seeding them until they are all done
            removeFromSeedingInProgressTilesAndSeedThem();
            return true;
        }

        if (seedingZ < _settings.tileLayerMin) {
            // no more seeding
            cancelCacheCurrentMapArea();
            return false;
        }

        return true;
    }

    // null indicates no more tiles
    (:storage)
    function nextRoutePointTileKey() as TileKey? {
        // DANGEROUS - could trigger watchdog
        var counter = 0;
        while (true) {
            ++counter;
            if (counter > 20) {
                // we should not take any amount of time to do this
                // the while lloop ony oves the state machine forward
                // one iteration each for
                //
                // next route (routes might not be enabled so X maxroutes)
                // next point in route
                // next partial point bwteen route points
                // get the tile coordinates from the partial point
                // inc tile x
                // inc tile y

                // most will return within 1 or 2 iterations, some will take more to increent each level of the loop
                logE("we reached or recursion limit");
                seedingRouteLeftRightValid = false;
                return null; // pretend we are done, something seems wrong
            }

            if (seedingRouteLeftRightValid) {
                // grab the current tile
                var x = seedingUpToTileX;
                var y = seedingUpToTileY;

                // increment for the next call
                ++seedingUpToTileX;
                if (seedingUpToTileX >= seedingLastTileX) {
                    seedingUpToTileX = seedingFirstTileX;
                    ++seedingUpToTileY;
                }

                if (seedingUpToTileY >= seedingLastTileY) {
                    // we were on our last tile for this partial point, reset for the next layer
                    seedingRouteLeftRightValid = false;
                }

                return new TileKey(x, y, seedingZ);
            }

            var routes = getApp()._breadcrumbContext.routes;
            // might be no enabled routes? or the routes might have no coordinates. Guess we just have to return finished?
            if (routes.size() == 0 || !_settings.atLeast1RouteEnabled()) {
                // set up a tile to be downloaded, so that 'seedNextTilesToStorageBoundingBox' returns true
                seedingRouteLeftRightValid = false;
                return null; // there is nothing to process
            }

            if (seedingUpToRoute >= routes.size()) {
                seedingUpToRoute = 0;
                seedingUpToRoutePoint = 0;
                seedingUpToRoutePointPartial = null;
                return null; // we have processed all the routes
            }

            var route = routes[seedingUpToRoute];
            if (!_settings.routeEnabled(route.storageIndex)) {
                ++seedingUpToRoute;
                seedingUpToRoutePoint = 0;
                seedingUpToRoutePointPartial = null;
                continue; // call me again asap
            }
            var routePoint = route.coordinates.getPoint(seedingUpToRoutePoint);
            var nextRoutePoint = route.coordinates.getPoint(seedingUpToRoutePoint + 1);
            if (routePoint == null || nextRoutePoint == null) {
                // we are at the end of the route, no more points, move onto the next route
                ++seedingUpToRoute;
                seedingUpToRoutePoint = 0;
                seedingUpToRoutePointPartial = null;
                continue; // call me again asap
            }

            var divisor = currentScale;
            if (divisor == 0f) {
                // we should always have a current scale at this point, since we manually set scale (or we are caching map tiles)
                System.println("Warning: current scale was somehow not set");
                divisor = 1f;
            }

            if (seedingUpToRoutePointPartial == null) {
                var tileWidthM =
                    earthsCircumference / Math.pow(2, seedingZ) / smallTilesPerScaledTile;
                seedingUpToRoutePointPartial = new SegmentPointIterator(
                    routePoint.x / divisor,
                    routePoint.y / divisor,
                    nextRoutePoint.x / divisor,
                    nextRoutePoint.y / divisor,
                    tileWidthM.toFloat() / 2.0f // we only need to step at half the tile distance, this guarantees we do not miss any tiles (if we have a large gap in coordinates)
                );
            }

            var seedingUpToRoutePointPartialLocal = seedingUpToRoutePointPartial;
            if (seedingUpToRoutePointPartialLocal == null) {
                // wtf? we just set it - must be completely broken, pretend we are finished
                seedingRouteLeftRightValid = false;
                return null;
            }

            var nextPoint = seedingUpToRoutePointPartialLocal.next();
            if (nextPoint == null) {
                // we are onto the next route point
                ++seedingUpToRoutePoint;
                seedingUpToRoutePointPartial = null;
                continue; // call us again soon asap
            }

            // we have reached a new point, update the our bounding box for the point
            seedingRectanglarTopLeft = new RectangularPoint(
                nextPoint[0] - _settings.storageSeedRouteDistanceM,
                nextPoint[1] + _settings.storageSeedRouteDistanceM,
                0f
            );

            seedingRectanglarBottomRight = new RectangularPoint(
                nextPoint[0] + _settings.storageSeedRouteDistanceM,
                nextPoint[1] - _settings.storageSeedRouteDistanceM,
                0f
            );

            var tileWidthM = earthsCircumference / Math.pow(2, seedingZ) / smallTilesPerScaledTile;

            // find which tile we are closest to
            seedingFirstTileX = (
                (seedingRectanglarTopLeft.x + originShift) /
                tileWidthM
            ).toNumber();
            seedingFirstTileY = (
                (originShift - seedingRectanglarTopLeft.y) /
                tileWidthM
            ).toNumber();
            // last tile is open ended range (+1)
            seedingLastTileX =
                ((seedingRectanglarBottomRight.x + originShift) / tileWidthM).toNumber() + 1;
            seedingLastTileY =
                ((originShift - seedingRectanglarBottomRight.y) / tileWidthM).toNumber() + 1;

            seedingUpToTileX = seedingFirstTileX;
            seedingUpToTileY = seedingFirstTileY;
            seedingRouteLeftRightValid = true;
            continue;
        }

        seedingRouteLeftRightValid = false;
        return null; // should alwasy return fromt he shile loop above, this should be unreachable, but pretend we are finished if we hit here
    }

    (:storage)
    function seedNextTilesToStorageAlongRoute() as Boolean {
        var tileCache = getApp()._breadcrumbContext.tileCache;
        // could use Bresenham's Line Algorithm to find all tiles on the path
        // instead we split the routes points up into segments, and download all the tiles for each point in the route,
        // factoring in the max distance around the route to cache

        // each point is downloaded as a bounding box, there will be overlaps
        // this is also highly ineffcient, as there might only be one tile for the entire route ayt low zoom levels, but we still try and get the same
        // tile over and over
        removeFromSeedingInProgressTilesAndSeedThem(); // do not call in for loop, we want to break out so we do not get watchdog errors

        // max 10 outstanding requests, and 10 lots of work for the watchdog, work is variable depending on nextRoutePointTileKey complexity
        // we also need the i tracking it, because on the lower layers we can add the same tile multiple times. eg. layer 0 all the route points will likely point at a single tile, but we stil have to precess the entire route
        var maxTilesAtATime = 50;
        maxTilesAtATime = minN(maxTilesAtATime, _settings.storageTileCacheSize);
        // logD("starting for");
        for (
            var i = 0;
            i < maxTilesAtATime && seedingInProgressTiles.size() < maxTilesAtATime;
            ++i
        ) {
            var nextTileKey = nextRoutePointTileKey();
            // logD("tile:" + nextTileKey);
            if (nextTileKey == null) {
                // we are finished the z layer, move on to the next
                return true;
            }

            // only add it if it's not already present
            if (seedingInProgressTiles.indexOf(nextTileKey) > -1) {
                // logD("already had it");
                continue;
            }

            // logD("adding");
            // we might already have the tile in the storage cache, queue it up anyway so we reach our terminating condition faster
            seedingInProgressTiles.add(nextTileKey);
            tileCache.seedTileToStorage(nextTileKey);
        }

        return false; // only the for loop may return that we are completed
    }

    (:storage)
    function removeFromSeedingInProgressTilesAndSeedThem() as Void {
        var tileCache = getApp()._breadcrumbContext.tileCache;
        var toRemove = [];
        for (var i = 0; i < seedingInProgressTiles.size(); ++i) {
            var item = seedingInProgressTiles[i];

            if (tileCache._storageTileCache.haveTile(item)) {
                toRemove.add(item);
            }
        }

        for (var i = 0; i < toRemove.size(); ++i) {
            var item = toRemove[i];
            seedingInProgressTiles.remove(item as TileKey);
        }

        for (var i = 0; i < seedingInProgressTiles.size(); ++i) {
            var item = seedingInProgressTiles[i];
            // we better request it again, it might not have reached the web handler before
            tileCache.seedTileToStorage(item);
        }
    }

    // todo: switch seedNextTilesToStorageBoundingBox over to use seedingInProgressTiles, so we can start tiles on the next layer before they are done
    // and should also be using cached values for
    // seedingFirstTileX = 0;
    // seedingFirstTileY = 0;
    // seedingLastTileX = 0;
    // seedingLastTileY = 0;
    (:storage)
    function seedNextTilesToStorageBoundingBox() as Boolean {
        var tileWidthM = earthsCircumference / Math.pow(2, seedingZ) / smallTilesPerScaledTile;

        // find which tile we are closest to
        var firstTileX = ((seedingRectanglarTopLeft.x + originShift) / tileWidthM).toNumber();
        var firstTileY = ((originShift - seedingRectanglarTopLeft.y) / tileWidthM).toNumber();
        // last tile is open ended range (+1)
        var lastTileX =
            ((seedingRectanglarBottomRight.x + originShift) / tileWidthM).toNumber() + 1;
        var lastTileY =
            ((originShift - seedingRectanglarBottomRight.y) / tileWidthM).toNumber() + 1;
        var origFirstTileY = firstTileY;

        var tilesPerXRow = lastTileX - firstTileX;
        seedingTilesOnThisLayer = tilesPerXRow * (lastTileY - firstTileY);

        // firstTileX = maxN(firstTileX, seedingUpToTileX); firstTileX cannot be capped, since it needs to start fresh on each row
        firstTileY = maxN(firstTileY, seedingUpToTileY);

        updateSeedingProgress(firstTileX, firstTileY, lastTileX, lastTileY);
        if (seedingUpToTileX == lastTileX - 1 && seedingUpToTileY == lastTileY - 1) {
            return true;
        }

        // our progress might have changed
        firstTileY = maxN(firstTileY, seedingUpToTileY);

        seedingTilesProgressForThisLayer =
            tilesPerXRow * (firstTileY - origFirstTileY) +
            tilesPerXRow -
            (lastTileX - maxN(firstTileX, seedingUpToTileX));

        var tileCache = getApp()._breadcrumbContext.tileCache;

        // we do not want to get a massive for loop that we then get killed by the watchdog
        // we also might not even fetch a tile, we need to wait until the previous set have responded
        // the we can move onto fetching the next set of tiles
        // the storage could also be very small, so we need to keep this number small
        // otherwsie we will
        // * try and download 10 tile to storage
        // * only fit the last 9 tiles in storage
        // * then we do not have all 10, so we will start again
        // ideally we would progress the storage seed based on the web handler responding with a tile
        var maxTilesAtATime = 50;
        maxTilesAtATime = minN(maxTilesAtATime, _settings.storageTileCacheSize);

        var tileStarted = 0;
        for (var y = firstTileY; y < lastTileY; ++y) {
            for (
                var x = y == firstTileY ? maxN(firstTileX, seedingUpToTileX) : firstTileX;
                x < lastTileX;
                ++x
            ) {
                var tileKey = new TileKey(x, y, seedingZ);
                if (tileCache.seedTileToStorage(tileKey)) {
                    ++tileStarted;
                }

                if (tileStarted >= maxTilesAtATime) {
                    return false;
                }
            }
        }

        return false;
    }

    (:storage)
    function updateSeedingProgress(
        firstTileX as Number,
        firstTileY as Number,
        lastTileX as Number,
        lastTileY as Number
    ) as Void {
        var tileCache = getApp()._breadcrumbContext.tileCache;

        for (var y = firstTileY; y < lastTileY; ++y) {
            for (
                var x = y == firstTileY ? maxN(firstTileX, seedingUpToTileX) : firstTileX;
                x < lastTileX;
                ++x
            ) {
                var tileKey = new TileKey(x, y, seedingZ);
                if (!tileCache._storageTileCache.haveTile(tileKey)) {
                    // we need to seed some more
                    return;
                }

                // we have the tile (may be a bad response, but we have attempted it in the past), move our progress forward
                // users should remove tile cache and start from scratch if they want to retry failed tiles
                seedingUpToTileX = x;
                seedingUpToTileY = y;
            }
        }
    }

    function seedingProgressString() as String {
        if (_settings.storageSeedBoundingBox) {
            return (
                seedingTilesProgressForThisLayer +
                "/" +
                seedingTilesOnThisLayer +
                "  (" +
                (
                    (seedingTilesProgressForThisLayer / seedingTilesOnThisLayer.toFloat()) *
                    100
                ).format("%.1f") +
                "%)"
            );
        }

        var routes = getApp()._breadcrumbContext.routes;
        if (seedingUpToRoute >= routes.size()) {
            return "Route: " + seedingUpToRoute + "/" + routes.size();
        }
        var coords = routes[seedingUpToRoute].coordinates;
        var points = coords.pointSize();
        return (
            "Route: " +
            (seedingUpToRoute + 1) +
            "/" +
            routes.size() +
            " P: " +
            seedingUpToRoutePoint +
            "/" +
            points +
            " (" +
            ((seedingUpToRoutePoint.toFloat() / points) * 100).format("%.1f") +
            "%)\n" +
            (seedingLastTileX - seedingFirstTileX) +
            " X " +
            (seedingLastTileY - seedingFirstTileY) +
            " tiles (" +
            _settings.storageSeedRouteDistanceM.format("%.1f") +
            "m)"
        );
    }
}
