import Toybox.Lang;
import Toybox.Test;

(:test,:debug)
function latLon2xyTest(logger as Logger) as Boolean {
    var point = RectangularPoint.latLon2xy(-27.49225, 153.030049, 123.4);
    logger.debug("point = " + point);
    Test.assert(point != null);
    if (point == null) {
        return false;
    }
    return point.x == 17035226.0 && point.y == -3185107.25 && point.altitude == 123.4;
}

(:test,:debug)
function latLon2xyTest2(logger as Logger) as Boolean {
    var point = RectangularPoint.latLon2xy(-26.49225, 153.030049, 123.4);
    logger.debug("point = " + point);
    Test.assert(point != null);
    if (point == null) {
        return false;
    }
    return point.x == 17035226.0 && point.y == -3060177.5 && point.altitude == 123.4;
}

(:test,:debug)
function latLon2xyRoundTrip(logger as Logger) as Boolean {
    var lat = -26.49225;
    var long = 153.030049;
    var point = RectangularPoint.latLon2xy(lat, long, 123.4);
    Test.assert(point != null);
    if (point == null) {
        return false;
    }
    var latlong = RectangularPoint.xyToLatLon(point.x, point.y);

    Test.assert(latlong != null);
    if (latlong == null) {
        return false;
    }
    logger.debug(latlong[0]);
    logger.debug(latlong[1]);
    Test.assert(lat - latlong[0] < 0.001f);
    Test.assert(long - latlong[1] < 0.001f);
    return true;
}

(:test,:debug)
function restrictPointsToMaxMemoryLessThanHalf(logger as Logger) as Boolean {
    // 1. Create a PointArray and populate it with 10 points.
    var points = new PointArray(10);
    points.add(new RectangularPoint(1f,2f,3f));
    points.add(new RectangularPoint(4f,5f,6f));
    points.add(new RectangularPoint(7f,8f,9f));
    points.add(new RectangularPoint(10f,11f,12f));
    points.add(new RectangularPoint(13f,14f,15f));
    points.add(new RectangularPoint(16f,17f,18f));

    
    Test.assertEqual(points.pointSize(), 6);
    Test.assertEqual(points.size(), 18);

    var wasRestricted = points.restrictPointsDecimation(2);
    Test.assert(wasRestricted);

    var lastPoint = points.lastPoint(); // this use to throw because we only cut the points in half but then set the array size smaller than the internal tracking  _size

    var newSize = points.pointSize();
    logger.debug("New point size after restriction: " + newSize);
    Test.assertEqual(newSize, 3); // it also keeps the last point

    Test.assertEqual(points.size(), 9);

    Test.assertEqual(points._internalArrayBuffer[0], 1f);
    Test.assertEqual(points._internalArrayBuffer[1], 2f);
    Test.assertEqual(points._internalArrayBuffer[2], 3f);
    Test.assertEqual(points._internalArrayBuffer[3], 10f);
    Test.assertEqual(points._internalArrayBuffer[4], 11f);
    Test.assertEqual(points._internalArrayBuffer[5], 12f);
    Test.assertEqual(points._internalArrayBuffer[6], 16f);
    Test.assertEqual(points._internalArrayBuffer[7], 17f);
    Test.assertEqual(points._internalArrayBuffer[8], 18f);


    Test.assert(lastPoint != null);
    if (lastPoint == null) {
        return false;
    }
    Test.assertEqual(lastPoint.x, 16f);
    Test.assertEqual(lastPoint.y, 17f);
    Test.assertEqual(lastPoint.altitude, 18f);

    return true;
}

(:test,:debug)
function restrictPointsOddNumberKeepsLastPointTest(logger as Logger) as Boolean {
    // 1. Create a PointArray and populate it with 10 points.
    var points = new PointArray(10);
    points.add(new RectangularPoint(1f,2f,3f));
    points.add(new RectangularPoint(4f,5f,6f));
    points.add(new RectangularPoint(7f,8f,9f));
    points.add(new RectangularPoint(10f,11f,12f));
    points.add(new RectangularPoint(13f,14f,15f));
    points.add(new RectangularPoint(16f,17f,18f));

    
    Test.assertEqual(points.pointSize(), 6);
    Test.assertEqual(points.size(), 18);

    var wasRestricted = points.restrictPointsDecimation(3);
    Test.assert(wasRestricted);

    var newSize = points.pointSize();
    logger.debug("New point size after restriction: " + newSize);
    Test.assertEqual(newSize, 4);

    Test.assertEqual(points.size(), 12);

    Test.assertEqual(points._internalArrayBuffer[0], 1f);
    Test.assertEqual(points._internalArrayBuffer[1], 2f);
    Test.assertEqual(points._internalArrayBuffer[2], 3f);
    Test.assertEqual(points._internalArrayBuffer[3], 7f);
    Test.assertEqual(points._internalArrayBuffer[4], 8f);
    Test.assertEqual(points._internalArrayBuffer[5], 9f);
    Test.assertEqual(points._internalArrayBuffer[6], 13f);
    Test.assertEqual(points._internalArrayBuffer[7], 14f);
    Test.assertEqual(points._internalArrayBuffer[8], 15f);
    Test.assertEqual(points._internalArrayBuffer[9], 16f);
    Test.assertEqual(points._internalArrayBuffer[10], 17f);
    Test.assertEqual(points._internalArrayBuffer[11], 18f);

    return true;
}

