import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Application;

const MAX_POINTS = 1000;
const MIN_DISTANCE_M = 5; // meters
const RESTART_STABILITY_POINT_COUNT = 10; // number of points in a row that need to be within RESTART_STABILITY_DISTANCE_M to be onsisiddered a valid course
//note: RESTART_STABILITY_POINT_COUNT should be set based on DELAY_COMPUTE_COUNT
// if DELAY_COMPUTE_COUNT = 5 seconds, 10 points give us startup cheking for 50 seconds, enough time to get a lock
const STABILITY_MAX_DISTANCE_M = 100; // max distance allowed to move to be consisdered a stable point (distance from previous point)
// note: onActivityInfo is called once per second but delayed by DELAY_COMPUTE_COUNT make sure STABILITY_MAX_DISTANCE_M takes that into account
// ie human averge running speed is 3m/s if DELAY_COMPUTE_COUNT is set to 5 STABILITY_MAX_DISTANCE_M should be set to at least 15
const DELAY_COMPUTE_COUNT = 5;
// start as minimum area, and is set to the correct size as points are added
// we want a 'empty' track to not sway the calculation of what to render
// note: we cannot do a const, as it assigns the array or point by reference
function BOUNDING_BOX_DEFAULT() as [Float, Float, Float, Float] {return [FLOAT_MAX, FLOAT_MAX, FLOAT_MIN, FLOAT_MIN];}
function BOUNDING_BOX_CENTER_DEFAULT() as RectangularPoint {return new RectangularPoint(0.0f, 0.0f, 0.0f);}

class BreadcrumbTrack {
  // cached values
  // we should probbaly do this per latitude to get an estimate and just use a lookup table
  var _lonConversion as Float = 20037508.34f / 180.0f;
  var _pi360 as Float = Math.PI / 360.0f;
  var _pi180 as Float = Math.PI / 180.0f;

  // unscaled cordinates in
  // not sure if its more performant to have these as one array or 2
  // suspect 1 would result in faster itteration when drawing
  // shall store them as poit classes for now, and can convert to using just
  // arrays
  var coordinates as PointArray = new PointArray();
  var seenStartupPoints as Number = 0;
  var possibleBadPointsAdded as Number = 0;
  var inRestartMode as Boolean = true;
  var _computeCounter as Number = 0;

  var boundingBox as [Float, Float, Float, Float] = BOUNDING_BOX_DEFAULT();
  var boundingBoxCenter as RectangularPoint = BOUNDING_BOX_CENTER_DEFAULT();
  var distanceTotal as Float = 0f;
  var elevationMin as Float = FLOAT_MAX;
  var elevationMax as Float = FLOAT_MIN;

