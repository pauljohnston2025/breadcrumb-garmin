import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;

class RectangularPoint {
  var x as Float;
  var y as Float;
  var altitude as Float;

  function initialize(_x as Float, _y as Float, _altitude as Float) {
    x = _x;
    y = _y;
    altitude = _altitude;
  }
}

class BreadcrumbTrack {
  // unscaled cordinates in
  // not sure if its more performant to have these as one array or 2
  // suspect 1 would result in faster itteration when drawing
  // shall store them as poit classes for now, and can convert to using just
  // arrays
  var coordinates as Array<RectangularPoint> = [];

  // start as minumum area, and is reduced as poins are added
  var boundingBox as[Float, Float, Float, Float] =
      [ FLOAT_MAX, FLOAT_MAX, FLOAT_MIN, FLOAT_MIN ];
  var boundingBoxCenter as RectangularPoint = new RectangularPoint(0.0f, 0.0f, 0.0f);

  function clear() as Void { coordinates = []; }

  function addPointRaw(lat as Float, lon as Float, altitude as Float) as Void {
    System.println("adding coordinate: " + lat + "," + lon);
    var point = latLon2xy(lat, lon, altitude);
    coordinates.add(point);
    updateBoundingBox(point);
    // System.println("do some track maths");
  }

  function updateBoundingBox(point as RectangularPoint) {
    boundingBox[0] = minF(boundingBox[0], point.x);
    boundingBox[1] = minF(boundingBox[1], point.y);
    boundingBox[2] = maxF(boundingBox[2], point.x);
    boundingBox[3] = maxF(boundingBox[3], point.y);

    boundingBoxCenter = new RectangularPoint(
        boundingBox[0] + (boundingBox[2] - boundingBox[0]) / 2.0,
        boundingBox[1] + (boundingBox[3] - boundingBox[1]) / 2.0, 0.0f);
  }

  function onActivityInfo(activityInfo as Activity.Info) as Void {
    // todo skip if 'last logged' is not large enough (we don't want to do
    // complex calcualtions all the time)
    var loc = activityInfo.currentLocation;
    if (loc == null) {
      return;
    }

    var altitude = activityInfo.altitude;
    if (altitude == null) {
      return;
    }

    // todo only add point if it is futher aways than x meters
    // or if we have been in the same spot for some time?
    // need to limit coordinates to a certain size
    var asDeg = loc.toDegrees();
    var lat = asDeg[0].toFloat();
    var lon = asDeg[1].toFloat();
    addPointRaw(lat, lon, altitude);
  }

  // inverse of https://gis.stackexchange.com/a/387677
  function latLon2xy(lat as Float, lon as Float,
                     altitude as Float) as RectangularPoint {
    // todo cache all these as constants
    var latRect =
        ((Math.ln(Math.tan((90 + lat) * Math.PI / 360.0)) / (Math.PI / 180.0)) *
         (20037508.34 / 180.0));
    var lonRect = lon * 20037508.34 / 180.0;

    return new RectangularPoint(latRect.toFloat(), lonRect.toFloat(), altitude);
  }
}
