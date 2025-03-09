import Toybox.Activity;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

const DESIRED_SCALE_PIXEL_WIDTH as Float = 100.0f;
const DESIRED_ELEV_SCALE_PIXEL_WIDTH as Float = 50.0f;
const MIN_SCALE as Float = DESIRED_SCALE_PIXEL_WIDTH / 100000.0f;

enum /*Mode*/ {
  MODE_NORMAL,
  MODE_ELEVATION,
  MODE_MAX,
}

class BreadcrumbRenderer {
  var _breadcrumbContext as BreadcrumbContext;
  var _scale as Float or Null = null;
  var _currentScale as Float = 0.0;
  var _rotationRad as Float = 90.0;  // heading in radians
  var _zoomAtPace as Boolean = true;
  var _clearRouteProgress as Number = 0;
  var mode as Number = MODE_NORMAL;

  // units in meters (float/int) to label
  var SCALE_NAMES as Dictionary = {
      1 => "1m", 5 => "5m", 10 => "10m", 20 => "20m", 30 => "30m", 40 => "40m", 50 => "50m", 100 => "100m", 250 => "250m",     
      500 => "500m", 1000 => "1km",   2000 => "2km",   3000 => "3km",     
      4000 => "4km", 5000 => "5km",   10000 => "10km", 20000 => "20km",   
      30000 => "30km", 40000 => "40km", 50000 => "50km", 100000 => "100km",
  };
  
  var ELEVATION_SCALE_NAMES as Dictionary = {
      // some rediculously small values for level ground (highly unlikely in the wild, but common on simulator)
      0.001 => "1mm", 0.0025 => "2.5mm", 0.005 => "5mm", 0.01 => "1cm", 
      0.025 => "2.5cm", 0.05 => "5cm", 0.1 => "10cm", 0.25 => "25cm", 
      0.5 => "50cm", 1 => "1m", 5 => "5m", 10 => "10m",  20 => "20m", 30 => "30m", 
      40 => "40m", 50 => "50m", 100 => "100m", 250 => "250m", 500 => "500m"
  };

  // cache some important maths to make everything faster
  // things set to -1 are set by setScreenSize()
  var _screenSize as Float = 360.0f; // default to venu2s screen size
  var _xHalf as Float = -1f;
  var _yHalf as Float = -1f;
  

  // benchmark same track loaded (just render track no activity running) using
  // average time over 1min of benchmark 
  // (just route means we always have a heap of points, and a small track does not bring the average down)
  // 13307us or 17718us - renderTrack manual code (_rotateCos, _rotateSin) 
  // 15681us or 17338us or 11996us - renderTrack manual code (rotateCosLocal, rotateSinLocal)  - use local variables might be faster lookup? 
  // 11162us or 18114us - rotateCosLocal, rotateSinLocal and hard code 180 as xhalf/yhalf
  // 22297us - renderTrack Graphics.AffineTransform

  // https://developer.garmin.com/connect-iq/reference-guides/monkey-c-reference/
  // Monkey C is a message-passed language. When a function is called, the virtual machine searches a hierarchy at runtime in the following order to find the function:
  // Instance members of the class
  // Members of the superclass
  // Static members of the class
  // Members of the parent module, and the parent modules up to the global namespace
  // Members of the superclass’s parent module up to the global namespace
  var _rotateCos = Math.cos(_rotationRad);
  var _rotateSin = Math.sin(_rotationRad);

  function initialize(breadcrumbContext as BreadcrumbContext) {
    _breadcrumbContext = breadcrumbContext;
    setScreenSize(360.0f, 50f); // start with known good size of the venu2s
  }

  function onActivityInfo(activityInfo as Activity.Info) as Void {
    // System.println(
    //     "store heading, current speed etc. so we can know how to render the "
    //     + "map");
    var currentHeading = activityInfo.currentHeading;
    if (currentHeading != null) {
      // -ve since x values increase down the page
      // extra 90 deg so it points to top of page
      _rotationRad = -currentHeading - Math.toRadians(90);
      _rotateCos = Math.cos(_rotationRad);
      _rotateSin = Math.sin(_rotationRad);
    }
  }

