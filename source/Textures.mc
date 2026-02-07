import Toybox.Lang;
import Toybox.Graphics;

// use with // dc.setStroke(getCheckerboardTexture());
function getCheckerboardTexture(
    width as Number,
    halfWidth as Number,
    colour as Number
) as Graphics.BitmapTexture {
    // checkerboard texture
    // texture docs are crap, this is the one example i could find https://forums.garmin.com/developer/connect-iq/f/discussion/292995/setstroke-and-bitmaptexture
    var bitmap = newBitmap(width, width);
    var bitmapDc = bitmap.getDc();
    bitmapDc.setColor(colour, Graphics.COLOR_TRANSPARENT);
    bitmapDc.clear();
    bitmapDc.fillRectangle(0, 0, halfWidth, halfWidth); // half colour and half transparent checkerboard (so both x and y are stripped)
    bitmapDc.fillRectangle(halfWidth, halfWidth, halfWidth, halfWidth); // half colour and half transparent checkerboard (so both x and y are stripped)

    return new Graphics.BitmapTexture({ :bitmap => bitmap });
}

function getHazardTexture(
    width as Number,
    halfWidth as Number,
    colour as Number
) as Graphics.BitmapTexture {
    // checkerboard texture
    // texture docs are crap, this is the one example i could find https://forums.garmin.com/developer/connect-iq/f/discussion/292995/setstroke-and-bitmaptexture
    var bitmap = newBitmap(width, width);
    var bDc = bitmap.getDc();
    bDc.setColor(colour, Graphics.COLOR_TRANSPARENT);

    // Draw two diagonal triangles to create a tiling stripe
    var pts = [
        [0, 0],
        [halfWidth, 0],
        [0, halfWidth],
    ];
    bDc.fillPolygon(pts);
    pts = [
        [width, halfWidth],
        [halfWidth, width],
        [width, width],
    ];
    bDc.fillPolygon(pts);

    return new Graphics.BitmapTexture({ :bitmap => bitmap });
}

function dotMatrixTexture(
    width as Number,
    halfWidth as Number,
    colour as Number
) as Graphics.BitmapTexture {
    var bitmap = newBitmap(4, 4);

    var bDc = bitmap.getDc();
    bDc.setColor(colour, Graphics.COLOR_TRANSPARENT);

    bDc.drawPoint(0, 0);
    bDc.drawPoint(2, 2);

    return new Graphics.BitmapTexture({ :bitmap => bitmap });
}

function polkaDotTexture(
    width as Number,
    halfWidth as Number,
    colour as Number
) as Graphics.BitmapTexture {
    var bitmap = newBitmap(width, width);
    var bDc = bitmap.getDc();

    var dotSize = (width / 4).toNumber();
    if (dotSize < 1) {
        dotSize = 1;
    }

    // Centered Dot
    bDc.setColor(colour, Graphics.COLOR_TRANSPARENT);
    bDc.fillCircle(halfWidth, halfWidth, dotSize);

    // Offset "half dots" at corners for perfect tiling
    // This ensures that dots appear staggered like real fabric
    bDc.fillCircle(0, 0, dotSize);
    bDc.fillCircle(width, 0, dotSize);
    bDc.fillCircle(0, width, dotSize);
    bDc.fillCircle(width, width, dotSize);

    return new Graphics.BitmapTexture({ :bitmap => bitmap });
}

function diamondTexture(
    width as Number,
    halfWidth as Number,
    colour as Number
) as Graphics.BitmapTexture {
    var bitmap = newBitmap(width, width);
    var bDc = bitmap.getDc();

    bDc.setColor(colour, Graphics.COLOR_TRANSPARENT);
    // Draw a diamond shape
    var pts = [
        [halfWidth, 0],
        [width, halfWidth],
        [halfWidth, width],
        [0, halfWidth],
    ];
    bDc.fillPolygon(pts);

    return new Graphics.BitmapTexture({ :bitmap => bitmap });
}

function getTexture(
    style as Number,
    width as Number,
    halfWidth as Number,
    colour as Number
) as Graphics.BitmapTexture or Number {
    try {
        if (style == TRACK_STYLE_CHECKERBOARD) {
            return getCheckerboardTexture(width, halfWidth, colour);
        } else if (style == TRACK_STYLE_HAZARD) {
            return getHazardTexture(width, halfWidth, colour);
        } else if (style == TRACK_STYLE_DOT_MATRIX) {
            return dotMatrixTexture(width, halfWidth, colour);
        } else if (style == TRACK_STYLE_POLKA_DOT) {
            return polkaDotTexture(width, halfWidth, colour);
        } else if (style == TRACK_STYLE_DIAMOND) {
            return diamondTexture(width, halfWidth, colour);
        }

        return -1;
    } catch (e) {
        logE("failed to generate texture: " + e.getErrorMessage());
        ++$.globalExceptionCounter;
        return -1;
    }
}

function isTextureStyle(style as Number) as Boolean {
    return style >= TRACK_STYLE_CHECKERBOARD && style <= TRACK_STYLE_DIAMOND;
}
