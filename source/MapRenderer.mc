import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.PersistedContent;

class MapRenderer {
    // single dim array might be better performance?
    // Could do multidimensional array to make calling code slightly easier
    // todo: get screen size and factor in some amount of padding
    var _tileCache as TileCache;
    var _settings as Settings;
    var _cachedValues as CachedValues;

    function initialize(
        tileCache as TileCache,
        settings as Settings,
        cachedValues as CachedValues
    ) {
        // todo persist to storage and load from storage in init
        _tileCache = tileCache;
        _settings = settings;
        _cachedValues = cachedValues;
    }

    // returns true if tile was loaded from storage
    function seedTiles() as Boolean {
        var cachedValues = _cachedValues; // local lookup faster
        if (!_cachedValues.mapDataCanBeUsed) {
            // do not divide by zero my good friends
            // we do not have a scale calculated yet
            return false;
        }

        if (!_settings.mapEnabled) {
            return false;
        }

        if (_cachedValues.seeding()) {
            return false;
        }

        var tileCountX = cachedValues.tileCountX; // local lookup faster
        var tileCountY = cachedValues.tileCountY; // local lookup faster
        var firstTileX = cachedValues.firstTileX; // local lookup faster
        var firstTileY = cachedValues.firstTileY; // local lookup faster
        var tileZ = cachedValues.tileZ; // local lookup faster

        for (
            var y = -_settings.tileCachePadding;
            y < tileCountY + _settings.tileCachePadding;
            ++y
        ) {
            for (
                var x = -_settings.tileCachePadding;
                x < tileCountX + _settings.tileCachePadding;
                ++x
            ) {
                // seed it for the next render
                if (_tileCache.seedTile(firstTileX + x, firstTileY + y, tileZ)) {
                    return true; // we pulled from storage, or there is some other reason to stop seeding the tile
                }
            }
        }

        return false;
    }