  function calculateScale(
      outerBoundingBox as[Float, Float, Float, Float]) as Float {
    if (_scale != null) {
      return _scale;
    }

    var xDistanceM = outerBoundingBox[2] - outerBoundingBox[0];
    var yDistanceM = outerBoundingBox[3] - outerBoundingBox[1];

    var maxDistanceM = maxF(xDistanceM, yDistanceM);

    if (maxDistanceM == 0)
    {
      // show 1m of space to avaoid division by 0
      maxDistanceM = 1;
    }
    // we want the whole map to be show on the screen, we have 360 pixels on the
    // venu 2s
    // but this would only work for sqaures, so 0.75 fudge factor for circle
    // watch face
    return _screenSize / maxDistanceM * 0.75;
  }

  function updateCurrentScale(outerBoundingBox as[Float, Float, Float, Float]) as Void {
    _currentScale = calculateScale(outerBoundingBox);
  }

  function getScaleSize() as [Number, Number] {
    return getScaleSizeGeneric(_currentScale, DESIRED_SCALE_PIXEL_WIDTH, SCALE_NAMES);
  }
  
  function getScaleSizeGeneric(scale as Float, desiredWidth as Float, scaleNames as Dictionary) as [Number, Number] {
    var foundDistanceM = 10;
    var foundPixelWidth = 0;
    // get the closest without going over
    // keys loads them in random order, we want the smallest first
    var keys = scaleNames.keys();
    keys.sort(null);
    for (var i = 0; i < keys.size(); ++i) {
      var distanceM = keys[i];
      var testPixelWidth = distanceM as Float * scale;
      if (testPixelWidth > desiredWidth) {
        break;
      }

      foundPixelWidth = testPixelWidth;
      foundDistanceM = distanceM;
    }

    return [foundPixelWidth, foundDistanceM];
  }

  function renderCurrentScale(dc as Dc) {
    
    var scaleData = getScaleSize();
    var pixelWidth = scaleData[0];
    var distanceM = scaleData[1];
    if (pixelWidth == 0)
    {
      return;
    }

    var foundName = SCALE_NAMES[distanceM];

    var y = _screenSize - 20;
    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(4);
    dc.drawLine(_xHalf - pixelWidth / 2.0f, y,
                _xHalf + pixelWidth / 2.0f, y);
    dc.drawText(_xHalf, y - 30, Graphics.FONT_XTINY, foundName,
                Graphics.TEXT_JUSTIFY_CENTER);
  }

