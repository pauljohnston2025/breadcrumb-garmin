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
        // System.println("" + Time.now().value() + " lonRect: " + lonRect.format("%.3f") + " latRect: " + latRect.format("%.3f"));
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
    function restrictPointsToMaxMemory(maxPoints as Number) as Void {
        restrictPoints(maxPoints);
        // memory may double when doing this, but its only on setting change
        _internalArrayBuffer = _internalArrayBuffer.slice(0, maxPoints * ARRAY_POINT_SIZE);
    }

    function restrictPoints(maxPoints as Number) as Boolean {
        // make sure we only have an acceptable amount of points
        // current process is to cull every second point
        // this means near the end of the track, we will have lots of close points
        // the start of the track will start getting more and more granular every
        // time we cull points
        if (_size / ARRAY_POINT_SIZE < maxPoints) {
            return false;
        }

        // we need to do this without creating a new array, since we do not want to
        // double the memory size temporarily
        // slice() will create a new array, we avoid this by using our custom class
        var i = 0;
        var j = 0;
        for (i = 0, j = 0; i < _size; i += ARRAY_POINT_SIZE * 2, j += ARRAY_POINT_SIZE) {
            _internalArrayBuffer[j] = _internalArrayBuffer[i];
            _internalArrayBuffer[j + 1] = _internalArrayBuffer[i + 1];
            _internalArrayBuffer[j + 2] = _internalArrayBuffer[i + 2];
        }

        resize(j);
        logD("restrictPoints occurred");
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
