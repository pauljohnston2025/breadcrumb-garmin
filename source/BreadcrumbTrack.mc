import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;

const MAX_POINTS = 10;

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
  var coordinates = new MemorySafeArray();
  var _computeCounter = 0;

  // start as minumum area, and is reduced as poins are added
  var boundingBox as[Float, Float, Float, Float] =
      [ FLOAT_MAX, FLOAT_MAX, FLOAT_MIN, FLOAT_MIN ];
  var boundingBoxCenter as RectangularPoint =
      new RectangularPoint(0.0f, 0.0f, 0.0f);

  function writeToDisk(key as String) as Void {
    Storage.setValue(key + "bb", boundingBox);
    Storage.setValue(key + "bbc", [
      boundingBoxCenter.x, boundingBoxCenter.y, boundingBoxCenter.altitude
    ]);
    Storage.setValue(key + "coords", coordinates._internalArrayBuffer);
    Storage.setValue(key + "coordsSize", coordinates._size);
  }

  static function readFromDisk(key as String) as BreadcrumbTrack or Null {
    try {
      var bb = Storage.getValue(key + "bb");
      if (bb == null) {
        return null;
      }
      var bbc = Storage.getValue(key + "bbc");
      if (bbc == null) {
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

      var track = new BreadcrumbTrack();
      track.boundingBox = bb as[Float, Float, Float, Float];
      if (track.boundingBox.size() != 4) {
        return null;
      }
      track.boundingBoxCenter = new RectangularPoint(
          bbc[0] as Float, bbc[1] as Float, bbc[2] as Float);
      track.coordinates._internalArrayBuffer = coords as Array<Float>;
      track.coordinates._size = coordsSize as Number;
      if (track.coordinates.size() % 3 != 0) {
        return null;
      }
      return track;
    } catch (e) {
      return null;
    }
  }

  function clear() as Void { coordinates.resize(0); }

  function addPointRaw(lat as Float, lon as Float, altitude as Float) as Void {
    var point = latLon2xy(lat, lon, altitude);
    coordinates.add(point.x);
    coordinates.add(point.y);
    coordinates.add(point.altitude);
    updateBoundingBox(point);
    restrictPoints();
  }

  function restrictPoints() {
    // make sure we only have an acceptancbe amount of points
    // current process is to cull every second point
    // this means near the end of the track, we will have lots of close points
    // the start of the track will start getting more and more granular every
    // time we cull points
    // 3 items per point
    if (coordinates.size() / 3 < MAX_POINTS) {
      return;
    }

    // we need to do this without creating a new array, since we do not want to
    // double the memory size temporarily
    // slice() will create a new array, we avoid this by using our custom class
    var rawCoordinates = coordinates._internalArrayBuffer;
    var j = 0;
    for (var i = 0; i < coordinates.size(); i += 6) {
      rawCoordinates[j] = rawCoordinates[i];
      rawCoordinates[j + 1] = rawCoordinates[i + 1];
      rawCoordinates[j + 2] = rawCoordinates[i + 2];
      j += 3;
    }

    coordinates.resize(3 * MAX_POINTS / 2);
  }

  function updateBoundingBox(point as RectangularPoint) as Void {
    boundingBox[0] = minF(boundingBox[0], point.x);
    boundingBox[1] = minF(boundingBox[1], point.y);
    boundingBox[2] = maxF(boundingBox[2], point.x);
    boundingBox[3] = maxF(boundingBox[3], point.y);

    boundingBoxCenter = new RectangularPoint(
        boundingBox[0] + (boundingBox[2] - boundingBox[0]) / 2.0,
        boundingBox[1] + (boundingBox[3] - boundingBox[1]) / 2.0, 0.0f);
  }

  function onActivityInfo(activityInfo as Activity.Info) as Void {
    // System.println("computing data field");
    _computeCounter++;
    // slow down the calls to onActivityInfo as its a heavy operation checking
    // the distance we don't really need data much faster than this anyway
    if (_computeCounter != 5) {
      return;
    }

    _computeCounter = 0;

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
