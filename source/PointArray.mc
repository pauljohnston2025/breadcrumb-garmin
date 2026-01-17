import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;
import Toybox.System;
import Toybox.Time;

const ARRAY_POINT_SIZE = 3;

// cached values
// we should probably do this per latitude to get an estimate and just use a lookup table
const _lonConversion as Float = 20037508.34f / 180.0f;
const _pi360 as Float = Math.PI / 360.0f;
const _pi180 as Float = Math.PI / 180.0f;

class RectangularPoint {
    var x as Float;
    var y as Float;
    var altitude as Float;

    function initialize(_x as Float, _y as Float, _altitude as Float) {
        x = _x;
        y = _y;
        altitude = _altitude;
    }

    function distanceTo(point as RectangularPoint) as Float {
        return distance(point.x, point.y, x, y);
    }

    function valid() as Boolean {
        return !isnan(x) && !isnan(y) && !isnan(altitude);
    }

    function toString() as String {
        return "RectangularPoint(" + x + " " + y + " " + altitude + ")";
    }

    function clone() as RectangularPoint {
        return new RectangularPoint(x, y, altitude);
    }

    function rescale(scaleFactor as Float) as RectangularPoint {
        // unsafe to call with nulls or 0, checks should be made in parent
        return new RectangularPoint(x * scaleFactor, y * scaleFactor, altitude);
    }

    function rescaleInPlace(scaleFactor as Float) as Void {
        // unsafe to call with nulls or 0, checks should be made in parent
        x *= scaleFactor;
        y *= scaleFactor;
    }

    // inverse of https://gis.stackexchange.com/a/387677
    // Converting lat, lon (epsg:4326) into EPSG:3857
    // this function needs to exactly match Point.convert2XY on the companion app
    static function latLon2xy(lat as Float, lon as Float, altitude as Float) as RectangularPoint? {
        var latRect = (Math.ln(Math.tan((90 + lat) * _pi360)) / _pi180) * _lonConversion;
        var lonRect = lon * _lonConversion;

        var point = new RectangularPoint(lonRect.toFloat(), latRect.toFloat(), altitude);
        if (!point.valid()) {
            return null;
        }

        return point;
    }

    // should be the inverse of latLon2xy ie. https://gis.stackexchange.com/a/387677
    static function xyToLatLon(x as Float, y as Float) as [Float, Float]? {
        // Inverse Mercator projection formulas
        var lon = x / _lonConversion; // Longitude (degrees)
        var lat = Math.atan(Math.pow(Math.E, (y / _lonConversion) * _pi180)) / _pi360 - 90;

        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
            // logE("Invalid lat/lon values: " + lat + " " + lon);
            return null;
        }

        return [lat.toFloat(), lon.toFloat()];
    }
}

// this is to solve the issue of slice() returning a new array
// we want to instead allocate teh array to a max length, the just remove the last elements
// ie. bigArray = bigArray.slice(0, 100) will result in bigArray + 100 extra items until big array is garbage collected
// this class allows us to just reduce bigArray to 100 elements in one go
class PointArray {
    // some stats on using byte array over array<float, float, float>
    // before changes (using array<float, float, float>)
    // Application Code: 100702
    // Application Data: 26192
    // route size:
    //  total: 6575
    //  coordinates._internalArrayBuffer: 5745
    //  directions // NA not sent on v2 payload (111 bytes of just the object)
    //
    // after changes (_internalArrayBufferBytes as ByteArray)
    // Application Code: 102427
    // Application Data: 26227
    // route size:
    //  total: 6677
    //  coordinates._internalArrayBufferBytes: 4599
    //  directions: 1263

    // note: the same route with no directions is a total of 5309 (1200 bytes saved, but we are now able to use them for direction storage)
    //
    // so we use ~100 bytes more per route/track (but the directions are included) - negligible (net 0 gain)
    // code size goes up by quite a bit though, 1725 bytes of extra code for a saving of 1200 per route (assuming we have at least 1 route active and the current track this is a net saving of 675 bytes)
    // for users that do not have routes, this is actually a negative, but thats not our normal use case
    // for users trying to have 3 large route, this is a very good thing (saves 3075 bytes)
    // but don't forget, we have added directions support, so we actually have used more memory overall (1700bytes code space), but gained a new feature.

