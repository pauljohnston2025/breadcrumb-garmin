import Toybox.Activity;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

class BreadcrumbRenderer {
  var _scale as Float or Null = null;
  var _currentScale = 0.0;
  var _rotationRad as Float = 90.0;  // heading in radians
  var _zoomAtPace = true;

  // units in meters to label
  var SCALE_NAMES = {
      10 => "10m",     20 => "20m",     30 => "30m",       40 => "40m",
      50 => "50m",     100 => "100m",   250 => "250m",     500 => "500m",
      1000 => "1km",   2000 => "2km",   3000 => "3km",     4000 => "4km",
      5000 => "5km",   10000 => "10km", 20000 => "20km",   30000 => "30km",
      40000 => "40km", 50000 => "50km", 100000 => "100km",
  };

  // chace some important maths to make everything faster
  var _xHalf = 360 / 2.0f;
  var _yHalf = 360 / 2.0f;
  // might be a good idea to store points as Graphix.Points2D
  // but we need to offset them from center anyway and make a new point
  // could also use another matrix for matrix.translate()
  // could possibly do
  // moveToWatchface.TransformPoints(rotate.TransformPoints(scale.TransformPoints(offsetFromCenter.TransformPoints(currentPoints))))
  // not sure if all the array iteration will make it worse, or it will be done
  // in native caode and be faster suspect the marshalling between object
  // creation will make it slower
  var _rotationMatrix = new Graphics.AffineTransform();

  function initialize() {}

  function onActivityInfo(activityInfo as Activity.Info) as Void {
    // System.println(
    //     "store heading, current speed etc. so we can know how to render the "
    //     + "map");
    var currentHeading = activityInfo.currentHeading;
    if (currentHeading != null) {
      // -ve since x values increase down the page
      // extra 90 deg so it points to top of page
      _rotationRad = -currentHeading - Math.toRadians(90);
      _rotationMatrix.setToRotation(_rotationRad);
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
    return 360.0 / maxDistanceM * 0.75;
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

    var rotated = _rotationMatrix.transformPoint(
        [ userPosUnrotatedX, userPosUnrotatedY ]);

    var triangleTopX = rotated[0] + _xHalf;
    var triangleTopY = rotated[1] + _yHalf - triangleSizeY;

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

    // note: size is using the overload of memeory safe array
    // but we draw from the raw points
    if (size > 5) {
      var firstXScaledAtCenter =
          (coordinatesRaw[0] - centerPosition.x) * _currentScale;
      var firstYScaledAtCenter =
          (coordinatesRaw[1] - centerPosition.y) * _currentScale;
      var lastRotated = _rotationMatrix.transformPoint(
          [ firstXScaledAtCenter, firstYScaledAtCenter ]);
      lastRotated[0] += _xHalf;
      lastRotated[1] += _yHalf;
      for (var i = 3; i < size; i += 3) {
        var nextX = coordinatesRaw[i];
        var nextY = coordinatesRaw[i + 1];

        var nextXScaledAtCenter = (nextX - centerPosition.x) * _currentScale;
        var nextYScaledAtCenter = (nextY - centerPosition.y) * _currentScale;

        var nextRotated = _rotationMatrix.transformPoint(
            [ nextXScaledAtCenter, nextYScaledAtCenter ]);
        nextRotated[0] += _xHalf;
        nextRotated[1] += _yHalf;

        dc.drawLine(lastRotated[0], lastRotated[1], nextRotated[0],
                    nextRotated[1]);

        lastRotated = nextRotated;
      }
    }

    // dc.drawText(0, _yHalf + 50, Graphics.FONT_XTINY, "Head: " + _rotationRad,
    //             Graphics.TEXT_JUSTIFY_LEFT);
  }

  // maybe put this into another class that handle ui touch events etc.
  function renderUi(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
    dc.setPenWidth(1);

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

  function resetScale() as Void { _scale = null; }
  function toggleFullView() as Void { _zoomAtPace = !_zoomAtPace; }
}