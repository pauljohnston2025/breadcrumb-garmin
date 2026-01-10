import Toybox.Position;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;

const WRONG_DIRECTION_TOLERANCE_M = 2; // meters
const SKIP_FORWARD_TOLERANCE_M = 0.1; // meters (needs to be kept small, see details at usage below)

const TRACK_ID = -1;
const RESTART_STABILITY_POINT_COUNT = 10; // number of points in a row that need to be within RESTART_STABILITY_DISTANCE_M to be considered a valid course
//note: RESTART_STABILITY_POINT_COUNT should be set based on DELAY_COMPUTE_COUNT
// if DELAY_COMPUTE_COUNT = 5 seconds, 10 points give us startup checking for 50 seconds, enough time to get a lock
// max distance allowed to move to be considered a stable point (distance from previous point)
// this needs to be relatively high, since the compute interval could be set quite large, or the user could be  on a motor transport (car, bike, jetski)
// eg. at 80kmph with a 5 second compute interval (that may not run for 3 attempts, 15 seconds)
// 80000/60/60*15 = 333.333
const STABILITY_MAX_DISTANCE_M = 400;
// note: onActivityInfo is called once per second but delayed by DELAY_COMPUTE_COUNT make sure STABILITY_MAX_DISTANCE_M takes that into account
// ie human averge running speed is 3m/s if DELAY_COMPUTE_COUNT is set to 5 STABILITY_MAX_DISTANCE_M should be set to at least 15
const DELAY_COMPUTE_COUNT = 5;
// start as minimum area, and is set to the correct size as points are added
// we want a 'empty' track to not sway the calculation of what to render
// note: we cannot do a const, as it assigns the array or point by reference
function BOUNDING_BOX_DEFAULT() as [Float, Float, Float, Float] {
    return [FLOAT_MAX, FLOAT_MAX, FLOAT_MIN, FLOAT_MIN];
}
function BOUNDING_BOX_CENTER_DEFAULT() as RectangularPoint {
    return new RectangularPoint(0.0f, 0.0f, 0.0f);
}

class OffTrackInfo {
    var onTrack as Boolean;
    //  pointWeLeftTrack is already scaled to pixels
    var pointWeLeftTrack as RectangularPoint?;
    var wrongDirection as Boolean;
    function initialize(
        onTrack as Boolean,
        pointWeLeftTrack as RectangularPoint?,
        wrongDirection as Boolean
    ) {
        me.onTrack = onTrack;
        me.pointWeLeftTrack = pointWeLeftTrack;
        me.wrongDirection = wrongDirection;
    }

    function clone() as OffTrackInfo {
        var pointWeLeftTrackL = pointWeLeftTrack;
        if (pointWeLeftTrackL == null) {
            return new OffTrackInfo(onTrack, null, wrongDirection);
        }

        return new OffTrackInfo(onTrack, pointWeLeftTrackL.clone(), wrongDirection);
    }
}

class BreadcrumbTrack {
    // the data stored on this class is scaled (coordinates are prescaled since scale changes are rare - but renders occur a lot)
    // scaled coordinates will be marked with // SCALED - anything that uses them needs to take scale into account
    var lastClosePointIndex as Number?;
    var _lastDistanceToNextPoint as Float?;
    // gets updated when track data is loaded, set to first point on track
    // also gets updated whenever we calculate off track
    // there is one oddity with storing lastClosePoint, if the user gets closer to another section of the track we will keep
    // telling them to go back to where they left the track. Acceptable, since the user should do their entire planned route.
    // If they rejoin the track at another point we pick up that they are on track correctly.
    // Multi routes also makes this issue slightly more annoying, in a rare case where a user has left one route, and done another route,
    // when we get close to the first route (if we are still off track) it will snap to the last point they left the route, rather than the start.
    // such a small edge case, that I only found in a random test setup, the performance benefits of caching the lastClosePoint
    // outweigh the chances users will run into this edge case. To solve it we have to process the whole route every time,
    // though we already do this in a multi route setup, we might parse off track alerts for all the other routes then get to the one we are on.
    // single route use case is more common though, so we will optimise for that. in multi route we could store 'last route we were on'
    var lastClosePoint as RectangularPoint? = null; // SCALED (note: altitude is currently unscaled)
    var createdAt as Number = 0;
    // storageIndex is the id of the route (-1 is the in progress track)
    var storageIndex as Number = 0;
    var name as String;
    var coordinates as PointArray = new PointArray(0); // SCALED (note: altitude is currently unscaled)
    var directions as DirectionPointArray = new DirectionPointArray();
    var lastDirectionIndex as Number = -1;
    var lastDirectionSpeedPPS as Float = -1f;
    var seenStartupPoints as Number = 0;
    var possibleBadPointsAdded as Number = 0;
    var inRestartMode as Boolean = true;
    var maxDistanceMScaled as Float = STABILITY_MAX_DISTANCE_M.toFloat(); // SCALED

    var boundingBox as [Float, Float, Float, Float] = BOUNDING_BOX_DEFAULT(); // SCALED -- since the points are used to generate it on failure
    var boundingBoxCenter as RectangularPoint = BOUNDING_BOX_CENTER_DEFAULT(); // SCALED -- since the points are used to generate it on failure
    var distanceTotal as Float = 0f; // SCALED -- since the points are used to generate it on failure
    var elevationMin as Float = FLOAT_MAX; // UNSCALED
    var elevationMax as Float = FLOAT_MIN; // UNSCALED
    var _neverStarted as Boolean;