    (:noImageTiles)
    function renderMapUnrotated(dc as Dc) as Void {
        if (!_settings.tileUrl.equals(COMPANION_APP_TILE_URL)) {
            if (!_settings.mapEnabled) {
                return;
            }

            var xHalfPhysical = _cachedValues.xHalfPhysical; // local lookup faster
            var yHalfPhysical = _cachedValues.yHalfPhysical; // local lookup faster

            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.clear();

            dc.drawText(
                xHalfPhysical,
                yHalfPhysical,
                Graphics.FONT_XTINY,
                "WEB\nTILE SERVER\nNOT SUPPORTED\nCONFIGURE TILE SERVER\nIN SETTINGS",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        renderMapUnrotatedInner(dc);
    }

    (:noCompanionTiles)
    function renderMapUnrotated(dc as Dc) as Void {
        if (_settings.tileUrl.equals(COMPANION_APP_TILE_URL)) {
            if (!_settings.mapEnabled) {
                return;
            }

            var xHalfPhysical = _cachedValues.xHalfPhysical; // local lookup faster
            var yHalfPhysical = _cachedValues.yHalfPhysical; // local lookup faster

            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.clear();

            dc.drawText(
                xHalfPhysical,
                yHalfPhysical,
                Graphics.FONT_XTINY,
                "COMPANION APP\nTILE SERVER\nNOT SUPPORTED\nCONFIGURE TILE SERVER\nIN SETTINGS",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        renderMapUnrotatedInner(dc);
    }

    (:noTileBorders)
    function drawTileBordersUnrotated(
        dc as Dc,
        xPixel as Number,
        yPixel as Number,
        tileScalePixelSize as Number
    ) as Void {
        unsupported(dc, "tile borders");
    }

    (:tileBorders)
    function drawTileBordersUnrotated(
        dc as Dc,
        xPixel as Number,
        yPixel as Number,
        tileScalePixelSize as Number
    ) as Void {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawRectangle(xPixel, yPixel, tileScalePixelSize, tileScalePixelSize);
    }

    (:companionTiles,:imageTiles)
    function renderMapUnrotated(dc as Dc) as Void {
        renderMapUnrotatedInner(dc);
    }
    function renderMapUnrotatedInner(dc as Dc) as Void {
        var cachedValues = _cachedValues; // local lookup faster
        if (!_cachedValues.mapDataCanBeUsed) {
            // do not divide by zero my good friends
            // we do not have a scale calculated yet
            return;
        }

        if (!_settings.mapEnabled) {
            return;
        }

        if (_settings.authMissing()) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.clear();
            // todo this should probably render to the raw dc, not the buffered one, since it may rotate out of view
            dc.drawText(
                _cachedValues.xHalfPhysical,
                _cachedValues.yHalfPhysical,
                Graphics.FONT_SYSTEM_MEDIUM,
                "AUTH TOKEN\nMISSING",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }
        
        if (!_settings.mapChoiceValid()) {
            unsupported(dc, "Map Choice");
            return;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var tileScalePixelSize = cachedValues.tileScalePixelSize; // local lookup faster
        var tileOffsetX = cachedValues.tileOffsetX; // local lookup faster
        var tileOffsetY = cachedValues.tileOffsetY; // local lookup faster
        var tileCountX = cachedValues.tileCountX; // local lookup faster
        var tileCountY = cachedValues.tileCountY; // local lookup faster
        var firstTileX = cachedValues.firstTileX; // local lookup faster
        var firstTileY = cachedValues.firstTileY; // local lookup faster
        var tileZ = cachedValues.tileZ; // local lookup faster
        var tileSize = _settings.tileSize;
        var useDrawBitmap = _settings.useDrawBitmap;

        for (var y = 0; y < tileCountY; ++y) {
            for (var x = 0; x < tileCountX; ++x) {
                var tileFromCache = _tileCache.getTile(firstTileX + x, firstTileY + y, tileZ); // seed it for the next render
                if (tileFromCache == null) {
                    continue;
                }

                if (
                    tileFromCache.bitmap.getWidth() != tileSize ||
                    tileFromCache.bitmap.getHeight() != tileSize
                ) {
                    badTileSize(dc);
                    return;
                }

                // Its best to have a 'scratch space' bitmap that we use for draws then rotate the whole thing
                // cant rotate individual tiles as you can see the seams between tiles
                // one large one then rotate looks much better, and is possibly faster
                // we must scale as the tile we picked is only close to the resolution we need
                var xPixel = tileOffsetX + x * tileScalePixelSize;
                var yPixel = tileOffsetY + y * tileScalePixelSize;
                if (useDrawBitmap) {
                    dc.drawBitmap(xPixel, yPixel, tileFromCache.bitmap);
                } else {
                    $.drawScaledBitmapHelper(
                        dc,
                        xPixel,
                        yPixel,
                        tileScalePixelSize,
                        tileScalePixelSize,
                        tileFromCache.bitmap
                    );
                }

                if (_settings.showTileBorders) {
                    drawTileBordersUnrotated(dc, xPixel, yPixel, tileScalePixelSize);
                }
            }
        }
    }

    (:noUnbufferedRotations)
    function renderMap(dc as Dc) as Void {}

    (:unbufferedRotations)
    function renderMap(dc as Dc) as Void {
        var cachedValues = _cachedValues; // local lookup faster
        if (!_cachedValues.mapDataCanBeUsed) {
            // we do not have a scale calculated yet
            return;
        }

        if (!_settings.mapEnabled) {
            return;
        }

        if (_settings.authMissing()) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(
                _cachedValues.xHalfPhysical,
                _cachedValues.yHalfPhysical,
                Graphics.FONT_SYSTEM_MEDIUM,
                "AUTH TOKEN\nMISSING",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        if (!_settings.mapChoiceValid()) {
            unsupported(dc, "Map Choice");
            return;
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var tileScalePixelSize = cachedValues.tileScalePixelSize; // local lookup faster
        var tileScaleFactor = cachedValues.tileScaleFactor; // local lookup faster
        var tileOffsetX = cachedValues.tileOffsetX; // local lookup faster
        var tileOffsetY = cachedValues.tileOffsetY; // local lookup faster
        var tileCountX = cachedValues.tileCountX; // local lookup faster
        var tileCountY = cachedValues.tileCountY; // local lookup faster
        var firstTileX = cachedValues.firstTileX; // local lookup faster
        var firstTileY = cachedValues.firstTileY; // local lookup faster
        var tileZ = cachedValues.tileZ; // local lookup faster
        var rotateAroundScreenX = cachedValues.rotateAroundScreenX; // local lookup faster
        var rotateAroundScreenY = cachedValues.rotateAroundScreenY; // local lookup faster
        var bufferedBitmapOffsetX = cachedValues.bufferedBitmapOffsetX; // local lookup faster
        var bufferedBitmapOffsetY = cachedValues.bufferedBitmapOffsetY; // local lookup faster
        var tileSize = _settings.tileSize; // local lookup faster
        var useDrawBitmap = _settings.useDrawBitmap; // local lookup faster

        // perhaps we should draw all tiles then draw all border lines in second for loop?
        // this for loop is noce though, as it only draws borders on the tiles that are drawn (and we have in our tile cache), not every possible tile on the screen
        var rotateCosNeg = 0f; // only calculate if we need it
        var rotateSinNeg = 0f; // only calculate if we need it
        if (_settings.showTileBorders) {
            rotateCosNeg = Math.cos(-cachedValues.rotationRad); // local lookup faster
            rotateSinNeg = Math.sin(-cachedValues.rotationRad); // local lookup faster
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
        }

        for (var y = 0; y < tileCountY; ++y) {
            for (var x = 0; x < tileCountX; ++x) {
                var tileFromCache = _tileCache.getTile(firstTileX + x, firstTileY + y, tileZ); // seed it for the next render
                if (tileFromCache == null) {
                    continue;
                }

                if (
                    tileFromCache.bitmap.getWidth() != tileSize ||
                    tileFromCache.bitmap.getHeight() != tileSize
                ) {
                    badTileSize(dc);
                    return;
                }

                // Its best to have a 'scratch space' bitmap that we use for draws then rotate the whole thing
                // cant rotate individual tiles as you can see the seams between tiles
                // one large one then rotate looks much better, and is possibly faster
                // we must scale as the tile we picked is only close to the resolution we need
                var xPos = (tileOffsetX + x * tileScalePixelSize).toFloat();
                var yPos = (tileOffsetY + y * tileScalePixelSize).toFloat();
                var xTranslate = rotateAroundScreenX - xPos;
                var yTranslate = rotateAroundScreenY - yPos;
                var xTranslate2 = bufferedBitmapOffsetX - xPos;
                var yTranslate2 = bufferedBitmapOffsetY - yPos;
                var rotationMatrix = new AffineTransform();
                // Apply transformations in REVERSE order of visual effect:
                rotationMatrix.translate(xTranslate, yTranslate); // move to center
                rotationMatrix.rotate(-cachedValues.rotationRad); // rotate
                rotationMatrix.translate(-xTranslate2, -yTranslate2); // move back to position
                rotationMatrix.scale(tileScaleFactor, tileScaleFactor); // scale

                // Error: Unhandled Exception
                // Time: 2025-04-19T13:31:58Z
                // Part-Number: 006-B3704-00
                // Firmware-Version: '19.05'
                // Language-Code: eng
                // ConnectIQ-Version: 5.1.1
                // Filename: BreadcrumbDataField
                // Appname: BreadcrumbDataField
                // Stack:
                //   - pc: 0x1000c98a
                //     File: 'BreadcrumbDataField\source\MapRenderer.mc'
                //     Line: 160
                //     Function: renderMap
                //   - pc: 0x1000ad04
                //     File: 'BreadcrumbDataField\source\BreadcrumbDataFieldView.mc'
                //     Line: 410
                //     Function: renderMain
                //   - pc: 0x1000b7f0
                //     File: 'BreadcrumbDataField\source\BreadcrumbDataFieldView.mc'
                //     Line: 293
                //     Function: onUpdate
                try {
                    if (useDrawBitmap) {
                        dc.drawBitmap(xPos, yPos, tileFromCache.bitmap);
                    } else {
                        dc.drawBitmap2(xPos, yPos, tileFromCache.bitmap, {
                            // :bitmapX =>
                            // :bitmapY =>
                            // :bitmapWidth =>
                            // :bitmapHeight =>
                            // :tintColor =>
                            :transform => rotationMatrix,
                            // Use bilinear filtering for smoother results when rotating/scaling (less noticible tearing)
                            :filterMode => Graphics.FILTER_MODE_BILINEAR,
                        });
                    }
                } catch (e) {
                    // not sure what this exception was see above
                    // simultor keeps getting InvalidValueException: Source must not use a color palette but I never use a colour pallete for this very reason
                    // seems to only be in render modes that render directly to dc, and not through the scratchpad
                    // also worked fine with vivoactive 5 (that always renders the bitmaps through drawBitmap2), but failed with the venu2s (my normal test device).
                    // purged the tmp dir AppData\Local\Temp\com.garmin.connectiq
                    // it seems to be wehn loading from an external tile server - so Communications.PACKING_FORMAT_DEFAULT in makeImageRequest must be the culprit (possibly vivoactive is always a png?).
                    // changing it to
                    // tileFromCache.bitmap.isCached() + " "
                    //  + " " + tileFromCache.bitmap
                    var message = e.getErrorMessage();
                    logE("failed drawBitmap2 (renderMap): " + message);
                    ++$.globalExceptionCounter;
                    incNativeColourFormatErrorIfMessageMatches(message);
                }
                if (_settings.showTileBorders) {
                    drawTileBorders(
                        dc,
                        x,
                        y,
                        tileOffsetX,
                        tileOffsetY,
                        tileScalePixelSize,
                        rotateSinNeg,
                        rotateCosNeg,
                        bufferedBitmapOffsetX,
                        bufferedBitmapOffsetY,
                        rotateAroundScreenX,
                        rotateAroundScreenY
                    );
                }
            }
        }
    }

    (:unbufferedRotations,:noTileBorders)
    function drawTileBorders(
        dc as Dc,
        x as Number,
        y as Number,
        tileOffsetX as Number,
        tileOffsetY as Number,
        tileScalePixelSize as Number,
        rotateSinNeg as Decimal,
        rotateCosNeg as Decimal,
        bufferedBitmapOffsetX as Float,
        bufferedBitmapOffsetY as Float,
        rotateAroundScreenX as Float,
        rotateAroundScreenY as Float
    ) as Void {
        unsupported(dc, "tile borders");
    }

    (:unbufferedRotations,:tileBorders)
    function drawTileBorders(
        dc as Dc,
        x as Number,
        y as Number,
        tileOffsetX as Number,
        tileOffsetY as Number,
        tileScalePixelSize as Number,
        rotateSinNeg as Decimal,
        rotateCosNeg as Decimal,
        bufferedBitmapOffsetX as Float,
        bufferedBitmapOffsetY as Float,
        rotateAroundScreenX as Float,
        rotateAroundScreenY as Float
    ) as Void {
        // we have to manually draw rotated lines, since we cannot draw to a buffered bitmap (taking up too much memory)
        // we could probably avoid drawing 2 where the tiles overlap, but then have to handle the outer tiles differently
        // its only a debug settings in a rarely used mode, so fine to do multiple draws
        var tlX = tileOffsetX + x * tileScalePixelSize;
        var tlY = tileOffsetY + y * tileScalePixelSize;
        var trX = tlX + tileScalePixelSize;
        var trY = tlY;

        var blX = tlX;
        var blY = tlY + tileScalePixelSize;
        var brX = trX;
        var brY = blY;

        var tlUnrotatedX = tlX - bufferedBitmapOffsetX;
        var tlUnrotatedY = tlY - bufferedBitmapOffsetY;
        var tlRotatedX =
            rotateAroundScreenX + rotateCosNeg * tlUnrotatedX - rotateSinNeg * tlUnrotatedY;
        var tlRotatedY =
            rotateAroundScreenY + (rotateSinNeg * tlUnrotatedX + rotateCosNeg * tlUnrotatedY);

        var trUnrotatedX = trX - bufferedBitmapOffsetX;
        var trUnrotatedY = trY - bufferedBitmapOffsetY;
        var trRotatedX =
            rotateAroundScreenX + rotateCosNeg * trUnrotatedX - rotateSinNeg * trUnrotatedY;
        var trRotatedY =
            rotateAroundScreenY + (rotateSinNeg * trUnrotatedX + rotateCosNeg * trUnrotatedY);

        var blUnrotatedX = blX - bufferedBitmapOffsetX;
        var blUnrotatedY = blY - bufferedBitmapOffsetY;
        var blRotatedX =
            rotateAroundScreenX + rotateCosNeg * blUnrotatedX - rotateSinNeg * blUnrotatedY;
        var blRotatedY =
            rotateAroundScreenY + (rotateSinNeg * blUnrotatedX + rotateCosNeg * blUnrotatedY);

        var brUnrotatedX = brX - bufferedBitmapOffsetX;
        var brUnrotatedY = brY - bufferedBitmapOffsetY;
        var brRotatedX =
            rotateAroundScreenX + rotateCosNeg * brUnrotatedX - rotateSinNeg * brUnrotatedY;
        var brRotatedY =
            rotateAroundScreenY + (rotateSinNeg * brUnrotatedX + rotateCosNeg * brUnrotatedY);

        // draw our 4 lines
        dc.drawLine(tlRotatedX, tlRotatedY, trRotatedX, trRotatedY);
        dc.drawLine(trRotatedX, trRotatedY, brRotatedX, brRotatedY);
        dc.drawLine(brRotatedX, brRotatedY, blRotatedX, blRotatedY);
        dc.drawLine(blRotatedX, blRotatedY, tlRotatedX, tlRotatedY);
    }

    function badTileSize(dc as Dc) as Void {
        var xHalfPhysical = _cachedValues.xHalfPhysical; // local lookup faster
        var yHalfPhysical = _cachedValues.yHalfPhysical; // local lookup faster

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        dc.clear();

        dc.drawText(
            xHalfPhysical,
            yHalfPhysical,
            Graphics.FONT_XTINY,
            "TILE SIZE OF TILE\nIS INCORRECT\nCLEAR CHACE OR\nCHANGE TILE SIZE SETTING",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