    // but now i think we get watchdog errors, before it was memory errors though :(
    // we get watchdog errors on 3 large routes ~400 points and thats without a track
    // watchdog errors were in the rescale method, a relatively simple algorithm but now it has to do `x.encodeNumber(x.decodeNumber() * scale)` instead of just `x[i] = x[i] * scale`;
    // buts its also rescaling all the directions, so maybe its just the fact that we are at 400coords + 100 directions per route.

    // So after alot of testing I have decided to reverse the 'optimised byte array' changes
    // This is because although they are good for each route/track memory footprint, they are bad for code size (which is loaded into ram)
    // Its also bad for readability and finally the cpu hit is too high, causing watchdog errors
    // The watchdog errors are the one to be afraid of, they cannot be fixed and happen later on in the app lifecycle (it's much easier to test if a route/track memory footprint works as the app crashes straight away)
    // With memory optimised method I can only get at max 1150-1200 (1200 was rare and think it crashed) points across all routes/track before I start getting watchdog errors
    // With the high memory low cpu method the memory becomes the limiting factor
    // I can achieve 1443 points with the _internalArrayBuffer as Array<Float> which is enough for 3 full routes with directions, but don't forget about the track
    // note: This seems to be the real limit, as this gets watchdog errors at this point (off track calculations are huge)
    // So we should be able to do nearly 250 coordinates and 100 directions and have 3 routes, and a track 400*3 * 300 = 1500 points (though I think 100 directions is quite high)
    // This is only for worst case when we have 3 routes loaded (general use case is one route and 1 track) so it will easily fit 400coords per track and  route and 100 directions = 900 points
    // users could also get creative and send some of the routes without directions (swimming leg of triathlon)

    // (_internalArrayBuffer as as Array<Float>, same for directions (they are now reverted) ~400 coordinates ~100 directions
    // Application Code: 101836
    // Application Data: 25821
    // route size:
    //  total: 8375
    //  coordinates._internalArrayBufferBytes: 5835
    //  directions: 2031

    // Trying to send more than 400 points seems to break on the ble send, so we are also limited there
    // Ths indicates that the user will have to pick how they want to distribute the 400 points per route they could do 300 points and 100 directions or 400 points and 0 directions.
    // or they could choose a lot lower point limit so they can have more routes overall

    // consider statically allocating the full size straight away (prevents re-mallocs in the underlying cpp code)
    var _internalArrayBuffer as Array<Float> = [];
    var _size as Number = 0;

    // not used, since wqe want to do optimised reads from the raw array
    // function get(i as Number) as Float
    // {
    //   return _internalArrayBuffer[i];
    // }

    function initialize(initalPointCount as Number) {
        // the idea of setting the size is for the track, but the track will not be full (so its only a memory space test, not a watchdog test)
        // if we add an extra route we can test the watchdog effects on scaleing etc (to ensure it can do routes + the track)
        // but an extra route may OOM if we also have the track fully allocaed in advance
        _internalArrayBuffer = new [initalPointCount * ARRAY_POINT_SIZE] as Array<Float>;
        _size = 0;
    }

    function rescale(scaleFactor as Float) as Void {
        logT("rescale");
        // unsafe to call with nulls or 0, checks should be made in parent
        // size is guaranteed to be a multiple of ARRAY_POINT_SIZE
        for (var i = 0; i < _size; i += ARRAY_POINT_SIZE) {
            _internalArrayBuffer[i] = _internalArrayBuffer[i] * scaleFactor;
            _internalArrayBuffer[i + 1] = _internalArrayBuffer[i + 1] * scaleFactor;
        }
    }

    function add(point as RectangularPoint) as Void {
        _add(point.x);
        _add(point.y);
        _add(point.altitude);
    }

    function removeLastCountPoints(count as Number) as Void {
        resize(_size - count * ARRAY_POINT_SIZE);
    }

    function lastPoint() as RectangularPoint? {
        return getPoint(_size / ARRAY_POINT_SIZE - 1); // stack overflow if we call pointSize()
    }

    function firstPoint() as RectangularPoint? {
        return getPoint(0);
    }

    function getPoint(i as Number) as RectangularPoint? {
        if (i < 0) {
            return null;
        }

        if (i >= _size / ARRAY_POINT_SIZE) {
            return null;
        }

        var offset = i * ARRAY_POINT_SIZE;
        return new RectangularPoint(
            _internalArrayBuffer[offset],
            _internalArrayBuffer[offset + 1],
            _internalArrayBuffer[offset + 2]
        );
    }

