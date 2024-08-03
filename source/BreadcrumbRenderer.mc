import Toybox.Activity;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

class BreadcrumbRenderer {
  var _scale as Float = 0.1;
  var _heading as Float = 90.0;  // start at North
  var _speed as Float = 0.0;     // start at no speed

  function initialize() {}

  function onActivityInfo(activityInfo as Activity.Info) as Void {
    // System.println(
    //     "store heading, current speed etc. so we can know how to render the " +
    //     "map");
    var currentHeading = activityInfo.currentHeading;
    if (currentHeading != null) {
      _heading = currentHeading;
    }

    var currentSpeed = activityInfo.currentSpeed;
    if (currentSpeed != null) {
      _speed = currentSpeed;
    }
  }

  function renderTrack(dc as Dc, breadcrumb as BreadcrumbTrack,
                       colour as Graphics.ColorType,
                       currentPosition as RectangularPoint) as Void {
    dc.setColor(colour, Graphics.COLOR_BLACK);
    dc.setPenWidth(4);

    // test square
    // make this a const
    var xHalf = dc.getWidth() / 2;
    var yHalf = dc.getHeight() / 2;
    var width = 15;
    var widthScaled = width * _scale;
    dc.drawRectangle(xHalf - widthScaled / 2, yHalf - widthScaled / 2,
                     widthScaled, widthScaled);

    var size = breadcrumb.coordinates.size();
    var coordinatesRaw = breadcrumb.coordinates._internalArrayBuffer;

    // note: size is using the overload of memeory safe array
    // but we draw from the raw points
    if (size > 5) {
      for (var i = 0; i < size - 3; i+=3) {
        var startX = coordinatesRaw[i];
        var startY = coordinatesRaw[i + 1];
        // var startZ = coordinatesRaw[i + 2];
        var endX = coordinatesRaw[i + 3];
        var endY = coordinatesRaw[i + 4];
        // var endZ = coordinatesRaw[i + 5];

        dc.drawLine((startX - currentPosition.x) * _scale + xHalf,
                    (startY - currentPosition.y) * _scale + yHalf,
                    (endX - currentPosition.x) * _scale + xHalf,
                    (endY - currentPosition.y) * _scale + yHalf);
      }
    }
  }

  // maybe put this into another class that handle ui touch events etc.
  function renderUi(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);

    var xHalf = dc.getWidth() / 2;
    var yHalf = dc.getHeight() / 2;
    // single line across the screen
    // dc.drawLine(0, yHalf, dc.getWidth(), yHalf);
    var text = "Scale: " + _scale;
    var font = Graphics.FONT_XTINY;
    var textHeight = dc.getTextDimensions(text, font)[1];
    dc.drawText(0, yHalf - textHeight - 0.1, font, text,
                Graphics.TEXT_JUSTIFY_LEFT);

    // make this a const
    var halfLineLength = 15;
    var lineFromEdge = 25;

    // plus at the top of screen
    dc.drawLine(xHalf - halfLineLength, lineFromEdge, xHalf + halfLineLength,
                lineFromEdge);
    dc.drawLine(xHalf, lineFromEdge - halfLineLength, xHalf,
                lineFromEdge + halfLineLength);

    // minus at the bottom
    dc.drawLine(xHalf - halfLineLength, dc.getHeight() - lineFromEdge,
                xHalf + halfLineLength, dc.getHeight() - lineFromEdge);
  }

  function incScale() as Void { _scale += 0.001; }

  function decScale() as Void { _scale -= 0.001; }
}