  function renderUser(dc as Dc, centerPosition as RectangularPoint,
                      usersLastLocation as RectangularPoint) as Void {
    var triangleSizeY = 10;
    var triangleSizeX = 4;
    var userPosUnrotatedX =
        (usersLastLocation.x - centerPosition.x) * _currentScale;
    var userPosUnrotatedY =
        (usersLastLocation.y - centerPosition.y) * _currentScale;

    var userPosRotatedX =
        _rotateCos * userPosUnrotatedX - _rotateSin * userPosUnrotatedY;
    var userPosRotatedY =
        _rotateSin * userPosUnrotatedX + _rotateCos * userPosUnrotatedY;

    var triangleTopX = userPosRotatedX + _xHalf;
    var triangleTopY = userPosRotatedY + _yHalf - triangleSizeY;

    var triangleLeftX = triangleTopX - triangleSizeX;
    var triangleLeftY = triangleTopY + triangleSizeY * 2;

    var triangleRightX = triangleTopX + triangleSizeX;
    var triangleRightY = triangleLeftY;

    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_BLACK);
    dc.setPenWidth(6);
    dc.drawLine(triangleTopX, triangleTopY, triangleRightX, triangleRightY);
    dc.drawLine(triangleRightX, triangleRightY, triangleLeftX, triangleLeftY);
    dc.drawLine(triangleLeftX, triangleLeftY, triangleTopX, triangleTopY);
  }

  function renderTrack(dc as Dc, breadcrumb as BreadcrumbTrack,
                       colour as Graphics.ColorType,
                       centerPosition as RectangularPoint) as Void {
    dc.setColor(colour, Graphics.COLOR_BLACK);
    dc.setPenWidth(4);

    var size = breadcrumb.coordinates.size();
    var coordinatesRaw = breadcrumb.coordinates._internalArrayBuffer;

    var rotateCosLocal = _rotateCos;
    var rotateSinLocal = _rotateSin;

    // note: size is using the overload of memeory safe array
    // but we draw from the raw points
    if (size >= ARRAY_POINT_SIZE * 2) {
      var firstXScaledAtCenter =
          (coordinatesRaw[0] - centerPosition.x) * _currentScale;
      var firstYScaledAtCenter =
          (coordinatesRaw[1] - centerPosition.y) * _currentScale;
      var lastXRotated = _xHalf + rotateCosLocal * firstXScaledAtCenter -
                         rotateSinLocal * firstYScaledAtCenter;
      var lastYRotated = _yHalf + rotateSinLocal * firstXScaledAtCenter +
                         rotateCosLocal * firstYScaledAtCenter;
      for (var i = ARRAY_POINT_SIZE; i < size; i += ARRAY_POINT_SIZE) {
        var nextX = coordinatesRaw[i];
        var nextY = coordinatesRaw[i + 1];

        var nextXScaledAtCenter = (nextX - centerPosition.x) * _currentScale;
        var nextYScaledAtCenter = (nextY - centerPosition.y) * _currentScale;

        var nextXRotated = _xHalf + rotateCosLocal * nextXScaledAtCenter -
                           rotateSinLocal * nextYScaledAtCenter;
        var nextYRotated = _yHalf + rotateSinLocal * nextXScaledAtCenter +
                           rotateCosLocal * nextYScaledAtCenter;

        dc.drawLine(lastXRotated, lastYRotated, nextXRotated, nextYRotated);

        lastXRotated = nextXRotated;
        lastYRotated = nextYRotated;
      }
    }

    // dc.drawText(0, _yHalf + 50, Graphics.FONT_XTINY, "Head: " + _rotationRad,
    //             Graphics.TEXT_JUSTIFY_LEFT);
  }

  // maybe put this into another class that handle ui touch events etc.
  function renderUi(dc as Dc) as Boolean {
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
    dc.setPenWidth(1);

    var padding = _xHalf / 2.0f;
    var topText = _yHalf / 2.0f;
    switch(_clearRouteProgress) {
      case 0:
        break;
      case 1:
      case 3:
      {
        // press right to confirm, left cancels
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        dc.fillRectangle(0, 0, _xHalf, _screenSize);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        dc.fillRectangle(_xHalf, 0, _xHalf, _screenSize);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_xHalf - padding, _yHalf, Graphics.FONT_XTINY,
                  "N", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_xHalf + padding, _yHalf, Graphics.FONT_XTINY,
                  "Y", Graphics.TEXT_JUSTIFY_CENTER);
        var text = _clearRouteProgress == 1 ? "Clearing route, are you sure?" : "Last chance!!!";
        dc.drawText(_xHalf, topText, Graphics.FONT_XTINY,
                  text, Graphics.TEXT_JUSTIFY_CENTER);
        return true;
      }
      case 2:
      {
        // press left to confirm, right cancels
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        dc.fillRectangle(0, 0, _xHalf, _screenSize);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        dc.fillRectangle(_xHalf, 0, _xHalf, _screenSize);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_xHalf - padding, _yHalf, Graphics.FONT_XTINY,
                  "Y", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_xHalf + padding, _yHalf, Graphics.FONT_XTINY,
                  "N", Graphics.TEXT_JUSTIFY_CENTER);
        var text = "Confirm route clear";
        dc.drawText(_xHalf, topText, Graphics.FONT_XTINY,
                  text, Graphics.TEXT_JUSTIFY_CENTER);
        return true;
      }
    }

    // single line across the screen
    // dc.drawLine(0, yHalf, dc.getWidth(), yHalf);
    // var text = "LU Scale: " + _currentScale;
    // var font = Graphics.FONT_XTINY;
    // var textHeight = dc.getTextDimensions(text, font)[1];
    // dc.drawText(0, _yHalf - textHeight - 0.1, font, text,
    //             Graphics.TEXT_JUSTIFY_LEFT);

    // var text2 = "Scale: " + _scale;
    // var textHeight2 = dc.getTextDimensions(text2, font)[1];
    // dc.drawText(0, _yHalf + textHeight2 + 0.1, font, text2,
    //             Graphics.TEXT_JUSTIFY_LEFT);

    // clear route
    dc.drawText(clearRouteX, clearRouteY, Graphics.FONT_XTINY, "C", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    // current mode displayed
    var modeLetter = "T";
    switch(mode)
    {
      case MODE_NORMAL:
        modeLetter = "T";
        break;
      case MODE_ELEVATION:
        modeLetter = "E";
        break;
    }

    dc.drawText(modeSelectX, modeSelectY, Graphics.FONT_XTINY, modeLetter, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    if (mode == MODE_ELEVATION)
    {
      return false;
    }

    // make this a const
    var halfLineLength = 10;
    var lineFromEdge = 10;

    // plus at the top of screen
    dc.drawLine(_xHalf - halfLineLength, lineFromEdge, _xHalf + halfLineLength,
                lineFromEdge);
    dc.drawLine(_xHalf, lineFromEdge - halfLineLength, _xHalf,
                lineFromEdge + halfLineLength);

    // minus at the bottom
    dc.drawLine(_xHalf - halfLineLength, dc.getHeight() - lineFromEdge,
                _xHalf + halfLineLength, dc.getHeight() - lineFromEdge);

    // auto
    if (_scale != null) {
      dc.drawText(dc.getWidth() - lineFromEdge, _yHalf, Graphics.FONT_XTINY,
                  "S: " + _scale.format("%.2f"), Graphics.TEXT_JUSTIFY_RIGHT);
    } else {
      dc.drawText(dc.getWidth() - lineFromEdge, _yHalf, Graphics.FONT_XTINY,
                  "A", Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // M - default, moving is zoomed view, stopped if full view
    // S - stopped is zoomed view, moving is entire view
    var fvText = "M";
    // dirty hack, should pass the bool in another way
    // ui should be its own class, as should states
    if (!_zoomAtPace) {
      // zoom view
      fvText = "S";
    }
    dc.drawText(lineFromEdge, _yHalf, Graphics.FONT_XTINY, fvText,
                Graphics.TEXT_JUSTIFY_LEFT);

    // north facing N with litle cross
    // var nPosX = 295;
    // var nPosY = 85;
    return false;
  }

  function getDecIncAmount(direction as Number) as Float {
    var scaleData = getScaleSize();
    var currentPixelDistance = scaleData[0];
    // var distanceToDesired = DESIRED_SCALE_PIXEL_WIDTH - currentPixelDistance;
    // we are really close to the pixel distance, due to float rounding, we will consider this already 
    // there, and go up 2 windows instead of 1
    // think at this point I should just set the new scale, but id need to do something similar anyway
    // or if its really small, same issue
    // i really should store the index of the key for the scale, then calculate the float scale on the fly
    // that way index is determined and no round trip floating point errors.
    // the current strategy results in some zooms needing to be clicked twice, others once.
    // if (distanceToDesired < 2 || currentPixelDistance < 2)
    // {
    //   direction = direction * 2;
    // }
    var currentDistanceM = scaleData[1];
    var keys = SCALE_NAMES.keys();
    keys.sort(null);
    for (var i = 0; i < keys.size(); ++i) {
      var distanceM = keys[i];
      if (currentDistanceM == distanceM)
      {
          var nextScaleIndex = i - direction;
          if (nextScaleIndex >= keys.size())
          {
            nextScaleIndex = keys.size() - 1;
          }

          if (nextScaleIndex < 0)
          {
            nextScaleIndex = 0;
          }
          
          // we want the result to be 
          // DESIRED_SCALE_PIXEL_WIDTH = keys[nextScaleIndex] * _scale;
          var desiredScale = DESIRED_SCALE_PIXEL_WIDTH / keys[nextScaleIndex] as Float;
          // System.println("next scale: " + keys[nextScaleIndex]);
          // need some fudge factor to cross floating point error boundaries when needed
          var toInc = (desiredScale - _scale);
          return toInc;
      }
    }

    return direction * MIN_SCALE;
  }

  function incScale() as Void {
    if (mode == MODE_ELEVATION)
    {
      return;
    }

    if (_scale == null) {
      _scale = _currentScale;
    }
    _scale += getDecIncAmount(1);
  }

  function decScale() as Void {
    if (mode == MODE_ELEVATION)
    {
      return;
    }

    if (_scale == null) {
      _scale = _currentScale;
    }
    _scale += getDecIncAmount(-1);

    // prevent negative values
    // may need to go to lower scales to display larger maps (maybe like 0.05?)
    if (_scale < MIN_SCALE) {
      _scale = MIN_SCALE;
    }
  }

  function handleClearRoute(x as Number, y as Number) as Boolean
  {
    switch(_clearRouteProgress) {
      case 0:
        // press top left to start clear route
        if (   y > clearRouteY - halfHitboxSize 
            && y < clearRouteY + halfHitboxSize  
            && x > clearRouteX - halfHitboxSize
            && x < clearRouteX + halfHitboxSize)
        {
          _clearRouteProgress = 1;
          return true;
        }
        return false;
      case 1:
        // press right to confirm, left cancels
        if (x > _xHalf)
        {
            _clearRouteProgress = 2;
            return true;
        }
        _clearRouteProgress = 0;
        return true;
      
      case 2:
        // press left to confirm, right cancels
        if (x < _xHalf)
        {
            _clearRouteProgress = 3;
            return true;
        }
        _clearRouteProgress = 0;
        return true;
      case 3:
        // press right to confirm, left cancels
        if (x > _xHalf)
        {
            _breadcrumbContext.clearRoute();
        }
        _clearRouteProgress = 0;
        return true;
    }

    return false;
  }

  function resetScale() as Void { 
    if (mode == MODE_ELEVATION)
    {
      return;
    }
    _scale = null; 
  }

  function toggleZoomAtPace() as Void { 
    if (mode == MODE_ELEVATION)
    {
      return;
    }

    _zoomAtPace = !_zoomAtPace; 
  }
  function cycleMode() as Void
  {
    // System.println("mode cycled");
    // could just add one and check if over MODE_MAX?
    mode++;
    if (mode >= MODE_MAX)
    {
      mode = MODE_NORMAL;
    }
  }

  // things set to -1 are set by setScreenSize()
  var _xElevationStart as Float = -1f; // think this needs to depend on dpi?
  var _xElevationEnd as Float = -1f;
  var _yElevationHeight as Float = -1f;
  var _halfYElevationHeight as Float = -1f;
  var yElevationTop as Float = -1f;
  var yElevationBottom as Float = -1f;
  var clearRouteX as Float = -1f; 
  var clearRouteY as Float = -1f; 
  var modeSelectX as Float = -1f; 
  var modeSelectY as Float = -1f; 
  var hitboxSize as Float = 50f;
  var halfHitboxSize as Float = hitboxSize / 2.0f;

  function setScreenSize(size as Float, xElevationStart as Float) as Void
  {
    _xElevationStart = xElevationStart; 
    _screenSize = size;
    _xHalf = _screenSize / 2.0f;
    _yHalf = _screenSize / 2.0f;    
    _xElevationEnd = _screenSize - _xElevationStart;
    var xElevationFromCenter = _xHalf - _xElevationStart;
    _yElevationHeight = Math.sqrt(_xHalf * _xHalf - xElevationFromCenter * xElevationFromCenter) * 2 - 40;
    _halfYElevationHeight = _yElevationHeight / 2.0f;
    yElevationTop = _yHalf - _halfYElevationHeight;
    yElevationBottom = _yHalf + _halfYElevationHeight;    
    var offsetSize = Math.sqrt((_yHalf - halfHitboxSize )*(_yHalf - halfHitboxSize) / 2);
    // top left
    clearRouteX = _xHalf - offsetSize;
    clearRouteY = _yHalf - offsetSize;
    
    // top right
    modeSelectX = _xHalf + offsetSize;
    modeSelectY = _yHalf - offsetSize;
  }

  function renderElevationChart(
    dc as Dc, 
    hScale as Float, 
    vScale as Float,
    startAt as Float
  ) as Void {
    var hScaleData = getScaleSizeGeneric(hScale, DESIRED_SCALE_PIXEL_WIDTH, SCALE_NAMES);
    var hPixelWidth = hScaleData[0];
    var hDistanceM = hScaleData[1];
    var vScaleData = getScaleSizeGeneric(vScale, DESIRED_ELEV_SCALE_PIXEL_WIDTH, ELEVATION_SCALE_NAMES);
    var vPixelWidth = vScaleData[0];
    var vDistanceM = vScaleData[1];

    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
    dc.setPenWidth(1);
    
    // vertical and horizontal lines for extreems
    dc.drawLine(_xElevationStart, yElevationTop, _xElevationStart, yElevationBottom);
    dc.drawLine(_xElevationStart, _yHalf, _xElevationEnd, _yHalf);
    // border (does not look great)
    // dc.drawRectangle(_xElevationStart, _yHalf - _halfYElevationHeight, _screenSize - _xElevationStart * 2, _yElevationHeight);

    // horizontal lines vertical scale
    if (vPixelWidth != 0) // do not want infinite for loop
    {
      for (var i=0; i<_halfYElevationHeight ; i+=vPixelWidth)
      {
        var yTop = _yHalf - i;
        var yBottom = _yHalf + i;
        dc.drawLine(_xElevationStart, yTop, _xElevationEnd, yTop);
        dc.drawLine(_xElevationStart, yBottom, _xElevationEnd, yBottom);
      }
    }

    // vertical lines horizontal scale
    if (hPixelWidth != 0) // do not want infinite for loop
    {
      for (var i=_xElevationStart; i<_xElevationEnd ; i+=hPixelWidth)
      {
        dc.drawLine(i, yElevationTop, i, yElevationBottom);
      }
    }

    dc.drawText(0, _yHalf - 15, Graphics.FONT_XTINY, startAt.format("%.0f"), Graphics.TEXT_JUSTIFY_LEFT);
    if (vScale != 0) // prevent division by 0
    {
      var topScaleM = startAt + _halfYElevationHeight / vScale;
      var topText = topScaleM.format("%.0f") + "m";
      var textDim = dc.getTextDimensions(topText, Graphics.FONT_XTINY);
      dc.drawText(_xElevationStart, _yHalf - _halfYElevationHeight - textDim[1], Graphics.FONT_XTINY, topText, Graphics.TEXT_JUSTIFY_LEFT);
      var bottomScaleM = startAt - _halfYElevationHeight / vScale;
      dc.drawText(_xElevationStart, _yHalf + _halfYElevationHeight, Graphics.FONT_XTINY, bottomScaleM.format("%.0f") + "m", Graphics.TEXT_JUSTIFY_LEFT);
    }
    
    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(3);

    if (hPixelWidth != 0) // if statement makes sure that we can get a SCALE_NAMES[hDistanceM]
    {
      var hFoundName = SCALE_NAMES[hDistanceM];

      var y = _screenSize - 20;
      dc.drawLine(_xHalf - hPixelWidth / 2.0f, y, _xHalf + hPixelWidth / 2.0f, y);
      dc.drawText(_xHalf, y - 30, Graphics.FONT_XTINY, hFoundName, Graphics.TEXT_JUSTIFY_CENTER);
    }

    if (vPixelWidth != 0) // if statement makes sure that we can get a ELEVATION_SCALE_NAMES[vDistanceM]
    {
      var vFoundName = ELEVATION_SCALE_NAMES[vDistanceM];

      var x = _xHalf + DESIRED_SCALE_PIXEL_WIDTH/ 2.0f;
      var y = _screenSize - 20 - 5 - vPixelWidth / 2.0f;
      dc.drawLine(x , y - vPixelWidth / 2.0f, x, y + vPixelWidth / 2.0f);
      dc.drawText(x + 5, y - 15, Graphics.FONT_XTINY, vFoundName, Graphics.TEXT_JUSTIFY_LEFT);
      // var vectorFont = Graphics.getVectorFont(
      //   {
      //     // font face from https://developer.garmin.com/connect-iq/reference-guides/devices-reference/
      //     :face=>["VeraSans"], 
      //     :size=>16, 
      //     // :font=>Graphics.FONT_XTINY, 
      //     // :scale=>1.0f
      //   }
      // );
      // dc.drawAngledText(0, _yHalf, vectorFont, vFoundName, Graphics.TEXT_JUSTIFY_LEFT, 90);
      // dc.drawRadialText(0, _yHalf, vectorFont, vFoundName, Graphics.TEXT_JUSTIFY_LEFT, 90, 0, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
      // drawAngledText and drawRadialText not available :(
    }
  }

  function getElevationScale(track as BreadcrumbTrack, route as BreadcrumbTrack or Null) as [Float, Float, Float] {
    if (route == null || route.coordinates.pointSize() < 2)
    {
      var elevationChange = abs(track.elevationMax - track.elevationMin);
      return getElevationScaleRaw(track.distanceTotal, elevationChange, track.elevationMin + elevationChange / 2);
    }

    if (track.coordinates.pointSize() < 2)
    {
      // we did not have enough points on the track to get good elevation, we cannot use the default start at, 
      // since our route will be off the screen unless it has elevation that spreads over the default start at
      // we also do not have any points to get a good distance, so just use the route
      var elevationChange = abs(route.elevationMax - route.elevationMin);
      return getElevationScaleRaw(route.distanceTotal, elevationChange, route.elevationMin + elevationChange / 2);
    }
    
    // a combination of both
    var distance = maxF(track.distanceTotal, route.distanceTotal);
    var minElevation = minF(track.elevationMin, route.elevationMin);
    // abs really only needed until we get the first point (then max should always be more than min)
    var elevationChange = abs(maxF(track.elevationMax, route.elevationMax) - minElevation);
    var startAt = minElevation + elevationChange / 2;
    return getElevationScaleRaw(distance, elevationChange, startAt);
  }

  function getElevationScaleRaw(distance as Float, elevationChange as Float, startAt as Float) as [Float, Float, Float] {
    // clip to a a square (since we cannot see the edges of the circle)
    var totalXDistance = _screenSize - 2 * _xElevationStart;
    var totalYDistance = _yElevationHeight;

    if (distance == 0 && elevationChange == 0)
    {
      return [0f, 0f, startAt]; // do not divide by 0
    }

    if (distance == 0)
    {
        return [0f, totalYDistance / elevationChange, startAt]; // do not divide by 0
    }

    if (elevationChange == 0)
    {
        return [totalXDistance / distance, 0f, startAt]; // do not divide by 0
    }

    var hScale = totalXDistance / distance;
    var vScale = totalYDistance / elevationChange;

    return [hScale, vScale, startAt];
  }

  function renderTrackElevtion(
    dc as Dc, 
    track as BreadcrumbTrack, 
    colour as Graphics.ColorType, 
    hScale as Float, 
    vScale as Float,
    startAt as Float) as Void {
    var firstPoint = track.firstPoint();

    if (firstPoint == null)
    {
      return;
    }

    
    dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(1);

    var pointSize = track.coordinates.pointSize();

    // we do alot of distance calcualtion, much more expensive than the array itteration
    var prevX = _xElevationStart;
    var prevY = _yHalf + (startAt - firstPoint.altitude) * vScale;
    for (var i = 1; i < pointSize; i++) {
      var prevPoint = track.coordinates.getPoint(i - 1);
      var currPoint = track.coordinates.getPoint(i);

      if (prevPoint == null || currPoint == null)
      {
        break; // we cannot draw anymore
      }

      var xDistance = prevPoint.distanceTo(currPoint);
      var yDistance = prevPoint.altitude - currPoint.altitude;
      var currX = prevX + xDistance * hScale;
      var currY = prevY + yDistance * vScale;

      dc.drawLine(prevX, prevY, currX, currY);

      prevX = currX;
      prevY = currY;
    }
  }
}