    // similar to restrictPoints, but also makes sure the underlying array buffer is fixed to that size too
    function restrictPointsToMaxMemory(
        maxPoints as Number,
        trackPointReductionMethod as Number,
        currentScale as Float
    ) as Void {
        restrictPoints(maxPoints, trackPointReductionMethod, currentScale);
        // memory may double when doing this, but its only on setting change
        _internalArrayBuffer = _internalArrayBuffer.slice(0, maxPoints * ARRAY_POINT_SIZE);
        if (_size > maxPoints) {
            logE("size was incorrect? how did this happen");
            // this is never meant to happen, but we will push on by resetting the points array if it does
            _size = 0;
        }
    }

    function restrictPoints(
        maxPoints as Number,
        trackPointReductionMethod as Number,
        currentScale as Float
    ) as Boolean {
        if (trackPointReductionMethod == TRACK_POINT_REDUCTION_METHOD_DOWNSAMPLE) {
            return restrictPointsDecimation(maxPoints);
        }

        if (restrictPointsReumannWitkam(maxPoints, currentScale)) {
            // be sure we have removed enough to meet our memory limit requirements
            restrictPointsDecimation(maxPoints);
            return true;
        }

        // we might not have found any points we can eliminate through our first method, but we might still have too many
        return restrictPointsDecimation(maxPoints);
    }

    // Simplified Line Simplification (Reumann-Witkam variant)
    // This is O(n) and won't crash the stack.
    const minCosTheta = 0.819f; // Corresponds to ~35 degrees (Math.cos(35 * PI / 180))
    function restrictPointsReumannWitkam(maxPoints as Number, currentScale as Float) as Boolean {
        var currentPoints = pointSize();
        if (currentPoints < maxPoints) {
            return false;
        }

        if (currentPoints <= 1) {
            return false; // we don't have any points, user must have set maxPoints really low (0 or negative)
        }
        // if (currentPoints % 2) {
        //     // hack run the algo every second time, strip points constantly - for testing
        //     // need to also comment out the above 2 if checks
        //     return false;
        // }

        System.println(
            "" + Time.now().value() + " restrictPointsReumannWitkam starting: " + currentPoints
        );

        // --- STAGE 1: Single-Pass Linear Simplification ---
        // Tolerance: how many meters can a point deviate from a straight line
        // before we consider it a 'corner'. 1.0 - 2.0 is usually safe for GPS.
        var toleranceMeters = 5f;
        var tolerancePixels = toleranceMeters;
        var tooCloseDistanceMeters = 7f;
        var tooCloseDistancePixels = tooCloseDistanceMeters;
        if (currentScale != 0.0f) {
            tolerancePixels = toleranceMeters * currentScale;
            tooCloseDistancePixels = tooCloseDistanceMeters * currentScale;
        }
        var toleranceSq = tolerancePixels * tolerancePixels;
        var tooCloseDistancePixelsSq = tooCloseDistancePixels * tooCloseDistancePixels;
        // logT("currentScale: " + currentScale + " tooCloseDistancePixelsSq: " + tooCloseDistancePixelsSq);

        var writeIdx = 1; // Always keep first point
        var anchorIdx = 0; // The 'start' of our current straight line segment
        var nextIdx = 1; // Point B (defines the direction)

        // We use the 2nd point to define our initial direction
        for (var i = 2; i < currentPoints; i++) {
            var a = anchorIdx * ARRAY_POINT_SIZE;
            var b = nextIdx * ARRAY_POINT_SIZE; // The candidate for the 'end' of the line
            var p = i * ARRAY_POINT_SIZE; // The current point we are testing

            // Get coordinates
            var ax = _internalArrayBuffer[a];
            var ay = _internalArrayBuffer[a + 1];
            var bx = _internalArrayBuffer[b];
            var by = _internalArrayBuffer[b + 1];
            var px = _internalArrayBuffer[p];
            var py = _internalArrayBuffer[p + 1];

            // Calculate perpendicular distance from Point P to line segment AB
            // Formula: dist = |(y2-y1)x0 - (x2-x1)y0 + x2y1 - y2x1| / sqrt(dist_sq_AB)
            // 1. Perpendicular Check (Standard Reumann-Witkam) (Vector-based)
            var dx1 = bx - ax;
            var dy1 = by - ay;
            var dx2 = px - bx;
            var dy2 = py - by;

            // Vector from Anchor (A) to Point (P)
            var dpx = px - ax;
            var dpy = py - ay;

            var distSqAB = dx1 * dx1 + dy1 * dy1;
            var devSq = 0.0f;

            if (distSqAB != 0.0f) {
                // Standard 2D Cross Product of vectors AP and AB
                // This represents the area of the parallelogram formed by the vectors
                var area = dpx * dy1 - dpy * dx1;
                devSq = (area * area) / distSqAB;
            }

            // 2. Angle Guard: Don't kill sharp corners
            var isSharpTurn = false;
            var distAB = Math.sqrt(distSqAB);
            var distBP = Math.sqrt(dx2 * dx2 + dy2 * dy2);

            if (distAB > 0.1 && distBP > 0.1) {
                // Dot product / (magA * magB) = cos(theta)
                var cosTheta = (dx1 * dx2 + dy1 * dy2) / (distAB * distBP);
                if (cosTheta < minCosTheta) {
                    isSharpTurn = true;
                }
            }

            // If points are too close, just skip them and wait for a point further away to define the line.
            if (distSqAB < tooCloseDistancePixelsSq && !isSharpTurn) {
                nextIdx = i;
                continue;
            }

            // Trigger a key point if we strayed too far OR if we changed direction
            // devSq > toleranceSq -- If the point deviates too much, the PREVIOUS point (i-1) was a corner
            // logT("devSq: " + devSq + " toleranceSq: " + toleranceSq);
            if (devSq > toleranceSq || isSharpTurn) {
                var w = writeIdx * ARRAY_POINT_SIZE;
                var target = (i - 1) * ARRAY_POINT_SIZE;

                _internalArrayBuffer[w] = _internalArrayBuffer[target];
                _internalArrayBuffer[w + 1] = _internalArrayBuffer[target + 1];
                _internalArrayBuffer[w + 2] = _internalArrayBuffer[target + 2];

                anchorIdx = i - 1;
                nextIdx = i;
                writeIdx++;
            }
        }

        // Always add the absolute last point
        var last = (currentPoints - 1) * ARRAY_POINT_SIZE;
        var wf = writeIdx * ARRAY_POINT_SIZE;
        _internalArrayBuffer[wf] = _internalArrayBuffer[last];
        _internalArrayBuffer[wf + 1] = _internalArrayBuffer[last + 1];
        _internalArrayBuffer[wf + 2] = _internalArrayBuffer[last + 2];
        writeIdx++;

        resize(writeIdx * ARRAY_POINT_SIZE);
        System.println(
            "" + Time.now().value() + " restrictPointsReumannWitkam ended: " + pointSize()
        );
        logD("restrictPointsReumannWitkam occurred");
        return true;
    }

