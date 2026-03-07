import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.PersistedContent;
import Toybox.StringUtil;
import Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Communications;
using Toybox.Application.Storage;
using Toybox.Time;

enum /*TileDataType*/ {
    TILE_DATA_TYPE_64_COLOUR = 0,
    TILE_DATA_TYPE_BASE64_FULL_COLOUR = 1,
    TILE_DATA_TYPE_BLACK_AND_WHITE = 2,
}

function tileKeyHash(x as Number, y as Number, z as Number) as String {
    var string = x.toString() + "-" + y + "-" + z;

    // we can base64 encode and get a shorter unique string
    // toString() contains '-' characters, and base64 does not have hyphens
    if (string.length() <= 12) {
        return string;
    }

    var byteArr = new [9]b;
    byteArr.encodeNumber(x, Lang.NUMBER_FORMAT_SINT32, {
        :offset => 0,
        :endianness => Lang.ENDIAN_BIG,
    });
    byteArr.encodeNumber(y, Lang.NUMBER_FORMAT_SINT32, {
        :offset => 4,
        :endianness => Lang.ENDIAN_BIG,
    });
    byteArr.encodeNumber(z, Lang.NUMBER_FORMAT_UINT8, {
        :offset => 8,
        :endianness => Lang.ENDIAN_BIG,
    });
    return (
        StringUtil.convertEncodedString(byteArr, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :encoding => StringUtil.CHAR_ENCODING_UTF8,
        }) as String
    );
}

const NO_EXPIRY = -1;
const WRONG_DATA_TILE = -6000;
function expired(expiresAt as Number, now as Number) as Boolean {
    return expiresAt != NO_EXPIRY && expiresAt < now;
}

class Tile {
    var lastUsed as Number;
    var expiresAt as Number = NO_EXPIRY;
    var bitmap as Graphics.BufferedBitmap or WatchUi.BitmapResource;

    function initialize(_bitmap as Graphics.BufferedBitmap or WatchUi.BitmapResource) {
        self.lastUsed = Time.now().value();
        self.bitmap = _bitmap;
    }

    function setExpiresAt(expiresAt as Number) as Void {
        self.expiresAt = expiresAt;
    }

    function expiredAlready(now as Number) as Boolean {
        return expired(self.expiresAt, now);
    }

    function markUsed() as Void {
        lastUsed = Time.now().value();
    }
}

(:noCompanionTiles)
class JsonWebTileRequestHandler {
    function initialize(
        tileCache as TileCache,
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        tileCacheVersion as Number,
        onlySeedStorage as Boolean
    ) {}

    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void {}
}

(:companionTiles)
class JsonWebTileRequestHandler {
    var _tileCache as TileCache;
    var _tileKeyStr as String;
    var _tileCacheVersion as Number;
    var _onlySeedStorage as Boolean;
    var _x as Number;
    var _y as Number;
    var _z as Number;

    function initialize(
        tileCache as TileCache,
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        tileCacheVersion as Number,
        onlySeedStorage as Boolean
    ) {
        _tileCache = tileCache;
        _x = x;
        _y = y;
        _z = z;
        _tileKeyStr = tileKeyStr;
        _tileCacheVersion = tileCacheVersion;
        _onlySeedStorage = onlySeedStorage;
    }

    function handleErroredTile(responseCode as Number) as Void {
        _tileCache.addErroredTile(
            _tileKeyStr,
            _tileCacheVersion,
            responseCode.toString(),
            isHttpResponseCode(responseCode)
        );
    }

    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void {
        // do not store tiles in storage if the tile cache version does not match
        if (_tileCacheVersion != _tileCache._tileCacheVersion) {
            logE("failed seed cache version mismatch");
            return;
        }

        var settings = getApp()._breadcrumbContext.settings;
        var cachedValues = getApp()._breadcrumbContext.cachedValues;

        if (responseCode != 200) {
            // see error codes such as Communications.NETWORK_REQUEST_TIMED_OUT
            logE("json failed with: " + responseCode);
            if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                _tileCache._storageTileCache.addErroredTile(_x, _y, _z, _tileKeyStr, responseCode);
            }
            if (_onlySeedStorage) {
                return;
            }
            handleErroredTile(responseCode);
            return;
        }

        handleSuccessfulTile(data, true);
    }

    function handleSuccessfulTile(
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null,
        addToCache as Boolean
    ) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var cachedValues = getApp()._breadcrumbContext.cachedValues;
        // logT("handling success tile x: " + _x + " y: " + _y + " z: " + _z);

        if (!(data instanceof Dictionary)) {
            logE("wrong data type, not dict: " + data);
            if (addToCache) {
                if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                    _tileCache._storageTileCache.addWrongDataTile(_x, _y, _z, _tileKeyStr);
                }
            }
            if (_onlySeedStorage) {
                return;
            }
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "WD", false);
            return;
        }

        if (addToCache) {
            if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                _tileCache._storageTileCache.addJsonData(
                    _x,
                    _y,
                    _z,
                    _tileKeyStr,
                    data as Dictionary<PropertyKeyType, PropertyValueType>
                );
            }
        }

        if (_onlySeedStorage) {
            return;
        }

        // logT("data: " + data);
        var mapTile = data.get("data");
        if (!(mapTile instanceof String)) {
            logE("wrong data type, not string");
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "WD", false);
            return;
        }

        var type = data.get("type");
        if (type == null || !(type instanceof Number)) {
            // back compat
            logE("bad type for type: falling back: " + type);
            handle64ColourDataString(data.get("pId") as Number?, mapTile);
            return;
        }

        if (type == TILE_DATA_TYPE_64_COLOUR) {
            handle64ColourDataString(data.get("pId") as Number?, mapTile);
            return;
        } else if (type == TILE_DATA_TYPE_BASE64_FULL_COLOUR) {
            handleBase64FullColourDataString(mapTile);
            return;
        } else if (type == TILE_DATA_TYPE_BLACK_AND_WHITE) {
            handleBlackAndWhiteDataString(mapTile);
            return;
        }

        _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "UT", false);
    }

    function handle64ColourDataString(paletteId as Number?, mapTile as String) as Void {
        if (!(paletteId instanceof Number)) {
            logE("wrong paletteId type, not number: " + paletteId);
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "WPID", false);
            mustUpdate();
            return;
        }

        // logT("got tile string of length: " + mapTile.length());
        var bitmap = _tileCache.tileDataToBitmap64ColourString(paletteId, mapTile.toCharArray());
        if (bitmap == null) {
            logE("failed to parse bitmap");
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "FP", false);
            return;
        }

        var tile = new Tile(bitmap);
        _tileCache.addTile(_tileKeyStr, _tileCacheVersion, tile);
    }

    function handleBase64FullColourDataString(mapTile as String) as Void {
        var mapTileBytes =
            StringUtil.convertEncodedString(mapTile, {
                :fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            }) as ByteArray;
        // logT("got tile string of length: " + mapTile.length());
        var bitmap = _tileCache.tileDataToBitmapFullColour(mapTileBytes);
        if (bitmap == null) {
            logE("failed to parse bitmap");
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "FP", false);
            return;
        }

        var tile = new Tile(bitmap);
        _tileCache.addTile(_tileKeyStr, _tileCacheVersion, tile);
    }

    function handleBlackAndWhiteDataString(mapTile as String) as Void {
        // logT("got tile string of length: " + mapTile.length());
        var bitmap = _tileCache.tileDataToBitmapBlackAndWhite(mapTile.toCharArray());
        if (bitmap == null) {
            logE("failed to parse bitmap");
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "FP", false);
            return;
        }

        var tile = new Tile(bitmap);
        _tileCache.addTile(_tileKeyStr, _tileCacheVersion, tile);
    }
}

