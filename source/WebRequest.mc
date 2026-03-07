import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Communications;
import Toybox.Application;

typedef WebHandler as interface {
    // see error codes such as Communications.NETWORK_REQUEST_TIMED_OUT
    function handle(
        responseCode as Number,
        data as
            Dictionary or
                String or
                Iterator or
                WatchUi.BitmapResource or
                Graphics.BitmapReference or
                Null
    ) as Void;
};
typedef WebRequest as interface {
    var url as String;
    var params as Dictionary;
    var hash as String;

    function start(webRequestHandler as WebRequestHandler, settings as Settings) as Void;
};

(:companionTiles)
class JsonRequest {
    var url as String;
    var params as Dictionary;
    // unique id for this request, if two requests have the same hash the second one will be dropped if the first is pending
    var hash as String;
    var handler as WebHandler;

    function initialize(
        _hash as String,
        _url as String,
        _params as Dictionary,
        _handler as WebHandler
    ) {
        hash = _hash;
        url = _url;
        params = _params;
        handler = _handler;
    }

    function start(webRequestHandler as WebRequestHandler, settings as Settings) as Void {
        // logT("sending json request");
        var callback =
            (new WebRequestHandleWrapper(webRequestHandler, handler, hash)).method(:handle) as
            (Method
                (
                    responseCode as Lang.Number,
                    data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null
                ) as Void
            ) or
                (Method
                (
                    responseCode as Lang.Number,
                    data as Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null,
                    context as Lang.Object
                ) as Void
            );
        // note: even though docs say that this could be sent over wifi it seems it never is, and requires the bluetooth connection
        // also i tried several ways to force wifi, including calls to checkWifiConnection - which does connect wifi but the request still seems
        // to go through the bluetooth bridge
        // https://forums.garmin.com/developer/connect-iq/f/discussion/5230/web-requests-without-mobile-connect
        // it seems like edge devices in the simulator do not support this, the callback is just never called (could be a simulator bug)
        // routes still work though, so allowing them to still be used
        Communications.makeWebRequest(
            url,
            params as Dictionary<Lang.Object, Lang.Object>,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    // docs say you can do this (or omit it), but i found its not sent, or is sent as application/x-www-form-urlencoded when using HTTP_RESPONSE_CONTENT_TYPE_JSON
                    // "Content-Type" => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                    // my local server does not like content type being supplied when its a get or post
                    // the android server does not seem to get
                    // "Content-Type" => "application/json",
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            }, // options
            // see https://forums.garmin.com/developer/connect-iq/f/discussion/2289/documentation-clarification-object-method-and-lang-method
            callback
        );
    }
}

class ImageRequest {
    var url as String;
    var params as Dictionary;
    // unique id for this request, if two requests have the same hash the second one will be dropped if the first is pending
    var hash as String;
    var handler as WebHandler;

    function initialize(
        _hash as String,
        _url as String,
        _params as Dictionary,
        _handler as WebHandler
    ) {
        hash = _hash;
        url = _url;
        params = _params;
        handler = _handler;
    }