    function restrictPointsDecimation(maxPoints as Number) as Boolean {
        // make sure we only have an acceptable amount of points
        // current process is to cull every second point
        // this means near the end of the track, we will have lots of close points
        // the start of the track will start getting more and more granular every
        // time we cull points
        var currentPoints = _size / ARRAY_POINT_SIZE;

        if (currentPoints < maxPoints) {
            return false;
        }

        if (currentPoints <= 1) {
            return false; // we don't have any points, user must have set maxPoints really low (0 or negative)
        }

        System.println("" + Time.now().value() + " restrictPointsDecimation starting");

        // Always preserve the last point
        var lastPoint = lastPoint();

        var decimationFactor = currentPoints / maxPoints;

        if (decimationFactor < 2) {
            decimationFactor = 2;
        }

        var stepSize = decimationFactor * ARRAY_POINT_SIZE;

        // we need to do this without creating a new array, since we do not want to
        // double the memory size temporarily
        // slice() will create a new array, we avoid this by using our custom class
        var j = 0;
        // Iterate and cull every second point, but exclude the original last point from the loop
        var sizeWithoutLastPoint = _size - ARRAY_POINT_SIZE;
        for (var i = 0; i < sizeWithoutLastPoint; i += stepSize) {
            _internalArrayBuffer[j] = _internalArrayBuffer[i];
            _internalArrayBuffer[j + 1] = _internalArrayBuffer[i + 1];
            _internalArrayBuffer[j + 2] = _internalArrayBuffer[i + 2];
            j += ARRAY_POINT_SIZE;
        }

        resize(j);

        // Now, add the preserved last point to the end of the culled array
        if (lastPoint != null) {
            add(lastPoint);
        }

        System.println("" + Time.now().value() + " restrictPointsDecimation ended");
        logD("restrictPointsDecimation occurred");
        return true;
    }