(:noCompanionTiles)
class JsonPelletLoadHandler {
    function initialize(tileCache as TileCache) {}

    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void {}
}

(:companionTiles)
class JsonPelletLoadHandler {
    var _tileCache as TileCache;

    function initialize(tileCache as TileCache) {
        _tileCache = tileCache;
    }

    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void {
        logD("handling JsonPelletLoadHandler");

        if (responseCode != 200) {
            logE("JsonPelletLoadHandler failed with: " + responseCode);
            return;
        }

        if (!(data instanceof Dictionary)) {
            logE("JsonPelletLoadHandler wrong data type, not dict: " + data);
            return;
        }

        logD("JsonPelletLoadHandler response: " + data);

        var palette = data.get("data");
        var id = data.get("id");

        _tileCache.updatePalette(id as Number?, palette as Array?);
    }
}

(:noImageTiles)
class ImageWebTileRequestHandler {
    function initialize(
        tileCache as TileCache,
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        fullTileKeyStr as String,
        tileCacheVersion as Number,
        onlySeedStorage as Boolean
    ) {}

    function handle(
        responseCode as Number,
        data as WatchUi.BitmapResource or Graphics.BitmapReference or Null
    ) as Void {}
}
(:imageTiles)
class ImageWebTileRequestHandler {
    var _tileCache as TileCache;
    var _tileKeyStr as String;
    var _fullTileKeyStr as String;
    var _tileCacheVersion as Number;
    var _onlySeedStorage as Boolean;
    var _x as Number;
    var _y as Number;
    var _z as Number;

    function initialize(
        tileCache as TileCache,
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        fullTileKeyStr as String,
        tileCacheVersion as Number,
        onlySeedStorage as Boolean
    ) {
        _tileCache = tileCache;
        _x = x;
        _y = y;
        _z = z;
        _tileKeyStr = tileKeyStr;
        _fullTileKeyStr = fullTileKeyStr;
        _tileCacheVersion = tileCacheVersion;
        _onlySeedStorage = onlySeedStorage;
    }

    function handleErroredTile(responseCode as Number) as Void {
        _tileCache.addErroredTile(
            _tileKeyStr,
            _tileCacheVersion,
            responseCode.toString(),
            isHttpResponseCode(responseCode)
        );
    }

    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void {
        // do not store tiles in storage if the tile cache version does not match
        if (_tileCacheVersion != _tileCache._tileCacheVersion) {
            logE("failed seed cache version mismatch");
            return;
        }

        var settings = getApp()._breadcrumbContext.settings;
        var cachedValues = getApp()._breadcrumbContext.cachedValues;

        if (responseCode != 200) {
            // see error codes such as Communications.NETWORK_REQUEST_TIMED_OUT
            logE("image failed with: " + responseCode);
            if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                _tileCache._storageTileCache.addErroredTile(
                    _x,
                    _y,
                    _z,
                    _fullTileKeyStr,
                    responseCode
                );
            }
            if (_onlySeedStorage) {
                return;
            }
            handleErroredTile(responseCode);
            return;
        }

        handleSuccessfulTile(data, true);
    }

    function handleSuccessfulTile(
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null,
        addToCache as Boolean
    ) as Void {
        var settings = getApp()._breadcrumbContext.settings;
        var cachedValues = getApp()._breadcrumbContext.cachedValues;
        // logT("handling success tile x: " + _x + " y: " + _y + " z: " + _z);
        if (
            data == null ||
            (!(data instanceof WatchUi.BitmapResource) &&
                !(data instanceof Graphics.BitmapReference))
        ) {
            logE("wrong data type not image");
            if (addToCache) {
                if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                    _tileCache._storageTileCache.addWrongDataTile(_x, _y, _z, _tileKeyStr);
                }
            }
            if (_onlySeedStorage) {
                return;
            }
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "WD", false);
            return;
        }

        if (data instanceof Graphics.BitmapReference) {
            // need to keep it in memory all the time, if we use the reference only it can be deallocated by the graphics memory pool
            // https://developer.garmin.com/connect-iq/core-topics/graphics/
            data = data.get();
        }

        if (data == null || !(data instanceof WatchUi.BitmapResource)) {
            logE("data bitmap was null or not a bitmap");
            if (addToCache) {
                if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                    _tileCache._storageTileCache.addWrongDataTile(_x, _y, _z, _tileKeyStr);
                }
            }
            if (_onlySeedStorage) {
                return;
            }
            _tileCache.addErroredTile(_tileKeyStr, _tileCacheVersion, "WD", false);
            return;
        }

        if (addToCache) {
            if (settings.cacheTilesInStorage || cachedValues.seeding()) {
                _tileCache._storageTileCache.addBitmap(_x, _y, _z, _fullTileKeyStr, data);
            }
        }

        if (_onlySeedStorage) {
            return;
        }

        // we have to downsample the tile, not recommended, as this mean we will have to request the same tile multiple times (cant save big tiles around anywhere)
        // also means we have to use scratch space to draw the tile and downsample it

        // if (data.getWidth() != settings.tileSize || data.getHeight() != settings.tileSize) {
        //     // dangerous large bitmap could cause oom, buts its the only way to upscale the image and then slice it
        //     // we cannot downscale because we would be slicing a pixel in half
        //     // I guess we could just figure out which pixels to double up on?
        //     // anyone using an external tile server should be setting their tileSize to 256, but perhaps some devices will run out of memory?
        //     // if users are using a smaller size it should be a multiple of 256.
        //     // if its not, we will stretch the image then downsize, if its already a multiple we will use the image as is (optimal)
        //     var maxDim = maxN(data.getWidth(), data.getHeight()); // should be equal (every time server i know of is 256*256), but who knows
        //     var pixelsPerTile = maxDim / cachedValues.smallTilesPerScaledTile.toFloat();
        //     var sourceBitmap = data;
        //     if (
        //         Math.ceil(pixelsPerTile) != settings.tileSize ||
        //         Math.floor(pixelsPerTile) != settings.tileSize
        //     ) {
        //         // we have an anoying situation - stretch/reduce the image
        //         var scaleUpSize = cachedValues.smallTilesPerScaledTile * settings.tileSize;
        //         var scaleFactor = scaleUpSize / maxDim.toFloat();
        //         var upscaledBitmap = newBitmap(scaleUpSize, scaleUpSize);
        //         var upscaledBitmapDc = upscaledBitmap.getDc();

        //         var scaleMatrix = new AffineTransform();
        //         scaleMatrix.scale(scaleFactor, scaleFactor); // scale

        //         try {
        //             upscaledBitmapDc.drawBitmap2(0, 0, sourceBitmap, {
        //                 :transform => scaleMatrix,
        //                 // Use bilinear filtering for smoother results when rotating/scaling (less noticible tearing)
        //                 :filterMode => Graphics.FILTER_MODE_BILINEAR,
        //             });
        //         } catch (e) {
        // var message = e.getErrorMessage();
        // logE("failed drawBitmap2 (handleSuccessfulTile): " + message);
        // ++$.globalExceptionCounter;
        // incNativeColourFormatErrorIfMessageMatches(message);
        //         }
        //         // logT("scaled up to: " + upscaledBitmap.getWidth() + " " + upscaledBitmap.getHeight());
        //         // logT("from: " + sourceBitmap.getWidth() + " " + sourceBitmap.getHeight());
        //         sourceBitmap = upscaledBitmap; // resume what we were doing as if it was always the larger bitmap
        //     }

        //     var croppedSection = newBitmap(settings.tileSize, settings.tileSize);
        //     var croppedSectionDc = croppedSection.getDc();
        //     var xOffset = _tileKeyStr.x % cachedValues.smallTilesPerScaledTile;
        //     var yOffset = _tileKeyStr.y % cachedValues.smallTilesPerScaledTile;
        //     // logT("tile: " + _tileKeyStr);
        //     // logT("croppedSection: " + croppedSection.getWidth() + " " + croppedSection.getHeight());
        //     // logT("source: " + sourceBitmap.getWidth() + " " + sourceBitmap.getHeight());
        //     // logT("drawing from: " + xOffset * settings.tileSize + " " + yOffset * settings.tileSize);
        //     croppedSectionDc.drawBitmap(
        //         -xOffset * settings.tileSize,
        //         -yOffset * settings.tileSize,
        //         sourceBitmap
        //     );

        //     data = croppedSection;
        // }

        var tile = new Tile(data);
        _tileCache.addTile(_tileKeyStr, _tileCacheVersion, tile);
    }
}