(:test,:debug)
function restrictPointsOddNumberKeepsLastPointEvenIfOddTest(logger as Logger) as Boolean {
    // 1. Create a PointArray and populate it with 10 points.
    var points = new PointArray(10);
    points.add(new RectangularPoint(1f,2f,3f));
    points.add(new RectangularPoint(4f,5f,6f));
    points.add(new RectangularPoint(7f,8f,9f));
    points.add(new RectangularPoint(10f,11f,12f));
    points.add(new RectangularPoint(13f,14f,15f));
    
    Test.assertEqual(points.pointSize(), 5);
    Test.assertEqual(points.size(), 15);

    var wasRestricted = points.restrictPointsDecimation(3);
    Test.assert(wasRestricted);

    var newSize = points.pointSize();
    logger.debug("New point size after restriction: " + newSize);
    Test.assertEqual(newSize, 3);

    Test.assertEqual(points.size(), 9);


    Test.assertEqual(points._internalArrayBuffer[0], 1f);
    Test.assertEqual(points._internalArrayBuffer[1], 2f);
    Test.assertEqual(points._internalArrayBuffer[2], 3f);
    Test.assertEqual(points._internalArrayBuffer[3], 7f);
    Test.assertEqual(points._internalArrayBuffer[4], 8f);
    Test.assertEqual(points._internalArrayBuffer[5], 9f);
    Test.assertEqual(points._internalArrayBuffer[6], 13f);
    Test.assertEqual(points._internalArrayBuffer[7], 14f);
    Test.assertEqual(points._internalArrayBuffer[8], 15f);

    return true;
}

(:test,:debug)
function restrictPointsEvenNumberKeepsLastPointTest(logger as Logger) as Boolean {
    // 1. Create a PointArray and populate it with 10 points.
    var points = new PointArray(10);
    points.add(new RectangularPoint(1f,2f,3f));
    points.add(new RectangularPoint(4f,5f,6f));
    points.add(new RectangularPoint(7f,8f,9f));
    points.add(new RectangularPoint(10f,11f,12f));
    points.add(new RectangularPoint(13f,14f,15f));
    points.add(new RectangularPoint(16f,17f,18f));
    
    Test.assertEqual(points.pointSize(), 6);
    Test.assertEqual(points.size(), 18);

    var wasRestricted = points.restrictPointsDecimation(4);
    Test.assert(wasRestricted);

    var newSize = points.pointSize();
    logger.debug("New point size after restriction: " + newSize);
    Test.assertEqual(newSize, 4);

    Test.assertEqual(points.size(), 12);


    Test.assertEqual(points._internalArrayBuffer[0], 1f);
    Test.assertEqual(points._internalArrayBuffer[1], 2f);
    Test.assertEqual(points._internalArrayBuffer[2], 3f);
    Test.assertEqual(points._internalArrayBuffer[3], 7f);
    Test.assertEqual(points._internalArrayBuffer[4], 8f);
    Test.assertEqual(points._internalArrayBuffer[5], 9f);
    Test.assertEqual(points._internalArrayBuffer[6], 13f);
    Test.assertEqual(points._internalArrayBuffer[7], 14f);
    Test.assertEqual(points._internalArrayBuffer[8], 15f);
    Test.assertEqual(points._internalArrayBuffer[9], 16f);
    Test.assertEqual(points._internalArrayBuffer[10], 17f);
    Test.assertEqual(points._internalArrayBuffer[11], 18f);

    return true;
}

(:test,:debug)
function restrictPointsEvenNumberKeepsLastPointEvenIfOddTest(logger as Logger) as Boolean {
    // 1. Create a PointArray and populate it with 10 points.
    var points = new PointArray(10);
    points.add(new RectangularPoint(1f,2f,3f));
    points.add(new RectangularPoint(4f,5f,6f));
    points.add(new RectangularPoint(7f,8f,9f));
    points.add(new RectangularPoint(10f,11f,12f));
    points.add(new RectangularPoint(13f,14f,15f));
    
    Test.assertEqual(points.pointSize(), 5);
    Test.assertEqual(points.size(), 15);

    var wasRestricted = points.restrictPointsDecimation(2);
    Test.assert(wasRestricted);

    var newSize = points.pointSize();
    logger.debug("New point size after restriction: " + newSize);
    Test.assertEqual(newSize, 3);

    Test.assertEqual(points.size(), 9);


    Test.assertEqual(points._internalArrayBuffer[0], 1f);
    Test.assertEqual(points._internalArrayBuffer[1], 2f);
    Test.assertEqual(points._internalArrayBuffer[2], 3f);
    Test.assertEqual(points._internalArrayBuffer[3], 7f);
    Test.assertEqual(points._internalArrayBuffer[4], 8f);
    Test.assertEqual(points._internalArrayBuffer[5], 9f);
    Test.assertEqual(points._internalArrayBuffer[6], 13f);
    Test.assertEqual(points._internalArrayBuffer[7], 14f);
    Test.assertEqual(points._internalArrayBuffer[8], 15f);

    return true;
}