    function start(webRequestHandler as WebRequestHandler, settings as Settings) as Void {
        // logT("sending image request");
        var callback =
            (new WebRequestHandleWrapper(webRequestHandler, handler, hash)).method(:handle) as
            (Method
                (
                    responseCode as Lang.Number,
                    data as WatchUi.BitmapResource or Graphics.BitmapReference or Null
                ) as Void
            );
        // we only use image requests for external servers
        Communications.makeImageRequest(
            url,
            params,
            {
                :maxWidth => settings.scaledTileSize,
                :maxHeight => settings.scaledTileSize,

                // needs to be png or we will get
                // Error: Unhandled Exception
                // Exception: Source must not use a color palette if we try and draw it to another bufferedBitmap
                // it appears PACKING_FORMAT_DEFAULT is the culprit
                // PACKING_FORMAT_YUV, PACKING_FORMAT_PNG, PACKING_FORMAT_JPG are also fine
                // docs say png is slow to load, yuv is fast and jpg is reasonably fast
                // PACKING_FORMAT_YUV has weird issues in the physical device (its just tinting the image, not preserving pixel data)
                // looks like PACKING_FORMAT_PNG does work, but its really slow -> we should only fallback to this if we really need it
                // PACKING_FORMAT_JPG does weird things
                // (we have to scale the image - at this point im thinking i should just override the users setting to 256 if the tile server is not the companion app)
                // so we must use PACKING_FORMAT_PNG if they really want a slow response and smaller tiles cache
                // so tried it again, ang PNG did the same colour issue as JPG/YUV :( AHHHHHHHHHHHH
                // Communications.PACKING_FORMAT_DEFAULT - Image data is encoded in the device native format, a lossless encoding that available on all devices. It is very efficient to decode, but often results in large transfer sizes so is slow to download.
                // The default is slow to download? wtf? guess it is efficient to decode though. But it also has a pallet on some devices, so cannot be rendered in unbuffered rotations mode
                // PACKING_FORMAT_YUV - Image data is encoded in YUV format. This is a lossy encoding that is compressed, and is fast to load. It is ideal for photographic imagery with transparency.
                // PACKING_FORMAT_PNG - Image data is encoded in PNG format. This is a lossless encoding that is compressed, but is relatively slow to load. It is ideal for non-photographic imagery.
                // PACKING_FORMAT_JPG - Image data is encoded in JPG format. This is a lossy encoding that is compressed, and is reasonably fast to load. It is ideal for photographic imagery.
                // PACKING_FORMAT_YUV seems the fastest, compressed and fast to load
                // should perf test the others on real device, eg. perhaps jpg is faster download but slightly slower draw
                // :packingFormat => Communications.PACKING_FORMAT_YUV, // do not specify a palette, as we cannot draw directly to dc on some devices
                :packingFormat => settings.packingFormat as Communications.PackingFormat,
                // from android code
                // val osName = "Garmin"
                // val osVersion = Build.VERSION.RELEASE ?: "Unknown"
                // val deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}"
                // required by openstreetmaps, not sure how to get this to work
                // https://operations.osmfoundation.org/policies/tiles/
                // https://help.openstreetmap.org/questions/29938/in-my-app-problem-downloading-maptile-000-http-response-http11-403-forbidden
                // header("User-Agent", "Breadcrumb/1.0 ($osName $osVersion $deviceModel)")
                // but unfortunatly the makeImageRequest does not support headers
                // https://forums.garmin.com/developer/connect-iq/f/discussion/303994/makeimagerequest-additional-headers-and-svgs
                // so no openstreet maps for us :(
            }, // options
            // see https://forums.garmin.com/developer/connect-iq/f/discussion/2289/documentation-clarification-object-method-and-lang-method
            callback
        );
    }
}

class WebRequestHandleWrapper {
    var webHandler as WebRequestHandler;
    var hash as String;
    var handler as WebHandler;
    var alreadyDecedWebHandler as Boolean = false;