const TILES_KEY = "tileKeys";
const TILES_VERSION_KEY = "tilesVersion";
const TILES_STORAGE_VERSION = 4; // update this every time the tile format on disk changes, so we can purge of the old tiles on startup
const TILES_TILE_PREFIX = "tileData";
const TILES_META_PREFIX = "tileMeta";

enum /* StorageTileType */ {
    STORAGE_TILE_TYPE_DICT = 0,
    STORAGE_TILE_TYPE_BITMAP = 1,
    STORAGE_TILE_TYPE_ERRORED = 2,
}

// tiles are stored as
// TILES_KEY => list of all known tile keys in storage, this is kept in memory so we can do quick lookups and know what to delete
// <TILES_TILE_PREFIX><TILEKEY> => the raw tile data
// <TILES_META_PREFIX><TILEKEY> => [<lastUsed>, <tileType>, <expiresAt>, <type specific data>] only used when fetching tile, or when trying to find out which tile to remove based on lastUsed

// <type specific data> for
// STORAGE_TILE_TYPE_DICT -> nothing
// STORAGE_TILE_TYPE_BITMAP -> nothing
// STORAGE_TILE_TYPE_ERRORED -> the error code

// tile format returned is [<httpresponseCode>, <tileData>]
typedef StorageTileDataType as [Number, Dictionary or WatchUi.BitmapResource or Null];

// raw we request tiles stored directly on the watch for future use

(:noStorage)
class StorageTileCache {
    var _pageCount as Number = 0;
    var _totalTileCount as Number = 0;
    var _pageSizes as Array<Number> = [0];
    function initialize(settings as Settings, cachedValues as CachedValues) {}
    function setup() as Void {}

    function get(tileKeyStr as String) as StorageTileDataType? {
        return null;
    }
    function haveTile(tileKeyStr as String) as Boolean {
        return false;
    }
    function addErroredTile(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        responseCode as Number
    ) as Void {}
    function addWrongDataTile(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String
    ) as Void {}
    function addJsonData(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        data as Dictionary<PropertyKeyType, PropertyValueType>
    ) as Void {}
    function addBitmap(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        bitmap as WatchUi.BitmapResource
    ) as Void {}
    function clearValues() as Void {}
    function setNewPageCount(newPageCount as Number) as Void {}
}

(:storage)
class StorageTileCache {
    // The Storage module does not allow querying the current keys, so we would have to query every possible tile to get the oldest and be able to remove it.
    // To manage memory, we will store what tiles we know exist in pages, and be able to purge them ourselves.
    var _settings as Settings;
    var _cachedValues as CachedValues;

    // we store the tiles into pages based on the tile keys hash, this is so we only have to load small chunks of known keys at a time (if we try and store all the keys we quickly run out of memory)
    // 1 page is the most cpu efficient for reading, but limits the max number of tiles we can store
    var _pageCount as Number = 1;
    var _totalTileCount as Number = 0;
    var _currentPageIndex as Number = -1; // -1 indicates no page is loaded
    var _currentPageKeys as Array<String> = [];
    var _pageSizes as Array<Number> = [0];
    private var _lastEvictedPageIndex as Number = 0;
    private var _maxPageSize as Number = 0;

    function initialize(settings as Settings, cachedValues as CachedValues) {
        var tilesVersion = Storage.getValue(TILES_VERSION_KEY);
        if (tilesVersion != null && (tilesVersion as Number) != TILES_STORAGE_VERSION) {
            Storage.clearValues(); // we have to purge all storage (even our routes, since we have no way of cleanly removing the old storage keys (without having back compat for each format))
        }
        safeSetStorage(TILES_VERSION_KEY, TILES_STORAGE_VERSION);

        _settings = settings;
        _cachedValues = cachedValues;

        // Instead of loading all keys, we load the total count of tiles across all pages.
        var totalCount = Storage.getValue("totalTileCount");
        if (totalCount instanceof Number) {
            _totalTileCount = totalCount;
        }
    }

    private function pageCountUpdated() as Void {
        if (_pageCount <= 0) {
            _pageCount = 1;
        }
        _pageSizes = new [_pageCount] as Array<Number>;
        for (var i = 0; i < _pageSizes.size(); i++) {
            _pageSizes[i] = 0;
        }

        // Calculate the maximum allowed size for a single page to prevent memory issues.
        var idealPageSize = _settings.storageTileCacheSize / _pageCount;
        _maxPageSize = (idealPageSize * 1.1).toNumber();
    }

    function setup() as Void {
        // we have to leave _pageCount as 1 in the constructor because the setting have not loaded yet
        _pageCount = _settings.storageTileCachePageCount;
        pageCountUpdated();
        populateInitialPageSizes();
        if (_settings.storageTileCacheSize < _totalTileCount) {
            // Purge excess tiles if the cache size has been reduced.
            var numberToEvict = _totalTileCount - _settings.storageTileCacheSize;
            for (var i = 0; i < numberToEvict; ++i) {
                evictLeastRecentlyUsedTile();
            }
        }
    }

    private function populateInitialPageSizes() as Void {
        for (var i = 0; i < _pageSizes.size(); i++) {
            loadPage(i);
            _pageSizes[i] = _currentPageKeys.size();
        }
    }

    private function pageStorageKey(pageIndex as Number) as String {
        return TILES_KEY + "_" + pageIndex;
    }

    private function loadPage(pageIndex as Number) as Void {
        if (_currentPageIndex == pageIndex) {
            return; // Page is already loaded.
        }

        // logT("Loading storage page: " + pageIndex);

        // Release memory of the old page's keys before loading the new one.
        _currentPageKeys = [];
        var page = Storage.getValue(pageStorageKey(pageIndex));

        if (page instanceof Array) {
            _currentPageKeys = page as Array<String>;
        }
        // No else needed, _currentPageKeys is already an empty array.
        _currentPageIndex = pageIndex;
    }

