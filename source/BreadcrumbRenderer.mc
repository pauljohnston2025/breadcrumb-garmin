import Toybox.Activity;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

class BreadcrumbRenderer {
  var _scale as Float or Null = null;
  var _lastUsedScale = 0.0;
  var _rotationRad as Float = 90.0;  // heading in radians

  // chace some important maths to make everything faster
  var _xHalf = 360 / 2.0f;
  var _yHalf = 360 / 2.0f;
  var _rotateCos = Math.cos(_rotationRad);
  var _rotateSin = Math.sin(_rotationRad);

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
    return 360.0 / maxDistanceM * 0.75;
  }

  function renderTrack(dc as Dc, breadcrumb as BreadcrumbTrack,
                       colour as Graphics.ColorType,
                       centerPosition as RectangularPoint,
                       outerBoundingBox as[Float, Float, Float, Float],
                       usersLastLocation as RectangularPoint or Null) as Void {
    dc.setColor(colour, Graphics.COLOR_BLACK);
    dc.setPenWidth(4);
    var scale = calculateScale(outerBoundingBox);
    _lastUsedScale = scale;

    var size = breadcrumb.coordinates.size();
    var coordinatesRaw = breadcrumb.coordinates._internalArrayBuffer;

    // note: size is using the overload of memeory safe array
    // but we draw from the raw points
    if (size > 5) {
      for (var i = 0; i < size - 3; i += 3) {
        var startX = coordinatesRaw[i];
        var startY = coordinatesRaw[i + 1];
        // var startZ = coordinatesRaw[i + 2];
        var endX = coordinatesRaw[i + 3];
        var endY = coordinatesRaw[i + 4];
        // var endZ = coordinatesRaw[i + 5];

        var xStartScaledAtCenter = (startX - centerPosition.x) * scale;
        var yStartScaledAtCenter = (startY - centerPosition.y) * scale;
        var xEndScaledAtCenter = (endX - centerPosition.x) * scale;
        var yEndScaledAtCenter = (endY - centerPosition.y) * scale;

        var xStartRotated = _rotateCos * xStartScaledAtCenter -
                            _rotateSin * yStartScaledAtCenter;
        var yStartRotated = _rotateSin * xStartScaledAtCenter +
                            _rotateCos * yStartScaledAtCenter;
        var xEndRotated =
            _rotateCos * xEndScaledAtCenter - _rotateSin * yEndScaledAtCenter;
        var yEndRotated =
            _rotateSin * xEndScaledAtCenter + _rotateCos * yEndScaledAtCenter;

        dc.drawLine(xStartRotated + _xHalf, yStartRotated + _yHalf,
                    xEndRotated + _xHalf, yEndRotated + _yHalf);
      }
    }

    // dc.drawText(0, _yHalf + 50, Graphics.FONT_XTINY, "Head: " + _rotationRad,
    //             Graphics.TEXT_JUSTIFY_LEFT);

    if (usersLastLocation != null) {
      var triangleSizeY = 10;
      var triangleSizeX = 4;
      var userPosUnrotatedX = (usersLastLocation.x - centerPosition.x) * scale;
      var userPosUnrotatedY = (usersLastLocation.y - centerPosition.y) * scale;

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
  }

  // maybe put this into another class that handle ui touch events etc.
  function renderUi(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);

    // single line across the screen
    // dc.drawLine(0, yHalf, dc.getWidth(), yHalf);
    // var text = "LU Scale: " + _lastUsedScale;
    // var font = Graphics.FONT_XTINY;
    // var textHeight = dc.getTextDimensions(text, font)[1];
    // dc.drawText(0, _yHalf - textHeight - 0.1, font, text,
    //             Graphics.TEXT_JUSTIFY_LEFT);

    // var text2 = "Scale: " + _scale;
    // var textHeight2 = dc.getTextDimensions(text2, font)[1];
    // dc.drawText(0, _yHalf + textHeight2 + 0.1, font, text2,
    //             Graphics.TEXT_JUSTIFY_LEFT);

    // make this a const
    var halfLineLength = 15;
    var lineFromEdge = 25;

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
      dc.drawText(dc.getWidth(), _yHalf, Graphics.FONT_XTINY,
                  "S: " + _scale.format("%.2f"), Graphics.TEXT_JUSTIFY_RIGHT);
    } else {
      dc.drawText(dc.getWidth(), _yHalf, Graphics.FONT_XTINY, "Auto",
                  Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // FV - full view
    // CV - zoom view based on speed, or located at user coordinates
    var fvText = "ZV";
    // dirty hack, should pass the bool in another way
    // ui should be its own class, as should states
    if (Application.getApp()._breadcrumbContext.fullViewLocked) {
      // zoom view
      fvText = "FV";
    }
    dc.drawText(lineFromEdge, _yHalf, Graphics.FONT_XTINY, fvText,
                Graphics.TEXT_JUSTIFY_LEFT);

    // north facing N with litle cross
    var nPosX = 295;
    var nPosY = 85;
    
  }

  function incScale() as Void {
    if (_scale == null) {
      _scale = _lastUsedScale;
    }
    _scale += 0.05;
  }

  function decScale() as Void {
    if (_scale == null) {
      _scale = _lastUsedScale;
    }
    _scale -= 0.05;

    // prevent negative values
    // may need to go to lower scales to display larger maps (maybe like 0.05?)
    if (_scale < 0.05) {
      _scale = 0.05;
    }
  }

  function resetScale() as Void { _scale = null; }
}