  function writeToDisk(key as String) as Void {
    Storage.setValue(key + "bb", boundingBox);
    Storage.setValue(key + "bbc", [
      boundingBoxCenter.x, boundingBoxCenter.y, boundingBoxCenter.altitude
    ]);
    Storage.setValue(key + "coords", coordinates._internalArrayBuffer);
    Storage.setValue(key + "coordsSize", coordinates._size);
    Storage.setValue(key + "distanceTotal", distanceTotal);
    Storage.setValue(key + "elevationMin", elevationMin);
    Storage.setValue(key + "elevationMax", elevationMax);
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

      var track = new BreadcrumbTrack();
      track.boundingBox = bb as[Float, Float, Float, Float];
      if (track.boundingBox.size() != 4) {
        return null;
      }
      track.boundingBoxCenter = new RectangularPoint(
          bbc[0] as Float, bbc[1] as Float, bbc[2] as Float);
      track.coordinates._internalArrayBuffer = coords as Array<Float>;
      track.coordinates._size = coordsSize as Number;
      track.distanceTotal = distanceTotal as Float;
      track.elevationMin = elevationMin as Float;
      track.elevationMax = elevationMax as Float;
      if (track.coordinates.size() % ARRAY_POINT_SIZE != 0) {
        return null;
      }
      return track;
    } catch (e) {
      return null;
    }
  }

  function lastPoint() as RectangularPoint or Null 
  {
    return coordinates.lastPoint();
  }

  function firstPoint() as RectangularPoint or Null 
  {
    return coordinates.firstPoint();
  }

  function addLatLongRaw(lat as Float, lon as Float, altitude as Float) as Void {
    var newPoint = latLon2xy(lat, lon, altitude);
    if (newPoint == null)
    {
      return;
    }
    var lastPoint = lastPoint();
    if (lastPoint == null)
    {
      addPointRaw(newPoint, 0f);
      return;
    }

    var distance = lastPoint.distanceTo(newPoint);

    if (distance < MIN_DISTANCE_M)
    {
      // no need to add points closer than this
      return;
    }

    addPointRaw(newPoint, distance);
  }

  function addPointRaw(newPoint as RectangularPoint, distance as Float) as Void {
    // this might drift on slices, perhaps we should recalculate?
    distanceTotal += distance;
    coordinates.add(newPoint);
    updateBoundingBox(newPoint);
    coordinates.restrictPoints(MAX_POINTS);
  }

  function updateBoundingBoxFromAllPoints() as Void
  {
    boundingBox = BOUNDING_BOX_DEFAULT();
    boundingBoxCenter = BOUNDING_BOX_CENTER_DEFAULT();
    elevationMin = FLOAT_MAX;
    elevationMax = FLOAT_MIN;
    var pointSize = coordinates.pointSize();
    for (var i = 0; i < pointSize; ++i) {
      var point = coordinates.getPoint(i);
      // shoul never be null, but check to be safe
      if (point == null)
      {
        return;
      }

      updateBoundingBox(point);
    }
  }

  function updateBoundingBox(point as RectangularPoint) as Void {
    boundingBox[0] = minF(boundingBox[0], point.x);
    boundingBox[1] = minF(boundingBox[1], point.y);
    boundingBox[2] = maxF(boundingBox[2], point.x);
    boundingBox[3] = maxF(boundingBox[3], point.y);

    elevationMin = minF(elevationMin, point.altitude);
    elevationMax = maxF(elevationMax, point.altitude);

    boundingBoxCenter = new RectangularPoint(
        boundingBox[0] + (boundingBox[2] - boundingBox[0]) / 2.0,
        boundingBox[1] + (boundingBox[3] - boundingBox[1]) / 2.0, 0.0f);
  }

  function onTimerStart() as Void
  {
    // check from startup, and also clear the current coordinates, 
    // anything we got before start is invalid
    coordinates.clear();
    // we also need to reset the bounding box, as its only ever expanded, never reduced
    boundingBox = BOUNDING_BOX_DEFAULT();
    boundingBoxCenter = BOUNDING_BOX_CENTER_DEFAULT();
    distanceTotal = 0f;
    elevationMin = FLOAT_MAX;
    elevationMax = FLOAT_MIN;
    onTimerResume();
  }

  function onTimerResume() as Void
  {
    // check from startup
    seenStartupPoints = 0;
    possibleBadPointsAdded = 0;
    inRestartMode = true;
  }

  function handlePointAddStartup(newPoint as RectangularPoint) as Void
  {
    // genreal p-lan of this function is
    // add data to both startup array and raw array (so we can start drawing points immediately, without the need for patching both arrays together)
    // on unstable points, remove points from both arrays
    // if the main coordinates array has been sliced in half through `restrictPoints()` 
    // this may remove more points than needed, but is not a huge concern
    var lastStartupPoint = coordinates.lastPoint();
    if (lastStartupPoint == null || seenStartupPoints == 0)
    {
      // nothing to compare against, add the point to both arrays
      // setting to 1 instead of incrementing, just incase they do not get cleaed when they should
      seenStartupPoints = 1;
      possibleBadPointsAdded = 1;
      addPointRaw(newPoint, 0f);
      return;
    }

    var stabilityCheckDistance = lastStartupPoint.distanceTo(newPoint);
    if (stabilityCheckDistance < MIN_DISTANCE_M)
    {
      // point too close, no need to add, but its still a good point
      seenStartupPoints++;
      return;
    }

    if (stabilityCheckDistance > STABILITY_MAX_DISTANCE_M)
    {
        // we are unstable, remove all points
        seenStartupPoints = 0;
        coordinates.removeLastCountPoints(possibleBadPointsAdded);
        possibleBadPointsAdded = 0;
        updateBoundingBoxFromAllPoints();
        return;
    }

    // we are stable, see if we can break out of startup
    seenStartupPoints++;
    possibleBadPointsAdded++;
    addPointRaw(newPoint, stabilityCheckDistance);
    
    if (seenStartupPoints == RESTART_STABILITY_POINT_COUNT)
    {
      // we have enough stable points that we can exist restart mode and just handle them as normal points
      inRestartMode = false;
      seenStartupPoints = 0;
      possibleBadPointsAdded = 0;
    }
  }

  function onActivityInfo(activityInfo as Activity.Info) as Void {
    // System.println("computing data field");
    _computeCounter++;
    // slow down the calls to onActivityInfo as its a heavy operation checking
    // the distance we don't really need data much faster than this anyway
    if (_computeCounter != DELAY_COMPUTE_COUNT) {
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

    var newPoint = latLon2xy(lat, lon, altitude);
    if (newPoint == null)
    {
      return;
    }
    
    if (inRestartMode)
    {
      handlePointAddStartup(newPoint);
      return;
    }
    
    var lastPoint = lastPoint();
    if (lastPoint == null)
    {
      // startup mode should have set at least one point, revert to startup mode, something has gone wrong
      onTimerResume();
      return;
    }

    var distance = lastPoint.distanceTo(newPoint);
    if (distance < MIN_DISTANCE_M)
    {
      // point too close, so we can skip it
      return;
    }

    if (distance > STABILITY_MAX_DISTANCE_M)
    {
      // it's too far away, and likely a glitch
      return;
    }

    addPointRaw(newPoint, distance);
  }

  // inverse of https://gis.stackexchange.com/a/387677
  function latLon2xy(lat as Float, lon as Float,
                     altitude as Float) as RectangularPoint or Null {

    // todo cache all these as constants
    var latRect = ((Math.ln(Math.tan((90 + lat) * _pi360)) / _pi180) * _lonConversion);
    var lonRect = lon * _lonConversion;

    var point = new RectangularPoint(latRect.toFloat(), lonRect.toFloat(), altitude);
    if (!point.valid())
    {
      return null;
    }

    return point;
  }
}
