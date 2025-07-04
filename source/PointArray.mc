import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;
import Toybox.System;

const ARRAY_POINT_SIZE = 3;

// cached values
// we should probbaly do this per latitude to get an estimate and just use a lookup table
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
            // System.println("Invalid lat/lon values: " + lat + " " + lon);
            return null;
        }

        return [lat.toFloat(), lon.toFloat()];
    }
}

// this is to solve the issue of slice() returning a new array
// we want to instead allocate teh array to a max length, the just remove the last elements
// ie. bigArray = bigArray.slice(0, 100) will result in bigArray + 100 extra items untill big array is garbage collected
// this class allows us to just reduce bigArray to 100 elements in one go
class PointArray {
    var _internalArrayBuffer as Array<Float> = [];
    var _size as Number = 0;

    // not used, since wqe want to do optimised reads from the raw array
    // function get(i as Number) as Float
    // {
    //   return _internalArrayBuffer[i];
    // }

    function rescale(scaleFactor as Float) as Void {
        // unsafe to call with nulls or 0, checks should be made in parent
        // size is guaranteed to be a multiple of ARRAY_POINT_SIZE
        for (var i = 0; i < _internalArrayBuffer.size(); i += ARRAY_POINT_SIZE) {
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
        resize(size() - count * ARRAY_POINT_SIZE);
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

        return new RectangularPoint(
            _internalArrayBuffer[i * ARRAY_POINT_SIZE],
            _internalArrayBuffer[i * ARRAY_POINT_SIZE + 1],
            _internalArrayBuffer[i * ARRAY_POINT_SIZE + 2]
        );
    }

    function restrictPoints(maPoints as Number) as Boolean {
        // make sure we only have an acceptancbe amount of points
        // current process is to cull every second point
        // this means near the end of the track, we will have lots of close points
        // the start of the track will start getting more and more granular every
        // time we cull points
        if (size() / ARRAY_POINT_SIZE < maPoints) {
            return false;
        }

        // we need to do this without creating a new array, since we do not want to
        // double the memory size temporarily
        // slice() will create a new array, we avoid this by using our custom class
        var j = 0;
        for (var i = 0; i < size(); i += ARRAY_POINT_SIZE * 2) {
            _internalArrayBuffer[j] = _internalArrayBuffer[i];
            _internalArrayBuffer[j + 1] = _internalArrayBuffer[i + 1];
            _internalArrayBuffer[j + 2] = _internalArrayBuffer[i + 2];
            j += ARRAY_POINT_SIZE;
        }

        resize((ARRAY_POINT_SIZE * maPoints) / 2);
        logD("restrictPoints occurred");
        return true;
    }

    function reversePoints() as Void {
        var pointsCount = pointSize();
        if (pointsCount <= 1) {
            return;
        }

        for (
            var leftIndex = -1, rightIndex = size() - ARRAY_POINT_SIZE;
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
        // we could use ++_size, as it should never be larger than the size of the internal array
        _size = _internalArrayBuffer.size();
    }

    // the raw size
    function size() as Number {
        return _size;
    }

    // the number of points
    function pointSize() as Number {
        return size() / ARRAY_POINT_SIZE;
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
