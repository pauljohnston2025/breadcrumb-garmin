import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

const ROUTE_COLOUR = Graphics.COLOR_BLUE;
const TRACK_COLOUR = Graphics.COLOR_GREEN;

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
  var _scratchPadBitmap as BufferedBitmap;
  // var _renderCounter = 0;

  // Set the label of the data field here.
  function initialize(breadcrumbContext as BreadcrumbContext) {
    _breadcrumbContext = breadcrumbContext;
    _scratchPadBitmap = newBitmap(_breadcrumbContext.trackRenderer()._screenSize.toNumber());
    DataField.initialize();
  }

  function onLayout(dc as Dc) as Void {
    // for now we render everything in the onUpdate view, and assume only 1 data
    // screen
    var textDim = dc.getTextDimensions("1234", Graphics.FONT_XTINY);
    _breadcrumbContext.trackRenderer().setScreenSize(
      dc.getWidth() * 1.0f,
      textDim[0] * 1.0f
    );
    _scratchPadBitmap = newBitmap(_breadcrumbContext.trackRenderer()._screenSize.toNumber());
  }

  function onWorkoutStarted() as Void {
    _breadcrumbContext.track().onStart();
  }
  
  function onTimerStart() as Void {
    _breadcrumbContext.track().onStartResume();
  }
  
  function compute(info as Activity.Info) as Void {

    // temp hack for debugging (since it seems altitude does not work when playing activity data from gpx file)
    // var route = _breadcrumbContext.route();
    // if (route != null)
    // {
    //   var nextPoint = route.coordinates.getPoint(_breadcrumbContext.track().coordinates.pointSize());
    //   if (nextPoint != null)
    //   {
    //     info.altitude = nextPoint.altitude;
    //   }
    // }

  // this is here due to stack overflow bug when requests trigger the next request
    while(_breadcrumbContext.webRequestHandler().startNextIfWeCan())
    {

    }
    
    _breadcrumbContext.track().onActivityInfo(info);
    _breadcrumbContext.trackRenderer().onActivityInfo(info);
    var currentSpeed = info.currentSpeed;
    if (currentSpeed != null) {
      _speedMPS = currentSpeed;
    }
  }

  function onUpdate(dc as Dc) as Void {
    // _renderCounter++;
    // // slow down the calls to onUpdate as its a heavy operation, we will only render every second time (effectively 2 seconds)
    // // this should save some battery, and hopefully the screen stays as the old renderred value
    // // this will mean that we will need to wait this long for the inital render too
    // // perhaps we could base it on speed or 'user is looking at watch'
    // // and have a touch override?
    // if (_renderCounter != 2) {
    //   View.onUpdate(dc);
    //   return;
    // }

    // _renderCounter = 0;
    // looks like view must do a render (not doing a render causes flashes), perhaps we can store our rendered state to a buffer to load from?

    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    var renderer = _breadcrumbContext.trackRenderer();
    var mapRenderer = _breadcrumbContext.mapRenderer();
    if (renderer.renderUi(dc))
    {
      return;
    }

    // mode should be wtored here, but is needed for renderring the ui
    // should structure this way better, but oh well (renderer per mode etc.)
    if (renderer.mode == MODE_ELEVATION)
    {
       rederElevation(dc);
       return;
    }

    var route = _breadcrumbContext.route();
    var track = _breadcrumbContext.track();

    var lastPoint = track.lastPoint();
    if (lastPoint == null) {
      // edge case on startup when we have not got any readings yet (also when
      // viewing in settings) just render the route if we have one
      if (route != null) {
        mapRenderer.renderMap(dc, _scratchPadBitmap, route.boundingBoxCenter, renderer.rotationRadians());
        renderer.updateCurrentScale(route.boundingBox);
        renderer.renderTrack(dc, route, ROUTE_COLOUR, route.boundingBoxCenter);
        renderer.renderCurrentScale(dc);
      }

      return;
    }

    // if we are moving at some pace check the mode we are in to determine if we
    // zoom in or out
    if (_speedMPS > 1.0) {
      if (renderer._zoomAtPace) {
        renderCloseAroundCurrentPosition(dc, mapRenderer, renderer, lastPoint, route, track);
        return;
      }

      renderZoomedOut(dc, mapRenderer, renderer, lastPoint, route, track);
      return;
    }

    // we are not at speed, so invert logic (this allows us to zoom in when
    // stopped, and zoom out when running) mostly useful for cheking close route
    // whilst stopped but also allows quick zoom in before setting manual zoom
    // (rather than having to manually zoom in from the outer level) once zoomed
    // in we lock onto the user position anyway
    if (renderer._zoomAtPace) {
      renderZoomedOut(dc, mapRenderer, renderer, lastPoint, route, track);
      return;
    }

    renderCloseAroundCurrentPosition(dc, mapRenderer, renderer, lastPoint, route, track);
  }

  function renderZoomedOut(
      dc as Dc, 
      mapRenderer as MapRenderer,
      renderer as BreadcrumbRenderer, lastPoint as RectangularPoint,
      route as BreadcrumbTrack or Null, track as BreadcrumbTrack) as Void {
    // when the scale is locked, we need to be where the user is, otherwise we
    // could see a blank part of the map, when we are zoomed in and have no
    // context
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

      if (useUserLocation) {
        centerPoint = lastPoint;
      }

      mapRenderer.renderMap(dc, _scratchPadBitmap, centerPoint, renderer.rotationRadians());
      renderer.updateCurrentScale(outerBoundingBox);
      renderer.renderTrack(dc, route, ROUTE_COLOUR, centerPoint);
      renderer.renderTrack(dc, track, TRACK_COLOUR, centerPoint);
      renderer.renderUser(dc, centerPoint, lastPoint);
      renderer.renderCurrentScale(dc);
      return;
    }

    var centerPoint = track.boundingBoxCenter;
    if (useUserLocation) {
      centerPoint = lastPoint;
    }

    renderer.updateCurrentScale(track.boundingBox);
    renderer.renderTrack(dc, track, TRACK_COLOUR, centerPoint);
    renderer.renderUser(dc, centerPoint, lastPoint);
    renderer.renderCurrentScale(dc);
  }

  function renderCloseAroundCurrentPosition(
      dc as Dc, 
      mapRenderer as MapRenderer,
      renderer as BreadcrumbRenderer, lastPoint as RectangularPoint,
      route as BreadcrumbTrack or Null, track as BreadcrumbTrack) as Void {
    // note: this renders around the users position, but may result in a
    // different zoom level if the scale is set in the renderer render around
    // the current position
    var renderDistanceM = 100;
    var outerBoundingBox = [
      lastPoint.x - renderDistanceM,
      lastPoint.y - renderDistanceM,
      lastPoint.x + renderDistanceM,
      lastPoint.y + renderDistanceM,
    ];

    mapRenderer.renderMap(dc, _scratchPadBitmap, lastPoint, renderer.rotationRadians());
    renderer.updateCurrentScale(outerBoundingBox);

    if (route != null) {
      renderer.renderTrack(dc, route, ROUTE_COLOUR, lastPoint);
    }
    renderer.renderTrack(dc, track, TRACK_COLOUR, lastPoint);
    renderer.renderUser(dc, lastPoint, lastPoint);
    renderer.renderCurrentScale(dc);
  }

  function rederElevation(dc as Dc) as Void {
    var route = _breadcrumbContext.route();
    var track = _breadcrumbContext.track();   
    var renderer = _breadcrumbContext.trackRenderer();

    var elevationScale = renderer.getElevationScale(track, route);
    var hScale = elevationScale[0];
    var vScale = elevationScale[1];
    var startAt = elevationScale[2];

    renderer.renderElevationChart(dc, hScale, vScale, startAt);
    if (route != null) {
      renderer.renderTrackElevtion(dc, route, ROUTE_COLOUR, hScale, vScale, startAt);
    }
    renderer.renderTrackElevtion(dc, track, TRACK_COLOUR, hScale, vScale, startAt);
  }
}