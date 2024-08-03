import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

// note to get this to work on the simulator need to modify simulator.json and
// add isTouchable this is already on edgo devices with touch, but not the
// venu2s, even though I tested and it worked on the actual device
// C:\Users\RandomGuy2.1\AppData\Roaming\Garmin\ConnectIQ\Devices\venu2s\simulator.json
// "datafields": {
// 				"isTouchable": true,
//                 "datafields": [
// note: this only allows taps, cannot handle swipes/holds etc. (need to test on
// real device)
class BreadcrumbDataFieldView extends WatchUi.DataField {
  var _breadcrumbContext as BreadcrumbContext;
  var _speedMPS as Float = 0.0;  // start at no speed

  // Set the label of the data field here.
  function initialize(breadcrumbContext as BreadcrumbContext) {
    _breadcrumbContext = breadcrumbContext;
    DataField.initialize();
  }

  function onLayout(dc as Dc) as Void {
    // for now we render everything in the onUpdate view, and assume only 1 data
    // screen
  }

  function compute(info as Activity.Info) as Void {
    _breadcrumbContext.track().onActivityInfo(info);
    _breadcrumbContext.trackRenderer().onActivityInfo(info);
    var currentSpeed = info.currentSpeed;
    if (currentSpeed != null) {
      _speedMPS = currentSpeed;
    }
  }

  function onUpdate(dc as Dc) as Void {
    // System.println("onUpdate data field");

    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    var renderer = _breadcrumbContext.trackRenderer();
    renderer.renderUi(dc);

    var route = _breadcrumbContext.route();
    var track = _breadcrumbContext.track();

    var speedHighEnough = _speedMPS > 1.0;
    // if we are moving at some pace
    if (!_breadcrumbContext.fullViewLocked && speedHighEnough &&
        track.coordinates.size() >= 3) {
      // render around the current position
      var centerPoint = track.lastPoint();
      if (centerPoint == null) {
        throw new Exception();
      }
      var renderDistanceM = 100;
      var outerBoundingBox = [
        centerPoint.x - renderDistanceM,
        centerPoint.y - renderDistanceM,
        centerPoint.x + renderDistanceM,
        centerPoint.y + renderDistanceM,
      ];

      if (route != null) {
        renderer.renderTrack(dc, route, Graphics.COLOR_BLUE, centerPoint,
                             outerBoundingBox);
      }
      renderer.renderTrack(dc, track, Graphics.COLOR_RED, centerPoint,
                           outerBoundingBox);
      return;
    }

    // when the scale is locked, we need to be where the user is, otherwise we could see a blank part at the center of the map
    var useUserLocation = renderer._scale != null;

    // we are in 'full render mode', so do the entire extent
    if (route != null) {
      // render the whole track and route if we stop
      var outerBoundingBox = [
        minF(route.boundingBox[0], track.boundingBox[0]),
        minF(route.boundingBox[1], track.boundingBox[1]),
        maxF(route.boundingBox[2], track.boundingBox[2]),
        maxF(route.boundingBox[3], track.boundingBox[3]),
      ];

      var centerPoint = new RectangularPoint(
          outerBoundingBox[0] +
              (outerBoundingBox[2] - outerBoundingBox[0]) / 2.0,
          outerBoundingBox[1] +
              (outerBoundingBox[3] - outerBoundingBox[1]) / 2.0,
          0.0f);

      var lastLocation = track.lastPoint();
      if (useUserLocation && lastLocation != null) {
        centerPoint = lastLocation;
      }

      renderer.renderTrack(dc, route, Graphics.COLOR_BLUE, centerPoint,
                           outerBoundingBox);
      renderer.renderTrack(dc, track, Graphics.COLOR_RED, centerPoint,
                           outerBoundingBox);
      return;
    }

    if (useUserLocation) {
      // render the track if we do not have a route
      // we are in 'full render mode', so do the entire extent
      var lastPoint = track.lastPoint();
      if (lastPoint != null) {
        renderer.renderTrack(dc, track, Graphics.COLOR_RED, lastPoint,
                             track.boundingBox);
      }
      return;
    }

    renderer.renderTrack(dc, track, Graphics.COLOR_RED, track.boundingBoxCenter,
                         track.boundingBox);
  }
}