    private function saveCurrentPage() as Void {
        if (_currentPageIndex != -1) {
            var pageKey = pageStorageKey(_currentPageIndex);
            Storage.setValue(pageKey, _currentPageKeys as Array<PropertyValueType>);
        }
    }

    // this function needs to spread out amongst pages, but also should favour a page for a few tiles in a row
    // so we do not have a heap of page loads when we do 'for y { for x { ... } }'
    private function getPageIndexForKey(x as Number, y as Number, z as Number) as Number {
        if (_pageCount <= 1) {
            // Optimise for a single page.
            return 0;
        }

        // Use bitwise shifting to pack z, gridY, and gridX into a single 64-bit Long.
        // This is extremely robust and avoids "magic number" multipliers that can fail
        // with large coordinates.
        var combinedId = (z.toLong() << 59) | (y.toLong() << 30) | x.toLong();

        var res = absN((combinedId % _pageCount).toNumber());
        // logT("tile: " + x + "-" + y + "-" + z + " page: " + res);
        return res;
    }

    private function metaKey(tileKeyStr as String) as String {
        return TILES_META_PREFIX + tileKeyStr;
    }

    private function tileKey(tileKeyStr as String) as String {
        return TILES_TILE_PREFIX + tileKeyStr;
    }

    function get(tileKeyStr as String) as StorageTileDataType? {
        // if we are only a single page, load and do a quicker check (it should already be loaded)
        // if we are a multi page, we will spend more time loading the page then we would the meta data key, so just load the meta data
        if (_pageCount == 1) {
            loadPage(0);
            if (_currentPageKeys.indexOf(tileKeyStr) < 0) {
                // we do not have the tile key
                return null;
            }
        }

        var metaKeyStr = metaKey(tileKeyStr);
        var tileMeta = Storage.getValue(metaKeyStr);
        if (tileMeta == null || !(tileMeta instanceof Array) || tileMeta.size() < 3) {
            return null;
        }

        var epoch = Time.now().value();
        var expiresAt = tileMeta[2] as Number;
        if (expired(expiresAt, epoch)) {
            logE("tile expired" + tileMeta);
            // todo should we evict the tile now?
            return null;
        }

        tileMeta[0] = epoch;
        safeSetStorage(metaKeyStr, tileMeta);

        switch (tileMeta[1] as Number) {
            case STORAGE_TILE_TYPE_DICT: // fallthrough
            // bitmap has to just load as a single image (we cannot slice it because we cannot store buffered bitmaps, only the original bitmap), it could be over the 32Kb limit, but we have no other choice
            case STORAGE_TILE_TYPE_BITMAP: 
                // no need to check type of the getValue call, handling code checks it
                return [
                    200,
                    Storage.getValue(tileKey(tileKeyStr)) as Dictionary or WatchUi.BitmapResource,
                ]; // should always fit into the 32Kb size
            case STORAGE_TILE_TYPE_ERRORED:
                if (tileMeta.size() < 4) {
                    logE("bad tile metadata in storage for error tile" + tileMeta);
                    return null;
                }
                var responseCode = tileMeta[3] as Number;
                if (responseCode == WRONG_DATA_TILE) {
                    return [200, null]; // they normally come from 200 responses, with null data
                }
                return [responseCode, null];
        }

        return null;
    }

    function haveTile(tileKeyStr as String) as Boolean {
        // need to check for expired tiles
        // we could call get, but that also loads the tile data, and increments the "lastUsed" time

        // if we are only a single page, load and do a quicker check (it should already be loaded)
        // if we are a multi page, we will spend more time loading the page then we would the meta data key, so just load the meta data
        if (_pageCount == 1) {
            loadPage(0);
            if (_currentPageKeys.indexOf(tileKeyStr) < 0) {
                // we do not have the tile key
                return false;
            }
        }

        var metaKeyStr = metaKey(tileKeyStr);
        var tileMeta = Storage.getValue(metaKeyStr);
        if (tileMeta == null || !(tileMeta instanceof Array) || tileMeta.size() < 3) {
            return false;
        }

        var epoch = Time.now().value();
        var expiresAt = tileMeta[2] as Number;
        if (expired(expiresAt, epoch)) {
            logE("tile expired" + tileMeta);
            return false;
        }

        return true;
    }

    function addErroredTile(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        responseCode as Number
    ) as Void {
        var epoch = Time.now().value();
        var settings = getApp()._breadcrumbContext.settings;
        var expiresAt =
            epoch +
            (isHttpResponseCode(responseCode)
                ? settings.httpErrorTileTTLS
                : settings.errorTileTTLS);
        addMetaData(x, y, z, tileKeyStr, [
            epoch,
            STORAGE_TILE_TYPE_ERRORED,
            expiresAt,
            responseCode,
        ]);
    }

    function addWrongDataTile(x as Number, y as Number, z as Number, tileKeyStr as String) as Void {
        var epoch = Time.now().value();
        var settings = getApp()._breadcrumbContext.settings;
        var expiresAt = epoch + settings.errorTileTTLS;
        addMetaData(x, y, z, tileKeyStr, [
            epoch,
            STORAGE_TILE_TYPE_ERRORED,
            expiresAt,
            WRONG_DATA_TILE,
        ]);
    }

    function addJsonData(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        data as Dictionary<PropertyKeyType, PropertyValueType>
    ) as Void {
        addHelper(STORAGE_TILE_TYPE_DICT, x, y, z, tileKeyStr, data);
    }

    function addHelper(
        type as Number,
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        data as Dictionary<PropertyKeyType, PropertyValueType> or WatchUi.BitmapResource
    ) as Void {
        if (addMetaData(x, y, z, tileKeyStr, [Time.now().value(), type, NO_EXPIRY])) {
            safeAdd(tileKey(tileKeyStr), data);
        }
    }

    function addBitmap(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        bitmap as WatchUi.BitmapResource
    ) as Void {
        // bitmaps can be larger than the allowed 32kb limit, we must store it as 4 smaller bitmaps
        // todo slice the bitmap into small chunks (4 should always be enough, hard code for now)
        // this is not currently possible, since we can only draw to a buffered bitmap, but cannot save the buffered bitmap to storage
        // so we have to hope the tile size fits into storage
        addHelper(STORAGE_TILE_TYPE_BITMAP, x, y, z, tileKeyStr, bitmap);
    }

