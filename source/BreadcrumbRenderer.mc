import Toybox.Activity;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

class BreadcrumbRenderer {
  var _breadcrumbContext as BreadcrumbContext;
  var _scale as Float or Null = null;
  var _currentScale = 0.0;
  var _rotationRad as Float = 90.0;  // heading in radians
  var _zoomAtPace = true;
  var _clearRouteProgress = 0;

  // units in meters to label
  var SCALE_NAMES = {
      10 => "10m",     20 => "20m",     30 => "30m",       40 => "40m",
      50 => "50m",     100 => "100m",   250 => "250m",     500 => "500m",
      1000 => "1km",   2000 => "2km",   3000 => "3km",     4000 => "4km",
      5000 => "5km",   10000 => "10km", 20000 => "20km",   30000 => "30km",
      40000 => "40km", 50000 => "50km", 100000 => "100km",
  };

  // cache some important maths to make everything faster
  var _screenSize = 360.0f;
  var _xHalf = _screenSize / 2.0f;
  var _yHalf = _screenSize / 2.0f;
  

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
    // we want the whole map to be show on the screen, we have 360 pixels on the
    // venu 2s
    // but this would only work for sqaures, so 0.75 fudge factor for circle
    // watch face
    return _screenSize / maxDistanceM * 0.75;
  }

  function updateCurrentScale(outerBoundingBox as[Float, Float, Float, Float]) {
    _currentScale = calculateScale(outerBoundingBox);
  }

  function renderCurrentScale(dc as Dc) {
    var desiredPixeleWidth = 100;
    var foundName = "unknown";
    var foundPixelWidth = 0;
    // get the closest without going over
    // keys loads them in random order, we want the smallest first
    var keys = SCALE_NAMES.keys();
    keys.sort(null);
    for (var i = 0; i < keys.size(); ++i) {
      var distanceM = keys[i];
      var testPixelWidth = distanceM * _currentScale;
      if (testPixelWidth > desiredPixeleWidth) {
        break;
      }

      foundPixelWidth = testPixelWidth;
      foundName = SCALE_NAMES[distanceM];
    }

    var y = 340;
    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(4);
    dc.drawLine(_xHalf - foundPixelWidth / 2.0f, y,
                _xHalf + foundPixelWidth / 2.0f, y);
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
    if (size > 5) {
      var firstXScaledAtCenter =
          (coordinatesRaw[0] - centerPosition.x) * _currentScale;
      var firstYScaledAtCenter =
          (coordinatesRaw[1] - centerPosition.y) * _currentScale;
      var lastXRotated = _xHalf + rotateCosLocal * firstXScaledAtCenter -
                         rotateSinLocal * firstYScaledAtCenter;
      var lastYRotated = _yHalf + rotateSinLocal * firstXScaledAtCenter +
                         rotateCosLocal * firstYScaledAtCenter;
      for (var i = 3; i < size; i += 3) {
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
      case 2:
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

    // clear route
    dc.drawText(65, 75, Graphics.FONT_XTINY, "C", Graphics.TEXT_JUSTIFY_RIGHT);

    // north facing N with litle cross
    var nPosX = 295;
    var nPosY = 85;
  }

  function incScale() as Void {
    if (_scale == null) {
      _scale = _currentScale;
    }
    _scale += 0.05;
  }

  function decScale() as Void {
    if (_scale == null) {
      _scale = _currentScale;
    }
    _scale -= 0.05;

    // prevent negative values
    // may need to go to lower scales to display larger maps (maybe like 0.05?)
    if (_scale < 0.05) {
      _scale = 0.05;
    }
  }

  function handleClearRoute(x as Number, y as Number) as Boolean
  {
    switch(_clearRouteProgress) {
      case 0:
        // press top left to start clear route
        if (y > 50 && y < 100 && x > 40 && x < 90) {
          _clearRouteProgress = 1;
          return true;
        }
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

  function resetScale() as Void { _scale = null; }
  function toggleFullView() as Void { _zoomAtPace = !_zoomAtPace; }
}