    function initialize(routeIndex as Number, name as String, initalPointCount as Number) {
        _neverStarted = true;
        createdAt = Time.now().value();
        storageIndex = routeIndex;
        coordinates = new PointArray(initalPointCount);
        self.name = name;
    }

    function reverse() as Void {
        // distanceTotal  // we can't reverse the track, (the only one tracking distance total)

        coordinates.reversePoints();
        directions.reversePoints(coordinates.pointSize());
        lastDirectionIndex = -1;
        lastDirectionSpeedPPS = -1f;
        lastClosePointIndex = null;
        _lastDistanceToNextPoint = null;
        lastClosePoint = null; // we want to recalculate off track, since the cheveron direction will change
        writeToDisk(ROUTE_KEY); // write ourselves back to storage in reverse, so next time we load (on app restart) it is correct
    }

    function settingsChanged() as Void {
        // we might have enabled/disabled searching for directions or offtrack
        // This is mainly because the turn by turn direction alerts need to know where we are on track, or fall back to using the directions themselves.
        // If we turn off 'off track' alerts calculation the turn by turn directions will think we are always at that location and will not progress.
        lastDirectionIndex = -1;
        lastDirectionSpeedPPS = -1f;
        lastClosePoint = null;
        lastClosePointIndex = null;
        _lastDistanceToNextPoint = null;
    }

    function rescale(scaleFactor as Float) as Void {
        boundingBox[0] = boundingBox[0] * scaleFactor;
        boundingBox[1] = boundingBox[1] * scaleFactor;
        boundingBox[2] = boundingBox[2] * scaleFactor;
        boundingBox[3] = boundingBox[3] * scaleFactor;
        distanceTotal = distanceTotal * scaleFactor;
        boundingBoxCenter.rescaleInPlace(scaleFactor);
        coordinates.rescale(scaleFactor);
        // directions.rescale(scaleFactor); no need to rescale they are just an angle and index into coordinates
        if (lastClosePoint != null) {
            lastClosePoint.rescaleInPlace(scaleFactor);
        }
        maxDistanceMScaled = maxDistanceMScaled * scaleFactor;
        if (_lastDistanceToNextPoint != null) {
            _lastDistanceToNextPoint = _lastDistanceToNextPoint * scaleFactor;
        }
    }

    function handleRouteV2(
        routeData as Array<Float>,
        directions as Array<Number>,
        cachedValues as CachedValues
    ) as Boolean {
        // trust the app completely
        coordinates._internalArrayBuffer = routeData;
        coordinates._size = routeData.size();
        me.directions._internalArrayBuffer = directions;
        // we could optimise this further if the app provides us with binding box, center max/min elevation
        // but it makes it really hard to add any more cached data to the route, that the companion app then has to send
        // by making these rectangular coordinates, we skip a huge amount of math converting them from lat/long
        updatePointDataFromAllPoints();
        var wrote = writeToDisk(ROUTE_KEY); // write to disk before we scale, all routes on disk are unscaled
        var currentScale = cachedValues.currentScale;
        if (currentScale != 0f) {
            rescale(currentScale);
        }
        cachedValues.recalculateAll();
        return wrote;
    }