    private function addMetaData(
        x as Number,
        y as Number,
        z as Number,
        tileKeyStr as String,
        metaData as Array<PropertyValueType>
    ) as Boolean {
        var pageIndex = getPageIndexForKey(x, y, z);
        loadPage(pageIndex);

        // This is a new tile.
        _currentPageKeys.add(tileKeyStr);
        var _currentPageSize = 0;
        if (pageIndex >= 0 && pageIndex < _pageSizes.size()) {
            // never meant to not be within range, but monkeyc explodes if it isn't
            _pageSizes[pageIndex]++;
            _currentPageSize = _pageSizes[pageIndex];
        }
        _totalTileCount++;

        try {
            // update our tracking first, we do not want to loose tiles because we stored them, but could then not update the tracking
            // Save metadata and the updated page list first.
            saveCurrentPage();
            Storage.setValue(metaKey(tileKeyStr), metaData);
            Storage.setValue("totalTileCount", _totalTileCount);
        } catch (e) {
            if (e instanceof Lang.StorageFullException) {
                // we expect storage to get full at some point, but there seems to be no way to get the size of the storage,
                // or how much is remaining programmatically
                // we could allow the user to specify 'maxTileCache storage' but we will just fill it up until there is no more space
                // note: This means routes need to be loaded first, or there will be no space left for new routes

                logE("tile storage full: " + e.getErrorMessage());
                // this page might have been too big, or we might just be full, so evict 2 tiles to  be safe
                evictOldestTileFromPage();
                evictLeastRecentlyUsedTile();
                return false;
            }

            logE("failed tile storage add: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        }

        // Check if this page is getting too large, and evict its oldest tile.
        if (_currentPageSize >= _maxPageSize) {
            evictOldestTileFromPage();
        }

        if (_totalTileCount > _settings.storageTileCacheSize) {
            // Does this ever need to do more than one pass? Saw it in the sim early on where it was higher than storage cache size, but never again.
            // do not want to do a while loop, since it could go for a long time and trigger watchdog
            evictLeastRecentlyUsedTile();
        }

        return true;
    }

    private function safeAdd(key as String, data as PropertyValueType) as Void {
        try {
            Storage.setValue(key, data);
        } catch (e) {
            if (e instanceof Lang.StorageFullException) {
                // we expect storage to get full at some point, but there seems to be no way to get the size of the storage,
                // or how much is remaining programmatically
                // we could allow the user to specify 'maxTileCache storage' but we will just fill it up until there is no more space
                // note: This means routes need to be loaded first, or there will be no space left for new routes

                logE("tile storage full: " + e.getErrorMessage());
                evictLeastRecentlyUsedTile();
                return;
            }

            logE("failed tile storage add: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        }
    }

    private function evictOldestTileFromPage() as Void {
        if (_currentPageIndex < 0 || _currentPageIndex >= _pageSizes.size()) {
            logE("evicting from page thats not loaded");
            return;
        }

        var oldestTime = null;
        var oldestKey = null;
        var epoch = Time.now().value();

        // Find the oldest tile ON THE CURRENT PAGE.
        for (var i = 0; i < _currentPageKeys.size(); i++) {
            var key = _currentPageKeys[i];
            var tileMetaData = Storage.getValue(metaKey(key));

            if (tileMetaData instanceof Array && tileMetaData.size() >= 3) {
                var expiresAt = tileMetaData[2] as Number;
                if (expired(expiresAt, epoch)) {
                    oldestKey = key; // Found an expired tile, evict immediately.
                    break;
                }

                var lastUsed = tileMetaData[0] as Number;
                if (oldestTime == null || oldestTime > lastUsed) {
                    oldestTime = lastUsed;
                    oldestKey = key;
                }
            } else {
                // Corrupted/dangling entry, evict immediately.
                oldestKey = key;
                break;
            }
        }

        if (oldestKey != null) {
            deleteByMetaData(oldestKey);
            _currentPageKeys.remove(oldestKey);
            _pageSizes[_currentPageIndex]--;
            _totalTileCount--;

            // keep our tracking up to date
            saveCurrentPage();
            safeSetStorage("totalTileCount", _totalTileCount);

            logT("Evicted tile " + oldestKey + " from page " + _currentPageIndex);
        }
    }

    private function evictLeastRecentlyUsedTile() as Void {
        // so that we do not read every page and every tile we just evict from the next page in the list
        // this may not actually remove a tile if the page is empty
        // the tiles are meant to be spread out evenly across pages though, if they are not, none of the assumptions in the class help
        _lastEvictedPageIndex = (_lastEvictedPageIndex + 1) % _pageCount;
        loadPage(_lastEvictedPageIndex);

        // single shot try to get a non-empty page (incredibly rare case)
        if (_currentPageKeys.size() == 0) {
            _lastEvictedPageIndex = (_lastEvictedPageIndex + 1) % _pageCount;
            loadPage(_lastEvictedPageIndex);
        }

        evictOldestTileFromPage();
    }

    private function deleteByMetaData(key as String) as Void {
        // all tile types are just stored as a single key and metadata now
        // so just delete both, even if they are not there (some meta data stores 'errored tiles', and they do not have a tile, but its faster to assume it does rather than read then delete)
        Storage.deleteValue(metaKey(key));
        Storage.deleteValue(tileKey(key));
    }

    // if this setting is changed whist the app is not running it will leave tile dangling in storage, and we have no way to know they are there, so guess thats up to the user to clear the storage
    // or we could try every page on startup?
    function setNewPageCount(newPageCount as Number) as Void {
        if (newPageCount == _pageCount) {
            return;
        }

        // we need to purge everything, otherwise we will look in the wrong page for a tile
        clearValues();

        // set ourselves up for the enw partition strategy
        _pageCount = newPageCount;
        pageCountUpdated();
    }

    function reset() as Void {
        // called when storage is purged underneath us, we just need to reset our state rather than do the for loop
        clearValues(); // should be fairly fast unless we happen to be on page 0 - in which case it will try and delete by meta data, which will not be queryable, but it handles that, so a single for loop worst case.
    }

    function clearValues() as Void {
        for (var i = 0; i < _pageCount; i++) {
            loadPage(i);
            var keys = _currentPageKeys;
            var keysSize = keys.size();
            for (var j = 0; j < keysSize; j++) {
                deleteByMetaData(keys[j]);
            }
            Storage.deleteValue(pageStorageKey(i));
        }
        _currentPageKeys = [];
        _currentPageIndex = -1;
        _totalTileCount = 0;
        Storage.deleteValue("totalTileCount");
        for (var i = 0; i < _pageSizes.size(); i++) {
            _pageSizes[i] = 0;
        }
    }
}

class TileCache {
    var _internalCache as Dictionary<String, Tile>;
    var _webRequestHandler as WebRequestHandler;
    var _paletteId as Number?;
    var _palette as Array<Number>?;
    var _settings as Settings;
    var _cachedValues as CachedValues;
    var _hits as Number = 0;
    var _misses as Number = 0;
    // Ignore any tile adds that do not have this version (allows outstanding web requests to be ignored once they are handled)
    var _tileCacheVersion as Number = 0;
    var _storageTileCache as StorageTileCache;
    var _errorBitmaps as Dictionary<String, WeakReference<Graphics.BufferedBitmap> > =
        ({}) as Dictionary<String, WeakReference<Graphics.BufferedBitmap> >;

    function initialize(
        webRequestHandler as WebRequestHandler,
        settings as Settings,
        cachedValues as CachedValues
    ) {
        _settings = settings;
        _cachedValues = cachedValues;
        _webRequestHandler = webRequestHandler;
        _internalCache = ({}) as Dictionary<String, Tile>;
        _storageTileCache = new StorageTileCache(_settings, _cachedValues);
    }

    function updatePalette(id as Number?, data as Array?) as Void {
        // do we maybe want to store multiple palettes and just load the correct one form storage by id?
        // then we never need to nuke the palettes unless they change, and storage tiles could use whatever they wanted
        loadPalette(id, data);
        safeSetStorage("paletteId", id as Application.PropertyValueType); // can store null, this is fine (clear out any old palette)
        safeSetStorage("palette", _palette as Application.PropertyValueType); // can store null, this is fine (clear out any old palette)
    }

    function loadPalette(id as Number?, data as Array?) as Void {
        if (!(data instanceof Array)) {
            logE("colour palette wrong type: " + data);
            return;
        }

        var dataArr = data as Array;
        if (dataArr.size() != 64) {
            logE("colour palette has only: " + dataArr.size() + "elements");
            return;
        }

        for (var i = 0; i < dataArr.size(); ++i) {
            if (!(dataArr[i] instanceof Number)) {
                logE("colour palette dataArr wrong type");
                return;
            }
        }

        if (!(id instanceof Number)) {
            logE("colour palette id wrong type: " + id);
            return;
        }

        logT("new colour palette loaded: " + id);
        _paletteId = id as Number;
        _palette = data as Array<Number>;
    }

    function setup() as Void {
        _storageTileCache.setup();
    }

    public function clearValues() as Void {
        clearValuesWithoutStorage();
        // whenever we purge the tile cache it is usually because the tile server properties have changed, safest to nuke the storage cache too
        // though sme times its when the in memory tile cache size changes
        // users should not be modifying the tile settings in any way, otherwise the storage will also be out of date (eg. when tile size or tile url changes)
        _storageTileCache.clearValues();
    }

    public function clearValuesWithoutStorage() as Void {
        _internalCache = ({}) as Dictionary<String, Tile>;
        _errorBitmaps = ({}) as Dictionary<String, WeakReference<Graphics.BufferedBitmap> >;
        _tileCacheVersion++;

        // clear the pallet and it's storage, we need to load it again
        // this could be a problem if storage tiles are saying use a pallet that we do not have
        _paletteId = null;
        _palette = null;
        safeSetStorage("paletteId", null);
        safeSetStorage("palette", null);
    }

    // loads a tile into the cache
    // returns true if seed should stop and wait for next calculate (to prevent watchdog errors)
    function seedTile(x as Number, y as Number, z as Number) as Boolean {
        var tileKeyStr = tileKeyHash(x, y, z);
        var tile = _internalCache[tileKeyStr] as Tile?;
        if (tile != null) {
            var epoch = Time.now().value();
            if (!tile.expiredAlready(epoch)) {
                return false;
            }
        }
        return startSeedTile(tileKeyStr, x, y, z, false);
    }

    // seedTile puts the tile into memory, either by pulling from storage, or by running a web request
    // seedTileToStorage only puts the tile into storage
    // returns true if a tile seed was started, false if we already have the tile
    function seedTileToStorage(
        tileKeyStr as String,
        x as Number,
        y as Number,
        z as Number
    ) as Boolean {
        if (_storageTileCache.haveTile(tileKeyStr)) {
            // we already have the tile (and it is not expired)
            return false;
        }

        startSeedTile(tileKeyStr, x, y, z, true);
        return true;
    }

    // returns true if seed should stop and wait for next calculate (to prevent watchdog errors)
    private function startSeedTile(
        tileKeyStr as String,
        x as Number,
        y as Number,
        z as Number,
        onlySeedStorage as Boolean
    ) as Boolean {
        // logT("starting load tile: " + x + " " + y + " " + z);

        if (_settings.tileUrl.find(COMPANION_APP_TILE_URL_MATCH) == null) {
            return seedImageTile(tileKeyStr, x, y, z, onlySeedStorage);
        }

        return seedCompanionAppTile(tileKeyStr, x, y, z, onlySeedStorage);
    }

    (:noImageTiles)
    function seedImageTile(
        tileKeyStr as String,
        x as Number,
        y as Number,
        z as Number,
        onlySeedStorage as Boolean
    ) as Boolean {
        return false;
    }
    (:imageTiles)
    function seedImageTile(
        tileKeyStr as String,
        _x as Number,
        _y as Number,
        _z as Number,
        onlySeedStorage as Boolean
    ) as Boolean {
        // logD("small tile: " + tileKey + " scaledTileSize: " + _settings.scaledTileSize + " tileSize: " + _settings.tileSize);
        var x = _x / _cachedValues.smallTilesPerScaledTile;
        var y = _y / _cachedValues.smallTilesPerScaledTile;
        var fullSizeTileStr = tileKeyHash(x, y, _z);
        // logD("fullSizeTile tile: " + fullSizeTile);
        var imageReqHandler = new ImageWebTileRequestHandler(
            me,
            x,
            y,
            _z,
            tileKeyStr,
            fullSizeTileStr,
            _tileCacheVersion,
            onlySeedStorage
        );
        if (_settings.storageMapTilesOnly || _settings.cacheTilesInStorage) {
            var tileFromStorage = _storageTileCache.get(fullSizeTileStr);
            if (tileFromStorage != null) {
                var responseCode = tileFromStorage[0];
                // logD("image tile loaded from storage: " + tileKey + " with result: " + responseCode);
                if (responseCode != 200) {
                    imageReqHandler.handleErroredTile(responseCode);
                    return true;
                }
                // only handle successful tiles for now, maybe we should handle some other errors (404, 403 etc)
                imageReqHandler.handleSuccessfulTile(tileFromStorage[1] as BitmapResource?, false);
                return true;
            }
        }
        if (_settings.storageMapTilesOnly && !_cachedValues.seeding()) {
            // we are running in storage only mode, but the tile is not in the cache
            addErroredTile(tileKeyStr, _tileCacheVersion, "S404", true);
            return true; // this could be a complicated op if we are getting all these tiles from storage
        }
        _webRequestHandler.add(
            new ImageRequest(
                "im" + tileKeyStr + "-" + _tileCacheVersion, // the hash is for the small tile request, not the big one (they will send the same physical request out, but again use 256 tilSize if your using external sources)
                stringReplaceFirst(
                    stringReplaceFirst(
                        stringReplaceFirst(
                            stringReplaceFirst(_settings.tileUrl, "{x}", x.toString()),
                            "{y}",
                            y.toString()
                        ),
                        "{z}",
                        _z.toString()
                    ),
                    "{authToken}",
                    _settings.authToken
                ),
                {},
                imageReqHandler
            )
        );
        return false;
    }

    (:noCompanionTiles)
    function seedCompanionAppTile(
        tileKeyStr as String,
        _x as Number,
        _y as Number,
        _z as Number,
        onlySeedStorage as Boolean
    ) as Boolean {
        return false;
    }

    (:companionTiles)
    function seedCompanionAppTile(
        tileKeyStr as String,
        _x as Number,
        _y as Number,
        _z as Number,
        onlySeedStorage as Boolean
    ) as Boolean {
        // logD("small tile (companion): " + tileKey + " scaledTileSize: " + _settings.scaledTileSize + " tileSize: " + _settings.tileSize);
        var jsonWebHandler = new JsonWebTileRequestHandler(
            me,
            _x,
            _y,
            _z,
            tileKeyStr,
            _tileCacheVersion,
            onlySeedStorage
        );
        if (_settings.storageMapTilesOnly || _settings.cacheTilesInStorage) {
            var tileFromStorage = _storageTileCache.get(tileKeyStr);
            if (tileFromStorage != null) {
                var responseCode = tileFromStorage[0];
                // logD("image tile loaded from storage: " + tileKey + " with result: " + responseCode);
                if (responseCode != 200) {
                    jsonWebHandler.handleErroredTile(responseCode);
                    return true;
                }
                // only handle successful tiles for now, maybe we should handle some other errors (404, 403 etc)
                jsonWebHandler.handleSuccessfulTile(tileFromStorage[1] as Dictionary?, false);
                return true;
            }
        }
        if (_settings.storageMapTilesOnly && !_cachedValues.seeding()) {
            // we are running in storage only mode, but the tile is not in the cache
            addErroredTile(tileKeyStr, _tileCacheVersion, "S404", true);
            return true; // this could be a complicated op if we are getting all these tiles from storage
        }
        _webRequestHandler.add(
            new JsonRequest(
                "json" + tileKeyStr + "-" + _tileCacheVersion,
                _settings.tileUrl + "/loadtile",
                {
                    "x" => _x,
                    "y" => _y,
                    "z" => _z,
                    "scaledTileSize" => _settings.scaledTileSize,
                    "tileSize" => _settings.tileSize,
                },
                jsonWebHandler
            )
        );
        return false;
    }

    // puts a tile into the cache
    function addTile(tileKeyStr as String, tileCacheVersion as Number, tile as Tile) as Void {
        if (tileCacheVersion != _tileCacheVersion) {
            return;
        }

        tile.setExpiresAt(NO_EXPIRY); // be explicit that there is no expiry

        if (_internalCache.size() == _settings.tileCacheSize) {
            evictLeastRecentlyUsedTile();
        }

        _internalCache[tileKeyStr] = tile;
    }

    function addErroredTile(
        tileKeyStr as String,
        tileCacheVersion as Number,
        msg as String,
        isHttpResponseCode as Boolean
    ) as Void {
        if (tileCacheVersion != _tileCacheVersion) {
            return;
        }

        if (_internalCache.size() == _settings.tileCacheSize) {
            evictLeastRecentlyUsedTile();
        }

        var epoch = Time.now().value();
        var expiresAt =
            epoch + (isHttpResponseCode ? _settings.httpErrorTileTTLS : _settings.errorTileTTLS);

        var weakRefToErrorBitmap = _errorBitmaps[msg];
        if (weakRefToErrorBitmap != null) {
            var errorBitmap = weakRefToErrorBitmap.get() as Graphics.BufferedBitmap?;
            if (errorBitmap != null) {
                var tile = new Tile(errorBitmap);
                tile.setExpiresAt(expiresAt);
                _internalCache[tileKeyStr] = tile;
                return;
            }
        }

        var tileSize = _settings.tileSize;
        // todo perf: only draw each message once, and cache the result (since they are generally 404,403 etc.), still need the tile object though to track last used
        // this is especially important for larger tiles (image tiles are usually compressed and do not take up the full tile size in pixels)
        var bitmap = newBitmap(tileSize, tileSize);
        var dc = bitmap.getDc();
        var halfHeight = tileSize / 2;
        dc.setColor(Graphics.COLOR_RED, _settings.tileErrorColour);
        dc.clear();
        // cache the tile as errored, but do not show the error message
        if (_settings.showErrorTileMessages) {
            // could get text width and see which one covers more of the tile
            if (tileSize < 100) {
                dc.drawText(
                    halfHeight,
                    halfHeight,
                    Graphics.FONT_XTINY,
                    msg,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
            } else {
                var textHight = dc.getFontHeight(Graphics.FONT_LARGE);
                dc.drawText(0, 0, Graphics.FONT_LARGE, msg, Graphics.TEXT_JUSTIFY_LEFT);
                dc.drawText(tileSize, 0, Graphics.FONT_LARGE, msg, Graphics.TEXT_JUSTIFY_RIGHT);
                dc.drawText(
                    halfHeight,
                    halfHeight,
                    Graphics.FONT_LARGE,
                    msg,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
                );
                dc.drawText(
                    0,
                    tileSize - textHight,
                    Graphics.FONT_LARGE,
                    msg,
                    Graphics.TEXT_JUSTIFY_LEFT
                );
                dc.drawText(
                    tileSize,
                    tileSize - textHight,
                    Graphics.FONT_LARGE,
                    msg,
                    Graphics.TEXT_JUSTIFY_RIGHT
                );
            }
        }

        _errorBitmaps[msg] = bitmap.weak(); // store in our cache for later use
        var tile = new Tile(bitmap);
        tile.setExpiresAt(expiresAt);
        _internalCache[tileKeyStr] = tile;
    }

    // gets a tile that was stored by seedTile
    function getTile(x as Number, y as Number, z as Number) as Tile? {
        var tileKeyStr = tileKeyHash(x, y, z);
        var tile = _internalCache[tileKeyStr] as Tile?;
        if (tile != null) {
            // logT("cache hit: " + x  + " " + y + " " + z);
            _hits++;
            tile.markUsed();
            return tile;
        }

        // logT("cache miss: " + x  + " " + y + " " + z);
        // logT("have tiles: " + _internalCache.keys());
        _misses++;
        return null;
    }

    function haveTile(tileKeyStr as String) as Boolean {
        return _internalCache.hasKey(tileKeyStr);
    }

    function evictLeastRecentlyUsedTile() as Void {
        // todo put older tiles into disk, and store what tiles are on disk (storage class)
        // it will be faster to load them from there than bluetooth
        var oldestTime = null;
        var oldestKey = null;

        var epoch = Time.now().value();

        var keys = _internalCache.keys();
        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i];
            var tile = self._internalCache[key] as Tile;
            if (tile.expiredAlready(epoch)) {
                oldestKey = key;
                break;
            }

            if (oldestTime == null || oldestTime > tile.lastUsed) {
                oldestTime = tile.lastUsed;
                oldestKey = key;
            }
        }

        if (oldestKey != null) {
            _internalCache.remove(oldestKey);
            // logT("Evicted tile " + oldestKey + " from internal cache");
        }
    }

    (:companionTiles)
    function loadPalletFromWeb() as Void {
        // if we are still null after a load, we need to lad the palette from the tile server on the phone
        logD("loading TilePalette from web");
        var jsonTileHandler = new JsonPelletLoadHandler(me);
        _webRequestHandler.addHighPriority(
            new JsonRequest(
                "getTilePalette",
                _settings.tileUrl + "/getTilePalette",
                {},
                jsonTileHandler
            )
        );
    }

    (:noCompanionTiles)
    function tileDataToBitmap64ColourString(
        paletteId as Number,
        charArr as Array<Char>?
    ) as Graphics.BufferedBitmap? {
        return null;
    }
    (:companionTiles)
    function tileDataToBitmap64ColourString(
        paletteId as Number,
        charArr as Array<Char>?
    ) as Graphics.BufferedBitmap? {
        if (_paletteId == null || _palette == null) {
            loadPalette(
                Storage.getValue("paletteId") as Number?,
                Storage.getValue("palette") as Array?
            );
            if (_paletteId == null || _palette == null) {
                loadPalletFromWeb();
                return null;
            }
        }

        // this is safe, the above code sets it if its null
        var paletteArr = _palette as Array<Number>;

        if (paletteId != _paletteId) {
            logE("wrong pallet loaded, current: " + _paletteId + " target: " + paletteId);
            _paletteId = null;
            _palette = null;
            // clear the storage
            safeSetStorage("paletteId", null);
            safeSetStorage("palette", null);
            loadPalletFromWeb();
            return null;
        }
        // logT("tile data " + arr);
        var tileSize = _settings.tileSize;
        var requiredSize = tileSize * tileSize;
        // got a heap of
        // Error: Unexpected Type Error
        // Details: 'Failed invoking <symbol>'
        // even though the only calling coe checks it's a string, then calls .toUtf8Array()
        // Stack:
        // - pc: 0x1000867c
        //     File: 'BreadcrumbDataField\source\TileCache.mc'
        //     Line: 479
        //     Function: tileDataToBitmap64ColourString
        // - pc: 0x1000158c
        //     File: 'BreadcrumbDataField\source\TileCache.mc'
        //     Line: 121
        //     Function: handle
        // - pc: 0x10004e8d
        //     File: 'BreadcrumbDataField\source\WebRequest.mc'
        //     Line: 86
        //     Function: handle
        if (!(charArr instanceof Array)) {
            // managed to get this in the sim, it was a null (when using .toUtf8Array())
            // docs do not say that it can ever be null though
            // perhaps the colour string im sending is no good?
            // seems to be random though. And it seems to get through on the next pass, might be memory related?
            // it even occurs on a simple string (no special characters)
            // resorting to using the string directly
            // the toCharArray method im using now seems to throw OOM errors instead of returning null
            // not sure which is better, we are at our memory limits regardless, so
            // optimisation level seems to effect it (think it must garbage collect faster or inline things where it can)
            // slow optimisations are always good for relase, but make debugging harder when variables are optimised away (which is why i was running no optimisations).
            logE("got a bad type somehow? 64colour: " + charArr);
            return null;
        }

        if (charArr.size() < requiredSize) {
            logE("tile length too short 64colour: " + charArr.size());
            return null;
        }

        if (charArr.size() != requiredSize) {
            // we could load tile partially, but that would require checking each iteration of the for loop,
            // want to avoid any extra work for perf
            logE("bad tile length 64colour: " + charArr.size() + " best effort load");
        }

        // logT("processing tile data, first colour is: " + arr[0]);

        // todo check if setting the pallet actually reduces memory
        var localBitmap = newBitmap(tileSize, tileSize);
        var localDc = localBitmap.getDc();
        var it = 0;
        for (var i = 0; i < tileSize; ++i) {
            for (var j = 0; j < tileSize; ++j) {
                // _palette should have all values that are possible, not checking size for perf reasons
                var colour = paletteArr[charArr[it].toNumber() & 0x3f]; // charArr[it] as Char the toNumber is The UTF-32 representation of the Char interpreted as a Number
                it++;
                localDc.setColor(colour, colour);
                localDc.drawPoint(i, j);
            }
        }

        return localBitmap;
    }

    (:noCompanionTiles)
    function tileDataToBitmapBlackAndWhite(charArr as Array<Char>?) as Graphics.BufferedBitmap? {
        return null;
    }
    (:companionTiles)
    function tileDataToBitmapBlackAndWhite(charArr as Array<Char>?) as Graphics.BufferedBitmap? {
        // logT("tile data " + arr);
        var tileSize = _settings.tileSize;
        var requiredSize = Math.ceil((tileSize * tileSize) / 6f).toNumber(); // 6 bits of colour per byte
        if (!(charArr instanceof Array)) {
            // managed to get this in the sim, it was a null (when using .toUtf8Array())
            // docs do not say that it can ever be null though
            // perhaps the colour string im sending is no good?
            // seems to be random though. And it seems to get through on the next pass, might be memory related?
            // it even occurs on a simple string (no special characters)
            // resorting to using the string directly
            // the toCharArray method im using now seems to throw OOM errors instead of returning null
            // not sure which is better, we are at our memory limits regardless, so
            // optimisation level seems to effect it (think it must garbage collect faster or inline things where it can)
            // slow optimisations are always good for relase, but make debugging harder when variables are optimised away (which is why i was running no optimisations).
            logE("got a bad type somehow? b&w: " + charArr);
            return null;
        }

        if (charArr.size() < requiredSize) {
            logT("tile length too short b&w: " + charArr.size());
            return null;
        }

        if (charArr.size() != requiredSize) {
            // we could load tile partially, but that would require checking each itteration of the for loop,
            // want to avoid any extra work for perf
            logE("bad tile length b&w: " + charArr.size() + " best effort load");
        }

        // logT("processing tile data, first colour is: " + arr[0]);

        // todo check if setting the pallet actually reduces memory
        var localBitmap = newBitmap(tileSize, tileSize);
        var localDc = localBitmap.getDc();
        var bit = 0;
        var byte = 0;
        for (var i = 0; i < tileSize; ++i) {
            for (var j = 0; j < tileSize; ++j) {
                var colour = (charArr[byte].toNumber() >> bit) & 0x01;
                bit++;
                if (bit >= 6) {
                    bit = 0;
                    byte++;
                }

                if (colour == 1) {
                    localDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                } else {
                    localDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                }

                localDc.drawPoint(i, j);
            }
        }

        return localBitmap;
    }

    (:noCompanionTiles)
    function tileDataToBitmapFullColour(mapTileBytes as ByteArray?) as Graphics.BufferedBitmap? {
        return null;
    }
    (:companionTiles)
    function tileDataToBitmapFullColour(mapTileBytes as ByteArray?) as Graphics.BufferedBitmap? {
        // logT("tile data " + arr);
        var tileSize = _settings.tileSize;
        var requiredSize = tileSize * tileSize * 3;

        if (!(mapTileBytes instanceof ByteArray)) {
            // managed to get this in the sim, it was a null (when using .toUtf8Array())
            // docs do not say that it can ever be null though
            // perhaps the colour string im sending is no good?
            // seems to be random though. And it seems to get through on the next pass, might be memory related?
            // it even occurs on a simple string (no special characters)
            // resorting to using the string directly
            // the toCharArray method im using now seems to throw OOM errors instead of returning null
            // not sure which is better, we are at our memory limits regardless, so
            // optimisation level seems to effect it (think it must garbage collect faster or inline things where it can)
            // slow optimisations are always good for relase, but make debugging harder when variables are optimised away (which is why i was running no optimisations).
            logE("got a bad full colour type somehow?: " + mapTileBytes);
            return null;
        }

        if (mapTileBytes.size() < requiredSize) {
            logE("tile length too short full colour: " + mapTileBytes.size());
            return null;
        }

        if (mapTileBytes.size() != requiredSize) {
            // we could load tile partially, but that would require checking each itteration of the for loop,
            // want to avoid any extra work for perf
            logE("bad tile length full colour: " + mapTileBytes.size() + " best effort load");
        }

        mapTileBytes.add(0x00); // add a byte to the end so the last 24bit colour we parse still has 32 bits of data

        // logT("processing tile data, first colour is: " + arr[0]);

        // todo check if setting the pallet actually reduces memory
        var localBitmap = newBitmap(tileSize, tileSize);
        var localDc = localBitmap.getDc();
        var offset = 0;
        for (var i = 0; i < tileSize; ++i) {
            for (var j = 0; j < tileSize; ++j) {
                // probably a faster way to do this
                var colour =
                    mapTileBytes.decodeNumber(Lang.NUMBER_FORMAT_UINT32, {
                        :offset => offset,
                        :endianness => Lang.ENDIAN_BIG,
                    }) as Number;
                colour = (colour >> 8) & 0x00ffffff; // 24 bit colour only
                offset += 3;
                // tried setFill and setStroke, neither seemed to work, so we can only support 24bit colour
                localDc.setColor(colour, colour);
                localDc.drawPoint(i, j);
            }
        }

        return localBitmap;
    }

    function clearStats() as Void {
        _hits = 0;
        _misses = 0;
    }
}