    function reversePoints() as Void {
        var pointsCount = pointSize();
        if (pointsCount <= 1) {
            return;
        }

        for (
            var leftIndex = -1, rightIndex = _size - ARRAY_POINT_SIZE;
            leftIndex < rightIndex;
            rightIndex -= ARRAY_POINT_SIZE /*left increment done in loop*/
        ) {
            // hard code instead of for loop to hopefully optimise better
            var rightIndex0 = rightIndex;
            var rightIndex1 = rightIndex + 1;
            var rightIndex2 = rightIndex + 2;
            ++leftIndex;
            var temp = _internalArrayBuffer[leftIndex];
            _internalArrayBuffer[leftIndex] = _internalArrayBuffer[rightIndex0];
            _internalArrayBuffer[rightIndex0] = temp;

            ++leftIndex;
            temp = _internalArrayBuffer[leftIndex];
            _internalArrayBuffer[leftIndex] = _internalArrayBuffer[rightIndex1];
            _internalArrayBuffer[rightIndex1] = temp;

            ++leftIndex;
            temp = _internalArrayBuffer[leftIndex];
            _internalArrayBuffer[leftIndex] = _internalArrayBuffer[rightIndex2];
            _internalArrayBuffer[rightIndex2] = temp;
        }

        logD("reversePoints occurred");
    }

    function _add(item as Float) as Void {
        if (_size < _internalArrayBuffer.size()) {
            _internalArrayBuffer[_size] = item;
            ++_size;
            return;
        }

        _internalArrayBuffer.add(item);
        _size = _internalArrayBuffer.size();
    }

    // the raw size
    function size() as Number {
        return _size;
    }

    // the number of points
    function pointSize() as Number {
        return _size / ARRAY_POINT_SIZE;
    }

    function resize(size as Number) as Void {
        if (size > _internalArrayBuffer.size()) {
            throw new Exception();
        }

        if (size < 0) {
            size = 0;
        }

        _size = size;
    }

    function clear() as Void {
        resize(0);
    }
}

// a flat array for memory perf Array<Float> where Array[0] = X1 Array[1] = Y1 etc. similar to the coordinates array
// [xLatRect, YLatRect, angleToTurnDegrees (-180 to 180), coordinatesIndex]
class DirectionPointArray {
    // we pack the turn angle direction and the index into a single number to save memory space, index is the only variabl frequently access, so its stored in the lower 16 bits
    // ie.
    // index = _internalArrayBuffer[i] & 0x0000FFFF
    // angleDeg (-180 to 180) = ((_internalArrayBuffer[i] & 0xFFFF0000) >> 16) - 180
    var _internalArrayBuffer as Array<Number> = new [0] as Array<Number>;

    function reversePoints(coordinatesPointSize as Number) as Void {
        var pointsCount = pointSize();
        if (pointsCount <= 1) {
            return;
        }

        for (
            var leftIndex = -1, rightIndex = size() - 1;
            leftIndex < rightIndex;
            --rightIndex /*left increment done in loop*/
        ) {
            // hard code instead of for loop to hopefully optimise better
            var rightIndex0 = rightIndex;
            ++leftIndex;
            // the angle must be flipped, and the index now starts from the opposite end of the array
            var left = _internalArrayBuffer[leftIndex];
            var leftCoordIndex = left & 0x0000ffff;
            var leftAngle = ((left & 0xffff0000) >> 16) - 180;
            var right = _internalArrayBuffer[rightIndex0];
            var rightCoordIndex = right & 0x0000ffff;
            var rightAngle = ((right & 0xffff0000) >> 16) - 180;
            _internalArrayBuffer[leftIndex] =
                ((-rightAngle + 180) << 16) | (coordinatesPointSize - 1 - rightCoordIndex);
            _internalArrayBuffer[rightIndex0] =
                ((-leftAngle + 180) << 16) | (coordinatesPointSize - 1 - leftCoordIndex);
        }

        logD("reverseDirectionPoints occurred");
    }

    // the raw size
    function size() as Number {
        return _internalArrayBuffer.size();
    }

    // the number of points
    function pointSize() as Number {
        return size();
    }
}