    // writeToDisk should always be in raw meters coordinates // UNSCALED
    function writeToDisk(key as String) as Boolean {
        try {
            key = key + storageIndex;
            Storage.setValue(key + "bb", boundingBox);
            Storage.setValue(key + "bbc", [
                boundingBoxCenter.x,
                boundingBoxCenter.y,
                boundingBoxCenter.altitude,
            ]);
            Storage.setValue(
                key + "coords",
                coordinates._internalArrayBuffer as Array<PropertyValueType>
            );
            Storage.setValue(key + "coordsSize", coordinates._size);
            Storage.setValue(
                key + "directions",
                directions._internalArrayBuffer as Array<PropertyValueType>
            );
            Storage.setValue(key + "distanceTotal", distanceTotal);
            Storage.setValue(key + "elevationMin", elevationMin);
            Storage.setValue(key + "elevationMax", elevationMax);
            Storage.setValue(key + "createdAt", createdAt);
            Storage.setValue(key + "name", name);
        } catch (e) {
            // it will still be in memory, just not persisted, this is bad as the user will think it worked, so return false to indicate error
            logE("failed route save: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
            return false;
        }
        return true;
    }

    static function clearRoute(key as String, storageIndex as Number) as Void {
        key = key + storageIndex;
        // removing any key should cause it to fail to load next time, but would look weird when debugging, so remove all keys
        Storage.deleteValue(key + "bb");
        Storage.deleteValue(key + "bbc");
        Storage.deleteValue(key + "coords");
        Storage.deleteValue(key + "coordsSize");
        Storage.deleteValue(key + "directions");
        Storage.deleteValue(key + "distanceTotal");
        Storage.deleteValue(key + "elevationMin");
        Storage.deleteValue(key + "elevationMax");
        Storage.deleteValue(key + "createdAt");
        Storage.deleteValue(key + "name");
    }

    static function readFromDisk(key as String, storageIndex as Number) as BreadcrumbTrack? {
        key = key + storageIndex;
        try {
            var bb = Storage.getValue(key + "bb");
            if (bb == null) {
                return null;
            }
            var bbc = Storage.getValue(key + "bbc");
            if (bbc == null || !(bbc instanceof Array) || bbc.size() != 3) {
                return null;
            }
            var coords = Storage.getValue(key + "coords");
            if (coords == null) {
                return null;
            }

            var coordsSize = Storage.getValue(key + "coordsSize");
            if (coordsSize == null) {
                return null;
            }

            var directions = Storage.getValue(key + "directions");
            if (directions == null) {
                directions = []; // back compat
            }

            var distanceTotal = Storage.getValue(key + "distanceTotal");
            if (distanceTotal == null) {
                return null;
            }

            var elevationMin = Storage.getValue(key + "elevationMin");
            if (elevationMin == null) {
                return null;
            }

            var elevationMax = Storage.getValue(key + "elevationMax");
            if (elevationMax == null) {
                return null;
            }

            var createdAt = Storage.getValue(key + "createdAt");
            if (createdAt == null) {
                return null;
            }

            var name = Storage.getValue(key + "name");
            if (name == null || !(name instanceof String)) {
                return null;
            }

            var track = new BreadcrumbTrack(storageIndex, name, 0);
            track.boundingBox = bb as [Float, Float, Float, Float];
            if (track.boundingBox.size() != 4) {
                return null;
            }
            track.boundingBoxCenter = new RectangularPoint(
                bbc[0] as Float,
                bbc[1] as Float,
                bbc[2] as Float
            );
            track.coordinates._internalArrayBuffer = coords as Array<Float>;
            track.coordinates._size = coordsSize as Number;
            track.directions._internalArrayBuffer = directions as Array<Number>;
            track.distanceTotal = distanceTotal as Float;
            track.elevationMin = elevationMin as Float;
            track.elevationMax = elevationMax as Float;
            track.createdAt = createdAt as Number;
            if (track.coordinates.size() % ARRAY_POINT_SIZE != 0) {
                return null;
            }
            track.setInitialLastClosePoint();
            return track;
        } catch (e) {
            return null;
        }
    }

    function lastPoint() as RectangularPoint? {
        return coordinates.lastPoint();
    }

    function firstPoint() as RectangularPoint? {
        return coordinates.firstPoint();
    }

    function addLatLongRaw(lat as Float, lon as Float, altitude as Float) as Void {
        var newPoint = RectangularPoint.latLon2xy(lat, lon, altitude);
        if (newPoint == null) {
            return;
        }
        var lastPoint = lastPoint();
        if (lastPoint == null) {
            addPointRaw(newPoint, 0f);
            setInitialLastClosePoint();
            return;
        }

        var distance = lastPoint.distanceTo(newPoint);

        addPointRaw(newPoint, distance);
    }

    // new point should be in scale already
    function addPointRaw(newPoint as RectangularPoint, distance as Float) as Boolean {
        distanceTotal += distance;
        coordinates.add(newPoint);
        updateBoundingBox(newPoint);
        // todo have a local ref to settings
        if (
            coordinates.restrictPoints(
                getApp()._breadcrumbContext.settings.maxTrackPoints,
                getApp()._breadcrumbContext.cachedValues.currentScale
            )
        ) {
            // a resize occurred, calculate important data again
            updatePointDataFromAllPoints();
            // opt to remove more points then less, to ensure we get the bad point, or 1 of the good points instead
            possibleBadPointsAdded = Math.ceil(possibleBadPointsAdded / 2.0f).toNumber();
            return true;
        }

        return false;
    }

    function updatePointDataFromAllPoints() as Void {
        boundingBox = BOUNDING_BOX_DEFAULT();
        boundingBoxCenter = BOUNDING_BOX_CENTER_DEFAULT();
        elevationMin = FLOAT_MAX;
        elevationMax = FLOAT_MIN;
        distanceTotal = 0f;
        var pointSize = coordinates.pointSize();
        var prevPoint = coordinates.firstPoint();
        if (prevPoint == null) {
            return;
        }
        updateBoundingBox(prevPoint);
        for (var i = 1; i < pointSize; ++i) {
            var point = coordinates.getPoint(i);
            // should never be null, but check to be safe
            if (point == null) {
                break;
            }

            updateBoundingBox(point);
            distanceTotal += prevPoint.distanceTo(point);
            prevPoint = point;
        }
    }

    function updateBoundingBox(point as RectangularPoint) as Void {
        // tmp vars so we can inline the function and remove it
        var boundingBox0Tmp = boundingBox[0] as Float;
        var boundingBox1Tmp = boundingBox[1] as Float;
        var boundingBox2Tmp = boundingBox[2] as Float;
        var boundingBox3Tmp = boundingBox[3] as Float;

        boundingBox0Tmp = minF(boundingBox0Tmp, point.x);
        boundingBox1Tmp = minF(boundingBox1Tmp, point.y);
        boundingBox2Tmp = maxF(boundingBox2Tmp, point.x);
        boundingBox3Tmp = maxF(boundingBox3Tmp, point.y);

        boundingBox[0] = boundingBox0Tmp;
        boundingBox[1] = boundingBox1Tmp;
        boundingBox[2] = boundingBox2Tmp;
        boundingBox[3] = boundingBox3Tmp;

        elevationMin = minF(elevationMin, point.altitude);
        elevationMax = maxF(elevationMax, point.altitude);

        boundingBoxCenter = new RectangularPoint(
            boundingBox[0] + (boundingBox[2] - boundingBox[0]) / 2.0,
            boundingBox[1] + (boundingBox[3] - boundingBox[1]) / 2.0,
            0.0f
        );
    }

    // call on first start
    function onStart() as Void {
        logD("onStart");
        // check from startup, and also clear the current coordinates,
        // anything we got before start is invalid
        coordinates.clear();
        // we also need to reset the bounding box, as its only ever expanded, never reduced
        boundingBox = BOUNDING_BOX_DEFAULT();
        boundingBoxCenter = BOUNDING_BOX_CENTER_DEFAULT();
        distanceTotal = 0f;
        elevationMin = FLOAT_MAX;
        elevationMax = FLOAT_MIN;
        _neverStarted = false;
        onStartResume();
    }

    // when an activity has been stopped, and we have moved and restarted
    function onStartResume() as Void {
        if (_neverStarted) {
            onStart();
        }
        logD("onStartResume");
        // check from startup
        seenStartupPoints = 0;
        possibleBadPointsAdded = 0;
        inRestartMode = true;
    }

    function handlePointAddStartup(newPoint as RectangularPoint) as [Boolean, Boolean] {
        // general plan of this function is
        // add data to both startup array and raw array (so we can start drawing points immediately, without the need for patching both arrays together)
        // on unstable points, remove points from both arrays
        // if the main coordinates array has been sliced in half through `restrictPoints()`
        // this may remove more points than needed, but is not a huge concern
        var lastStartupPoint = coordinates.lastPoint();
        if (lastStartupPoint == null) {
            // nothing to compare against, add the point to both arrays
            return [true, addPointRaw(newPoint, 0f)];
        }

        var stabilityCheckDistance = lastStartupPoint.distanceTo(newPoint);

        // allow large distances when we have just started, we need to get the first point to work from after a resume
        if (stabilityCheckDistance > maxDistanceMScaled && possibleBadPointsAdded != 0) {
            // we are unstable, remove all our stability check points
            seenStartupPoints = 0;
            coordinates.removeLastCountPoints(possibleBadPointsAdded);
            possibleBadPointsAdded = 0;
            updatePointDataFromAllPoints();
            return [false, true];
        }

        // we are stable, see if we can break out of startup
        seenStartupPoints++;
        possibleBadPointsAdded++;
        if (seenStartupPoints == RESTART_STABILITY_POINT_COUNT) {
            inRestartMode = false;
        }

        // todo this could rescale underneath us, then we would remove the incorrect number of possibleBadPointsAdded if we get a bad point
        // have attempted to handle this on rescale, it will remove 1 extra point if it was an odd number before entering
        return [true, addPointRaw(newPoint, stabilityCheckDistance)];
    }

    function pointFromActivityInfo(activityInfo as Activity.Info) as RectangularPoint? {
        var loc = activityInfo.currentLocation;
        if (loc == null) {
            return null;
        }

        var altitude = activityInfo.altitude;
        if (altitude == null) {
            return null;
        }

        var asDeg = loc.toDegrees();
        var lat = asDeg[0].toFloat();
        var lon = asDeg[1].toFloat();

        return RectangularPoint.latLon2xy(lat, lon, altitude);
    }

    function setInitialLastClosePoint() as Void {
        var point = coordinates.getPoint(0);
        if (point != null) {
            lastClosePoint = point;
        }
    }

    function calculateDistancePointToSegment(
        pointP as RectangularPoint,
        segmentAX as Float,
        segmentAY as Float,
        segmentBX as Float,
        segmentBY as Float
    ) as [Decimal, Float, Float] {
        // Vector V = B - A
        var vx = segmentBX - segmentAX;
        var vy = segmentBY - segmentAY;
        var segmentLengthSq = vx * vx + vy * vy;

        if (segmentLengthSq == 0.0) {
            // Points A and B are the same
            // Calculate the final distance
            var xDist = pointP.x - segmentAX;
            var yDist = pointP.y - segmentAY;
            var closestDistance = Math.sqrt(xDist * xDist + yDist * yDist);
            return [closestDistance, segmentAX, segmentAY];
        }

        // --- Simplified Vector Math ---

        // Vector W = P - A
        var wx = pointP.x - segmentAX;
        var wy = pointP.y - segmentAY;

        // Dot product W . V
        var dotWV = wx * vx + wy * vy;

        // Calculate t = (W . V) / |V|^2
        var t = dotWV / segmentLengthSq;

        // Clamp t to the range [0, 1]
        var clampedT = maxF(0.0, minF(1.0, t));

        // Calculate closest point on segment: Closest = A + clampedT * V
        var closestX = segmentAX + clampedT * vx;
        var closestY = segmentAY + clampedT * vy;

        // Calculate the final distance
        var xDist = pointP.x - closestX;
        var yDist = pointP.y - closestY;
        var closestSegmentDistance = Math.sqrt(xDist * xDist + yDist * yDist);
        return [closestSegmentDistance, closestX, closestY];
    }

    function weAreStillCloseToTheLastDirectionPoint() as Boolean {
        // note: this logic is the same as in checkDirections but is only needed for when we go backwards on the path
        // so we can skip a heap of logic, checkDirections is more optimised for when it needs to check a heap more things
        var checkPoint = getApp()._breadcrumbContext.track.lastPoint();
        if (checkPoint == null) {
            return false;
        }

        var cachedValues = getApp()._breadcrumbContext.cachedValues;
        var directionsRaw = directions._internalArrayBuffer; // raw dog access means we can do the calcs much faster
        var coordinatesRaw = coordinates._internalArrayBuffer; // raw dog access means we can do the calcs much faster

        var settings = getApp()._breadcrumbContext.settings;
        var turnAlertTimeS = settings.turnAlertTimeS;
        var minTurnAlertDistanceM = settings.minTurnAlertDistanceM;

        var currentSpeedPPS = 1f; // assume a slow walk if we cannot get the current speed
        var info = Activity.getActivityInfo();
        if (info != null && info.currentSpeed != null) {
            currentSpeedPPS = info.currentSpeed as Float;
        }

        // it's in meters before this point then switches to pixels per second
        if (cachedValues.currentScale != 0f) {
            currentSpeedPPS *= cachedValues.currentScale;
        }

        if (lastDirectionIndex < 0 || lastDirectionIndex >= directions.pointSize()) {
            return false;
        }

        var oldCoordinatesIndexTemp = directionsRaw[lastDirectionIndex] & 0xffff;
        // blind trust that the phone app sent the correct data and we are not accessing out of bounds array access
        var oldLastDirectionPointDistance = distance(
            coordinatesRaw[oldCoordinatesIndexTemp * ARRAY_POINT_SIZE],
            coordinatesRaw[oldCoordinatesIndexTemp * ARRAY_POINT_SIZE + 1],
            checkPoint.x,
            checkPoint.y
        );
        // if we have slowed down still keep the larger perimeter, if we speed up when we exit the corner we also need to take the higher speed so we do not clear
        // the index and then add it straight back again when the distance increases because the speed increased
        var oldDistancePixelsCheck = turnAlertDistancePx(
            maxF(lastDirectionSpeedPPS, currentSpeedPPS),
            turnAlertTimeS,
            minTurnAlertDistanceM,
            cachedValues.currentScale
        );
        return oldLastDirectionPointDistance < oldDistancePixelsCheck;
    }

    // checkpoint should already be scaled, as should distanceCheck
    // returns [turnAngleDeg, distancePx] or null if no direction within range
    function checkDirections(
        checkPoint as RectangularPoint,
        turnAlertTimeS as Number,
        minTurnAlertDistanceM as Number,
        cachedValues as CachedValues
    ) as [Number, Float]? {
        var currentSpeedPPS = 1f; // assume a slow walk if we cannot get the current speed
        var info = Activity.getActivityInfo();
        if (info != null && info.currentSpeed != null) {
            currentSpeedPPS = info.currentSpeed as Float;
        }

        // it's in meters before this point then switches to pixels per second
        if (cachedValues.currentScale != 0f) {
            currentSpeedPPS *= cachedValues.currentScale;
        }

        var distancePixelsCheck = turnAlertDistancePx(
            currentSpeedPPS,
            turnAlertTimeS,
            minTurnAlertDistanceM,
            cachedValues.currentScale
        );
        var directionsRaw = directions._internalArrayBuffer; // raw dog access means we can do the calcs much faster
        var coordinatesRaw = coordinates._internalArrayBuffer; // raw dog access means we can do the calcs much faster
        // note: extremely short out and back sections with a single point may trigger strange alerts
        // eg.
        // - = route/track
        // | = route/track
        // * = direction turn point
        // + = standard track/route point
        //
        //         *       OUT AND BACK SECTION
        //         |
        //         |
        //         |
        //  *-----**--------- END
        //  |
        //  |
        // START
        //
        // When we come into the corner with 2 points (traveling to the right of the page), we get a turn alert (left), but then we check for the next turn alert (up to 5 points away).
        // This skips the point at the top of the page, but then checks the second point on the corner and tells us that we should then turn left (as if we were coming out of the corner).
        // All of this happens before we even turn though, so we get 2 direction alerts very close together that are confusing, then it skips the OUT AND BACK SECTION turn alert, because it
        // thinks we are already up to exiting the corner.
        //
        // Consider another case though where we intentionally skip going down the turn because we do not want to do the out and back since its so short, it should skip ahead to the next direction.

        // We also need this to work with back to back corners
        //
        // Case 2, back-to-back corners
        //      * END
        //      |
        //      |
        //      |
        //  *-*-*
        //  |
        //  |
        // START
        //
        // We need to ensure we look ahead, because although we are currently in range of the first turn we did, we want to tell the user that they are in range of another turn.
        // If off track alerts are enabled, we know when we have moved closer to the next turn, but if they are not enabled, we need to ensure the user gets the next turn alert.
        //
        // There is a third case though too, where there ar e many points leading up to the turn - we need to be able to skip over them so we can get an alert many meters from the turn
        // Case 3 - many points before turn
        //      * END
        //      |
        //      |
        //      |
        //         +
        //         *   THE TURN POINT IS THE 4th point in the corner, but its still within "Turn alert Time (s)" or "Min Turn Alert Distance (m)"
        //  *---+++
        //  |
        //  |
        // START
        //
        // So we need the lookahead, but it does not work very well for short out and back sections- we will just have to live with this. They should be rare.
        // I should probably write some unit test code for these 3 cases ...

        // longer routes with more points allow more look ahead (up to some percentage of the route)
        var allowedCoordinatePerimeter = 5;
        var oldLastClosePointIndex = lastClosePointIndex;
        var stillNearTheLastDirectionPoint = false;
        var startAt = 0;
        var oldCoordinatesIndex = -1;
        if (lastDirectionIndex >= 0 && lastDirectionIndex < directions.pointSize()) {
            startAt = lastDirectionIndex;
            var oldCoordinatesIndexTemp = directionsRaw[lastDirectionIndex] & 0xffff;
            // blind trust that the phone app sent the correct data and we are not accessing out of bounds array access
            var oldLastDirectionPointDistance = distance(
                coordinatesRaw[oldCoordinatesIndexTemp * ARRAY_POINT_SIZE],
                coordinatesRaw[oldCoordinatesIndexTemp * ARRAY_POINT_SIZE + 1],
                checkPoint.x,
                checkPoint.y
            );
            // if we have slowed down still keep the larger perimeter, if we speed up when we exit the corner we also need to take the higher speed so we do not clear
            // the index and then add it straight back again when the distance increases because the speed increased
            var oldDistancePixelsCheck = turnAlertDistancePx(
                maxF(lastDirectionSpeedPPS, currentSpeedPPS),
                turnAlertTimeS,
                minTurnAlertDistanceM,
                cachedValues.currentScale
            );
            stillNearTheLastDirectionPoint = oldLastDirectionPointDistance < oldDistancePixelsCheck;
            if (stillNearTheLastDirectionPoint) {
                // only use it if we are still close, otherwise we will get locked to this coordinate when we move forwards if we do not know our current position on the track
                oldCoordinatesIndex = oldCoordinatesIndexTemp;
            }
        }
        if (oldLastClosePointIndex != null && oldLastClosePointIndex > oldCoordinatesIndex) {
            // we are further along the track already, look for directions from here
            oldCoordinatesIndex = oldLastClosePointIndex;
        }

        // we do not know where we are on the track, either off track alerts are not enabled, or we are off track
        // in this case, we want to search all directions, since we could rejoin the track at any point
        var stopAt = directionsRaw.size();
        for (var i = startAt; i < stopAt; ++i) {
            // any points ahead of us are valid, since we have no idea where we are on the route, but don't allow points to go backwards
            var coordinatesIndex = directionsRaw[i] & 0xffff;
            if (coordinatesIndex <= oldCoordinatesIndex) {
                // skip any of the directions in the past, this should not really ever happen since we start at the index, but protect ourselves from ourselves
                continue;
            }

            if (
                oldCoordinatesIndex > 0 &&
                coordinatesIndex - oldCoordinatesIndex > allowedCoordinatePerimeter
            ) {
                // prevent any overlap of points further on in the route that go through the same intersection
                // we probably need to include a bit of padding here, since the overlap could be slightly miss-aligned
                // This is done in the loop to allow quick turns in succession to be alerted, but not the directions at the end of the route thats in the same intersection.
                // eg. a left turn followed by a right turn
                // we use the direction alert to know roughly where we are on the route
                // whilst we are within the circle of the last direction only consider the next X points
                return null;
            }

            // blind trust that the phone app sent the correct data and we are not accessing out of bounds array access
            var distancePx = distance(
                coordinatesRaw[coordinatesIndex * ARRAY_POINT_SIZE],
                coordinatesRaw[coordinatesIndex * ARRAY_POINT_SIZE + 1],
                checkPoint.x,
                checkPoint.y
            );
            if (distancePx < distancePixelsCheck) {
                lastDirectionIndex = i;
                lastDirectionSpeedPPS = currentSpeedPPS;
                // inline for perf, no function call overhead but unreadable :(
                var angle = ((directionsRaw[i] & 0xffff0000) >> 16) - 180;
                // by the time we get here we have parsed all the off track calculations and direction checks
                // if this takes some time (seconds) the distance we get could be off, as the user has traveled closer to the intersection
                // so we get the users location and calculate it from where they currently are
                var distanceM = getCurrentDistanceToDirection(
                    coordinatesRaw[coordinatesIndex * ARRAY_POINT_SIZE],
                    coordinatesRaw[coordinatesIndex * ARRAY_POINT_SIZE + 1],
                    distancePx,
                    cachedValues
                );
                return [angle, distanceM];
            }
        }

        if (!stillNearTheLastDirectionPoint) {
            // consider all directions again, we have moved outside the perimeter of the last direction
            // this is so we can rejoin at the start
            lastDirectionIndex = -1;
            lastDirectionSpeedPPS = -1f;
        }
        return null;
    }

    function getCurrentDistanceToDirection(
        xPx as Float,
        yPx as Float,
        distancePx as Float,
        cachedValues as CachedValues
    ) as Float {
        if (cachedValues.currentScale == 0f) {
            return distancePx;
        }

        var info = Activity.getActivityInfo();
        if (info == null) {
            return distancePx / cachedValues.currentScale;
        }
        var currentPoint = pointFromActivityInfo(info);
        if (currentPoint == null || !currentPoint.valid()) {
            return distancePx / cachedValues.currentScale;
        }

        return distance(
            xPx / cachedValues.currentScale,
            yPx / cachedValues.currentScale,
            currentPoint.x,
            currentPoint.y
        );
    }

    function updateOffTrackInfo(
        newIndex as Number,
        checkPoint as RectangularPoint,
        nextX as Float,
        nextY as Float,
        distToSegmentAndSegPoint as [Decimal, Float, Float]
    ) as OffTrackInfo {
        var oldLastClosePointIndex = lastClosePointIndex;
        var oldLastDistanceToNextPoint = _lastDistanceToNextPoint;

        // if the index goes backwards, we are moving backwards
        var wrongDirection = oldLastClosePointIndex != null && oldLastClosePointIndex > newIndex;
        // needed for breakpoints in debug
        // if (wrongDirection) {
        //     logD("wrong direction");
        // }

        // Calculate distance to the next point (the end of the current segment)
        var newDistanceToEnd = distance(
            distToSegmentAndSegPoint[1],
            distToSegmentAndSegPoint[2],
            nextX,
            nextY
        );

        var currentScale = getApp()._breadcrumbContext.cachedValues.currentScale;
        var scaleMultiplier = currentScale;
        if (scaleMultiplier == 0f) {
            scaleMultiplier = 1f;
        }

        // Check for wrong direction on the *same* segment
        if (
            oldLastClosePointIndex != null &&
            oldLastClosePointIndex == newIndex &&
            oldLastDistanceToNextPoint != null &&
            // prevent any float rounding errors, and make sure they have gone back by at least some amount
            newDistanceToEnd >
                oldLastDistanceToNextPoint + WRONG_DIRECTION_TOLERANCE_M * scaleMultiplier
        ) {
            wrongDirection = true;
        }

        // Store the new distance and index for the next check
        _lastDistanceToNextPoint = newDistanceToEnd;
        lastClosePointIndex = newIndex;
        lastClosePoint = new RectangularPoint(
            distToSegmentAndSegPoint[1],
            distToSegmentAndSegPoint[2],
            0f
        );

        if (wrongDirection) {
            // only reset this if we have left the radius area
            // we do not want to reset if we are still near the last direction point, because that would make us get multiple alerts. One for the wrong direction, and then another one for the turn.
            if (!weAreStillCloseToTheLastDirectionPoint()) {
                lastDirectionIndex = -1; // reset direction alerts
                lastDirectionSpeedPPS = -1f;
            }
        }
        return new OffTrackInfo(true, lastClosePoint, wrongDirection);
    }

    // checkpoint should already be scaled, as should distanceCheck
    function checkOffTrack(checkPoint as RectangularPoint, distanceCheck as Float) as OffTrackInfo {
        // logD("checking off track: " + storageIndex);
        // the big annoying thing with off track alerts is that routes do not have evenly spaced points
        // if the route goes in a straight line, there is only 2 points, these can be further than the alert distance
        // larger routes also have further spaced apart points (since we are limited to 500ish points per route to be able to transfer them from phone)
        // this means we could be on track, but between 2 points
        // this makes the calculation significantly harder :(, since we have to draw a line between each set of points and see if the user is
        // within some limit of that line
        var sizeRaw = coordinates.size();
        if (sizeRaw < 2) {
            return new OffTrackInfo(false, lastClosePoint, false);
        }

        var endSecondScanAtRaw = sizeRaw;
        var coordinatesRaw = coordinates._internalArrayBuffer; // raw dog access means we can do the calcs much faster (and do not need to create a point with altitude)
        if (lastClosePointIndex != null) {
            var lastClosePointRawStart = lastClosePointIndex * ARRAY_POINT_SIZE;
            // note: this algorithm will likely fail if the user is doing the track in the opposite direction
            // but we resort to scanning all the points below anyway
            // this for loop is optimised for on track, and navigating in the direction of the track
            // it should result in only a single iteration in most cases, as they get closer to the next point
            // we need at least 2 points of reference to be able to iterate the for loop,
            // if we were the second to last point the for loop will never run
            if (lastClosePointRawStart <= sizeRaw - 2 * ARRAY_POINT_SIZE) {
                endSecondScanAtRaw = lastClosePointRawStart + ARRAY_POINT_SIZE; // the second scan needs to include endSecondScanAtRaw, or we would skip a point in the overlap
                var lastPointX = coordinatesRaw[lastClosePointRawStart];
                var lastPointY = coordinatesRaw[lastClosePointRawStart + 1];
                for (
                    var i = lastClosePointRawStart + ARRAY_POINT_SIZE;
                    i < sizeRaw;
                    i += ARRAY_POINT_SIZE
                ) {
                    var nextX = coordinatesRaw[i];
                    var nextY = coordinatesRaw[i + 1];

                    var distToCurrentSegmentAndPoint = calculateDistancePointToSegment(
                        checkPoint,
                        lastPointX,
                        lastPointY,
                        nextX,
                        nextY
                    );

                    if (distToCurrentSegmentAndPoint[0] < distanceCheck) {
                        // We are on track relative to the current segment.
                        // BUT, let's check if we are even closer to the NEXT segment.

                        // If we do not do this, then on tight switch backs we will think we are still on the old segment, and then a wrong direction alert will trigger
                        //
                        // ie.
                        // * = users last position (where the last off track info computed it thought we were)
                        // U = users current position
                        // + = the current projected position for the user (its further away from the corner - this will trigger wrong direction alert)
                        //
                        //
                        //  *\
                        //  | \
                        //  +  U
                        //  |
                        //
                        // The nextSegmentIndex check makes sure we jump ahead to the next segment if we can, eg.
                        //
                        //  *\
                        //  | \
                        //  |  +U
                        //  |
                        var nextSegmentIndex = i + ARRAY_POINT_SIZE;
                        if (nextSegmentIndex < sizeRaw) {
                            var nextSegmentNextX = coordinatesRaw[nextSegmentIndex];
                            var nextSegmentNextY = coordinatesRaw[nextSegmentIndex + 1];

                            var distToNextSegmentAndPoint = calculateDistancePointToSegment(
                                checkPoint,
                                nextX, // Start of next segment
                                nextY, // Start of next segment
                                nextSegmentNextX,
                                nextSegmentNextY
                            );

                            var currentScale =
                                getApp()._breadcrumbContext.cachedValues.currentScale;
                            var scaleMultiplier = currentScale;
                            if (scaleMultiplier == 0f) {
                                scaleMultiplier = 1f;
                            }

                            // If we are closer to the next segment, use that one instead.
                            // eg. distToNextSegmentAndPoint[0] - distToCurrentSegmentAndPoint[0]
                            //     20.5 - 20 = 0.5  // if its pretty close we can also use it, as long as its also less than distanceCheck eg. if it were 30 away it would be too far, but might still be less than the tolerance
                            //     20 - 20.5 = -0.5 if its larger the values go negative - excellent we are closer
                            // we cannot have too much of a tolerance though for out and back graphs, it could incorrectly jump forward many times (would also need high alert check interval)
                            // eg.
                            // x = track point
                            //  x
                            //  | \
                            //  x  x
                            //  |  |
                            //  U
                            //
                            // As the user travels up the page on segment (1) they get closer to the 'x' point, which could jump forward to the next segment (2). If we check again instantly, it could jump forwards to the next segment (3), and then again jump to segment (4)
                            // But the user is still traveling up the page, so when they actually reach segment (2) we then think they are going backwards in the wrong direction because we incorrectly jumped forwards to segments (2,3,4).
                            // To prevent this we should choose larger values for check interval, and have a really small SKIP_FORWARD_TOLERANCE_M.
                            // setting SKIP_FORWARD_TOLERANCE_M = 0 results in essentially the same old code 'distToNextSegmentAndPoint[0] <= distToCurrentSegmentAndPoint[0]' note: its '<=' and not just '<'.
                            // Checking just '<' can result in wrong direction alerts too because it will never switch to the second segment if they are colinear, and then look like we are going backwards.
                            var compareDistance =
                                distToNextSegmentAndPoint[0] - distToCurrentSegmentAndPoint[0];
                            if (
                                distToNextSegmentAndPoint[0] < distanceCheck &&
                                compareDistance < SKIP_FORWARD_TOLERANCE_M * scaleMultiplier
                            ) {
                                return updateOffTrackInfo(
                                    i / ARRAY_POINT_SIZE, // Index of the next segment's START point
                                    checkPoint,
                                    nextSegmentNextX,
                                    nextSegmentNextY,
                                    distToNextSegmentAndPoint
                                );
                            }
                        }

                        // Otherwise, the current segment is the best fit.
                        return updateOffTrackInfo(
                            (i - ARRAY_POINT_SIZE) / ARRAY_POINT_SIZE,
                            checkPoint,
                            nextX,
                            nextY,
                            distToCurrentSegmentAndPoint
                        );
                    }

                    lastPointX = nextX;
                    lastPointY = nextY;
                }
            }
            lastClosePointIndex = null; // we have to search the start of the range now
            _lastDistanceToNextPoint = null; // we need to also reset the wrong direction tracking, we do not want it to go backwards when we rejoin the track
        }

        var lastPointX = coordinatesRaw[0];
        var lastPointY = coordinatesRaw[1];
        // The below for loop only runs when we are off track, or when the user is navigating the track in the reverse direction
        // so we need to check which point is closest, rather than grabbing the last point we left the track.
        // Because that could default to a random spot on the track, or the start of the track that is further away.
        var lastClosestX = lastPointX;
        var lastClosestY = lastPointY;
        var lastClosestDist = FLOAT_MAX;
        for (var i = ARRAY_POINT_SIZE; i < endSecondScanAtRaw; i += ARRAY_POINT_SIZE) {
            var nextX = coordinatesRaw[i];
            var nextY = coordinatesRaw[i + 1];

            var distToSegmentAndSegPoint = calculateDistancePointToSegment(
                checkPoint,
                lastPointX,
                lastPointY,
                nextX,
                nextY
            );
            if (distToSegmentAndSegPoint[0] < distanceCheck) {
                return updateOffTrackInfo(
                    (i - ARRAY_POINT_SIZE) / ARRAY_POINT_SIZE,
                    checkPoint,
                    nextX,
                    nextY,
                    distToSegmentAndSegPoint
                );
            }

            if (distToSegmentAndSegPoint[0] < lastClosestDist) {
                lastClosestDist = distToSegmentAndSegPoint[0];
                lastClosestX = distToSegmentAndSegPoint[1];
                lastClosestY = distToSegmentAndSegPoint[2];
            }

            lastPointX = nextX;
            lastPointY = nextY;
        }

        lastClosePoint = new RectangularPoint(lastClosestX, lastClosestY, 0f);
        return new OffTrackInfo(false, lastClosePoint, false); // we are not on track, therefore cannot be traveling in reverse
    }

    // returns [if a new point was added to the track, if a complex operation occurred]
    function onActivityInfo(newScaledPoint as RectangularPoint) as [Boolean, Boolean] {
        // todo only call this when a point is added (some points are skipped on smaller distances)
        // _breadcrumbContext.mapRenderer.loadMapTilesForPosition(newPoint, _breadcrumbContext.breadcrumbRenderer._currentScale);

        if (inRestartMode) {
            return handlePointAddStartup(newScaledPoint);
        }

        var lastPoint = lastPoint();
        if (lastPoint == null) {
            // startup mode should have set at least one point, revert to startup mode, something has gone wrong
            onStartResume();
            return [false, false];
        }

        var distance = lastPoint.distanceTo(newScaledPoint);
        if (distance > maxDistanceMScaled) {
            // it's too far away, and likely a glitch
            return [false, false];
        }

        return [true, addPointRaw(newScaledPoint, distance)];
    }
}