    function initialize(_webHandler as WebRequestHandler, _handler as WebHandler, _hash as String) {
        webHandler = _webHandler;
        handler = _handler;
        hash = _hash;
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
        try {
            handler.handle(responseCode, data);

            if (
                responseCode != 200 &&
                webHandler._settings.tileUrl.find(COMPANION_APP_TILE_URL_MATCH) != null &&
                !getApp()._breadcrumbContext.settings.storageMapTilesOnly
            ) {
                // todo only send this on certain errors, and only probably only after some limit?
                // we could also send a toast, but the transmit allows us to open the app easier on the phone
                // even though the phone side is a bit of a hack (ConnectIQMessageReceiver cannot parse the data), it's still better than having to manualy open the app.
                webHandler.transmit([PROTOCOL_SEND_OPEN_APP], {}, getApp()._commStatus);
            }

            // data can be null even when we mae a json request and get 200 response
            if (responseCode == 200 && data != null) {
                webHandler._successCount++;
            } else {
                // logET("got web error: " + responseCode);
                webHandler._errorCount++;
            }
            webHandler._lastResult = responseCode == 200 && data == null ? null : responseCode;
        } catch (e) {
            logE("failed to handle web request: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        } finally {
            // got some stack overflows, as handle can be called inline if it knows it will fail (eg. BLE_CONNECTION_UNAVAILABLE)
            // also saw alot of NETWORK_REQUEST_TIMED_OUT in the logs, but think it was when the BLE_CONNECTION_UNAVAILABLE happened
            // as that was the last log, and it makes sense that it can short circuit
            // so launch the next task in a timer
            // var timer = new Timer.Timer();
            // timer.start(webHandler.method(:startNext), 1, false);
            // or at least I would do this if the timer task was available to datafields :(
            // so we might have to call 'startNext' every time the compute method runs :(
            // new Timer.Timer(); Error: Permission Required ; Details: Module 'Toybox.Timer' not available to 'Data Field'
            if (!alreadyDecedWebHandler) {
                // try and prevent double decrement (only noticed on sim which was probably in bad state)
                // it also only seemed to be when it errored with 404 - companion app server was not running
                // perhaps it was from the webHandler.transmit, which is meant to prevent the `Communications transmit queue full` error
                // maybe all web requests need to finish before we can transmit? Or perhaps the web handler is still active when we are in this function?
                webHandler.decrementOutstanding(hash);
            }
            alreadyDecedWebHandler = true;
        }
    }
}

class ConnectionListenerWrapper extends Communications.ConnectionListener {
    var webHandler as WebRequestHandler;
    var handler as Communications.ConnectionListener;
    var alreadyDecedWebHandler as Boolean = false;

    function initialize(
        _webHandler as WebRequestHandler,
        _handler as Communications.ConnectionListener
    ) {
        Communications.ConnectionListener.initialize();
        webHandler = _webHandler;
        handler = _handler;
    }

    function onComplete() {
        try {
            handler.onComplete();
        } catch (e) {
            logE("failed onComplete: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        } finally {
            decOutstanding();
        }
    }

    function onError() {
        try {
            handler.onError();
        } catch (e) {
            logE("failed onError: " + e.getErrorMessage());
            ++$.globalExceptionCounter;
        } finally {
            decOutstanding();
        }
    }

    function decOutstanding() as Void {
        if (alreadyDecedWebHandler) {
            return;
        }

        alreadyDecedWebHandler = true;
        webHandler._outstandingCount--;
    }
}

class WebRequestHandler {
    // see https://forums.garmin.com/developer/connect-iq/f/discussion/209443/watchface-working-in-simulator-failing-webrequest-on-device-with-http-response--101
    // only 3 web requests are allowed in parallel, so we need to buffer them up and make new requests when we get responses
    // using 2 arrays so we get FIFO
    // also dictionary seemed to make the code 2X slower, think because we had to serch all the keys for a string several times
    var pendingTransmit as
    Array<[Application.PersistableType, Dictionary?, Communications.ConnectionListener]> = [];
    var pending as Array<WebRequest> = [];
    var pendingHashes as Array<String> = [];
    var outstandingHashes as Array<String> = [];
    var _outstandingCount as Number = 0;
    var _settings as Settings;
    var _errorCount as Number = 0;
    var _successCount as Number = 0;
    var _lastResult as Number? = null;

    function initialize(settings as Settings) {
        _settings = settings;
    }

    function clearValues() as Void {
        pending = [];
        pendingHashes = [];
    }

    // Communications.transmit can fail if web requests are pending, 'Communications transmit queue full'
    // so we will have to queue it up to the web server as 'high priority', or just have a transmit queue that is always high priority
    function transmit(
        content as Application.PersistableType,
        options as Dictionary?,
        listener as Communications.ConnectionListener
    ) as Void {
        pendingTransmit.add([content, options, listener]);
    }

