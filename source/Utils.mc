import Toybox.Lang;
import Toybox.System;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Math;

const FLOAT_MIN = -340282346638528859811704183484516925440.0;
const FLOAT_MAX = 340282346638528859811704183484516925440.0;
const NUMBER_MAX = 0x7fffffff;

function maxF(lhs as Float, rhs as Float) as Float {
    if (lhs > rhs) {
        return lhs;
    }

    return rhs;
}

function maxN(lhs as Number, rhs as Number) as Number {
    if (lhs > rhs) {
        return lhs;
    }

    return rhs;
}

function minF(lhs as Float, rhs as Float) as Float {
    if (lhs < rhs) {
        return lhs;
    }

    return rhs;
}

function minN(lhs as Number, rhs as Number) as Number {
    if (lhs < rhs) {
        return lhs;
    }

    return rhs;
}

function abs(val as Float) as Float {
    if (val < 0) {
        return -val;
    }

    return val;
}

// from https://forums.garmin.com/developer/connect-iq/f/discussion/338071/testing-for-nan/1777041#1777041
function isnan(a as Float) as Boolean {
    return a != a;
}

class BitmapCreateError extends Lang.Exception {
    function initialize() {
        Exception.initialize();
    }

    function getErrorMessage() as String? {
        return "failed btmap create";
    }
}

// https://developer.garmin.com/connect-iq/core-topics/graphics/#graphics
// we must call get and keep the reference otherwise it can get cleanup up from under us
// not too bad for temporaries, but terrible for tiles (they can not be garbage collected)
function newBitmap(width as Number, height as Number) as Graphics.BufferedBitmap {
    var options = {
        :width => width,
        :height => height,
    };

    var bitmap = Graphics.createBufferedBitmap(options).get();
    if (!(bitmap instanceof BufferedBitmap)) {
        System.println("Could not allocate buffered bitmap");
        throw new BitmapCreateError();
    }

    return bitmap;
}

function logLevel(lvl as String, message as String) as Void {
    System.println("" + Time.now().value() + " " + lvl + " " + message);
}

function logE(message as String) as Void {
    logLevel("E", message);
}

function logD(message as String) as Void {
    logLevel("D", message);
}

(:debug)
function logT(message as String) as Void {
    logLevel("T", message);
}

(:release)
function logT(message as String) as Void {}

(:scaledbitmap)
function drawScaledBitmapHelper(
    dc as Dc,
    x as Numeric,
    y as Numeric,
    width as Numeric,
    height as Numeric,
    bitmap as BitmapType
) as Void {
    dc.drawScaledBitmap(x, y, width, height, bitmap);
}

(:noscaledbitmap)
function drawScaledBitmapHelper(
    dc as Dc,
    x as Numeric,
    y as Numeric,
    width as Numeric,
    height as Numeric,
    bitmap as BitmapType
) as Void {
    // is there any reason not to move this into main code and just use AffineTransform every time - even for devices that support drawScaledBitmap?
    // I assume one has a performance benifit over the other?
    // need to test which is better (or if there is any noticible difference)
    // todo cache this transform so we do nto need to recreate every time
    var tileScaleFactor = getApp()._breadcrumbContext.cachedValues.tileScaleFactor;
    var scaleMatrix = new AffineTransform();
    scaleMatrix.scale(tileScaleFactor, tileScaleFactor); // scale
    try {
        // a horrible fix for "Source must be native color format"
        // see https://forums.garmin.com/developer/connect-iq/f/discussion/360257/bitmap-native-color-format-venusq2
        // and https://forums.garmin.com/developer/connect-iq/i/bug-reports/bitmap-png-format-bug-fr-165-venu-sq-2
        // the packing formats in the drawbles must have automaticPalette="false" and possibly packingFormat="default"
        // but it then appears makeImageRequest tiles also fail (even when using :packingFormat => Communications.PACKING_FORMAT_DEFAULT)
        // dc.drawBitmap(x, y, bitmap);
        // need to add this as a user setting, test device is instinct 3 45mm. not sure if this is simulator bug, or if it happens on real deivce too (other reports seem to indicate it happens to real device)
        dc.drawBitmap2(x, y, bitmap, {
            :transform => scaleMatrix,
            // Use bilinear filtering for smoother results when rotating/scaling (less noticible tearing)
            :filterMode => Graphics.FILTER_MODE_BILINEAR,
        });
    } catch (e) {
        var message = e.getErrorMessage();
        logE("failed drawBitmap2 (drawScaledBitmapHelper): " + message);
        ++$.globalExceptionCounter;
        incNativeColourFormatErrorIfMessageMatches(message);
    }
}

function incNativeColourFormatErrorIfMessageMatches(message as String?) as Void {
    // message seems to be the only way, could not find type
    // full message is "Source must be native color format", but that was not comparing equal for some reason (perhaps trailing white space)
    if (message != null && message.find("native color format") != null) {
        ++$.sourceMustBeNativeColorFormatCounter;
    }
}

function padStart(str as String?, targetLength as Number, padChar as Char) as String {
    var currentStr = str == null ? "" : str;
    var currentLength = currentStr.length();

    if (targetLength <= 0 || currentLength >= targetLength) {
        return currentStr; // No padding needed or invalid target length
    }

    var paddingNeeded = targetLength - currentLength;
    var padding = "";

    // Build the padding string
    // Note: Repeated string concatenation can be inefficient in MonkeyC
    // for VERY long padding, but is usually fine for typical use cases.
    for (var i = 0; i < paddingNeeded; i++) {
        padding += padChar;
    }

    return padding + currentStr;
}

function stringReplaceFirst(
    originalString as String,
    target as String,
    replacement as String
) as String {
    var index = originalString.find(target);

    if (index == null) {
        return originalString; // Target not found, return original string
    }

    var newString =
        originalString.substring(0, index) +
        replacement +
        originalString.substring(index + target.length(), originalString.length());

    return newString;
}

function isHttpResponseCode(responseCode as Number) as Boolean {
    return responseCode > 0;
}

function distance(x1 as Float, y1 as Float, x2 as Float, y2 as Float) as Float {
    var xDist = x2 - x1;
    var yDist = y2 - y1;
    return Math.sqrt(xDist * xDist + yDist * yDist).toFloat();
}

function inHitbox(
    x as Number,
    y as Number,
    hitboxX as Float,
    hitboxY as Float,
    halfHitboxSize as Float
) as Boolean {
    return (
        y > hitboxY - halfHitboxSize &&
        y < hitboxY + halfHitboxSize &&
        x > hitboxX - halfHitboxSize &&
        x < hitboxX + halfHitboxSize
    );
}
