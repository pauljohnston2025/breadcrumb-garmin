import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;

class BreadcrumbDataFieldBackground extends WatchUi.Drawable {

    hidden var mColor as ColorValue;

    function initialize() {
        var dictionary = {
            :identifier => "Background"
        };

        Drawable.initialize(dictionary);

        mColor = Graphics.COLOR_WHITE;
    }

    function setColor(color as ColorValue) as Void {
        mColor = color;
    }

    function draw(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, mColor);
        dc.clear();
    }

}