    // highPriority queries must be sent, and they must be sent first
    // always adds (if not already present)
    // it's currently still queued up in the order it sent to make adding simpler and consistent, monkeyc also has no insertAtFont() type method
    // so we would have to build a new array (and then copy all elements) and we have to do this twice, for pending and pendingHashes
    // not worth it since its only when a tile server setting changes, and maxPendingWebRequests should be low enough that we eventually get to the task
    // this method just guarantees it is sent, and not dropped based on maxPendingWebRequests logic (because we could starve ourselves out, and never send things that must be sent)
    function addHighPriority(webReq as WebRequest) as Void {
        var hash = webReq.hash;
        if (pendingHashes.indexOf(hash) > -1) {
            // logD("Dropping req for: " + hash);
            // note: we cannot attempt to run the request, as i've gotten stack over flows on real devices
            // all web requests will be started from the top level compute loop
            // stack overflow comes when it completes immediately, and calls into handle
            // see report at end of TileCache.mc
            // startNextIfWeCan(); // start any other ones whilst we are in a different function
            return;
        }

        if (outstandingHashes.indexOf(hash) > -1) {
            // we already have an outstanding request, do not queue up another to run as soon as the outstanding one completes
            return;
        }

        pending.add(webReq);
        pendingHashes.add(hash);
        // for now just start one at a time, simpler to track
        // At most 3 outstanding can occur, todo query this limit
        // https://forums.garmin.com/developer/connect-iq/f/discussion/204298/ble-queue-full
        // otherwise you will get BLE_QUEUE_FULL (-101)
        // note: we cannot attempt to run the request, as i've gotten stack over flows on real devices
        // all web requests will be started from the top level compute loop
        // stack overflow comes when it completes immediately, and calls into handle
        // see report at end of TileCache.mc
        // startNextIfWeCan();
    }

    function add(webReq as WebRequest) as Void {
        // todo remove old requests if we get too many (slow network and requests too often mean the internal array grows and we OOM)
        // hard to know if there is one outstanding though, also need to startNext() on a timer if we have not seen any requests in a while
        if (pending.size() > _settings.maxPendingWebRequests) {
            // we have too many, don't try and get the tile
            // we should try and dedupe - as its making a request for the same tile twice (2 renders cause 2 requests)
            // logE("Too many pending requests dropping: " + jsonReq.hash);
            return;
        }

        addHighPriority(webReq);
    }

    function startNextIfWeCan() as Boolean {
        if (pending.size() == 0 && pendingTransmit.size() == 0) {
            return false;
        }

        // kept getting errors with
        // Error: System Error
        // Details: failed inside handle_image_callback
        // only happened on real device when using makeImageRequest, and having tiles put into storage.
        // Not sure if its an issue with storage thats propagating to the image handler
        // (eg. maybe its larger than 32Kb and that makes a system error rather than a storage exception)
        // trying to reduce parallel requests to 1 at a time to see if that helps
        if (_outstandingCount < 3) {
            // we could get real crazy and start some tile requests through makeWebRequest
            // and some others through pushing tiles from the companion app
            // seems really hard to maintain though, and ble connection probably already saturated
            start();
            return true;
        }

        return false;
    }

    function decrementOutstanding(hash as String) as Void {
        --_outstandingCount;
        outstandingHashes.remove(hash);
    }

    function start() as Void {
        ++_outstandingCount;
        if (pendingTransmit.size() != 0) {
            // prioritize the  transmits over tile/web loads
            var transmitEntry = pendingTransmit[0];
            pendingTransmit.remove(transmitEntry);
            Communications.transmit(
                transmitEntry[0],
                transmitEntry[1],
                new ConnectionListenerWrapper(me, transmitEntry[2])
            );
            return;
        }

        var webReq = pending[0];
        pending.remove(webReq);
        // trust that the keys are in the same order as the hash
        pendingHashes.remove(webReq.hash);
        if (pending.size() != pendingHashes.size()) {
            logE("size mismatch: " + pending.size() + " " + pendingHashes.size());
            pending = [];
            pendingHashes = [];
        }
        outstandingHashes.add(webReq.hash);

        // logT("url: " + webReq.url);
        // logT("params: "  + webReq.params);
        webReq.start(me, _settings);

        if (webReq instanceof ImageRequest) {
            return;
        }
    }

    function clearStats() as Void {
        _errorCount = 0;
        _successCount = 0;
        _lastResult = 0;
    }
}
