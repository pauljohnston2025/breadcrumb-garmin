import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Application;

class BreadcrumbContext {
    var settings as Settings;
    var cachedValues as CachedValues;
    var breadcrumbRenderer as BreadcrumbRenderer;
    var routes as Array<BreadcrumbTrack>;
    var track as BreadcrumbTrack;
    var webRequestHandler as WebRequestHandler;
    var tileCache as TileCache;
    var mapRenderer as MapRenderer;

    // Set the label of the data field here.
    function initialize() {
        settings = new Settings();
        cachedValues = new CachedValues(settings);

        routes = [];
        track = new BreadcrumbTrack(TRACK_ID, "", settings.maxTrackPoints);
        breadcrumbRenderer = new BreadcrumbRenderer(settings, cachedValues);

        webRequestHandler = new WebRequestHandler(settings);
        tileCache = new TileCache(webRequestHandler, settings, cachedValues);
        mapRenderer = new MapRenderer(tileCache, settings, cachedValues);
    }

    function setup() as Void {
        settings.setup(); // we want to make sure everything is done later
        cachedValues.setup();
        tileCache.setup();

        // routes loaded from storage will be rescaled on the first calculate in cached values
        // had a bug where routes were still in storage, but removed from settings, so load everything that is enabled (up to 10 routes)
        // was some strange issue that i never could quite figure out, possibly when changing route max and disabling routes in settings in the same settings commit?
        var currentScale = cachedValues.currentScale;
        for (var i = 0; i < 10; ++i) {
            var route = BreadcrumbTrack.readFromDisk(ROUTE_KEY, i);
            if (route == null) {
                continue;
            }
            settings.ensureRouteIdNoSideEffect(route.storageIndex); // may not actually add the route if we are over route max
            if (settings.getRouteIndexById(route.storageIndex) == null) {
                clearRouteId(route.storageIndex); // clear it from storage, it was meant to get purged when we changed the settings
                continue;
            }

            if (settings.routeReversed(route.storageIndex)) {
                route.reverse();
            }

            if (currentScale != 0f) {
                // make sure we are in the correct scale
                route.rescale(currentScale);
            }

            routes.add(route);

            if (settings.routeName(route.storageIndex).equals("")) {
                // settings label takes precedence over our internal one until the setting route entry removed
                settings.setRouteNameNoSideEffect(route.storageIndex, route.name);
            }
        }

        // we pulled in some new route data, make sure we recalculate the bounding box etc.
        cachedValues.recalculateAll();
    }

    function newRoute(name as String) as BreadcrumbTrack? {
        if (settings.routeMax() <= 0) {
            WatchUi.showToast("Route Max is 0", {});
            return null; // cannot allocate routes
        }

        // we could maybe just not load the route if they are not enabled?
        // but they are pushing a new route from the app for this to happen
        // so forcing the new route to be enabled
        settings.setRoutesEnabled(true);

        // force the new route name into the settings
        // this can be kind of confusing, since we can have no routes in the context
        // but the settings can have a name and have the route allocated
        // routes should be created by pushing them to the watch from the companion app
        // if routes are configured in settings first, only the colour options will be preserved
        // Id's can be in any order, the next example is correct
        // eg me.routes = [] settings.routes = [{id:2, name: "customroute2"}, {id:0, name: "customroute0"}],
        // loading a route from the phone with name "phoneroute" will result in
        // eg me.routes = [BreadcrumbTrack{storageIndex:0, name: "phoneroute"}] settings.routes = [{id:2, name: "customroute2"}, {id:0, name: "phoneroute"}],
        // the colours will be uneffected
        // note: the route will also be force enabled, as described above
        if (routes.size() >= settings.routeMax()) {
            var oldestOrFirstDisabledRoute = null;
            for (var i = 0; i < routes.size(); ++i) {
                var thisRoute = routes[i];
                if (
                    oldestOrFirstDisabledRoute == null ||
                    oldestOrFirstDisabledRoute.createdAt > thisRoute.createdAt
                ) {
                    oldestOrFirstDisabledRoute = thisRoute;
                }

                if (!settings.routeEnabled(thisRoute.storageIndex)) {
                    oldestOrFirstDisabledRoute = thisRoute;
                    break;
                }
            }
            if (oldestOrFirstDisabledRoute == null) {
                logE(
                    "not possible (routes should be at least 1): " + settings.routeMax()
                );
                return null;
            }
            routes.remove(oldestOrFirstDisabledRoute);
            var routeId = oldestOrFirstDisabledRoute.storageIndex;
            var route = new BreadcrumbTrack(routeId, name, 0);
            routes.add(route);
            settings.ensureRouteId(routeId);
            settings.setRouteReversed(routeId, false);
            settings.setRouteName(routeId, route.name);
            settings.setRouteEnabled(routeId, true);
            settings.setRouteColour(routeId, settings.defaultRouteColour);
            return route;
        }

        var nextId = nextAvailableRouteId();
        if (nextId == null) {
            logE("failed to get route");
            // should never happen, we remove the oldest above if we are full, so just overwrite the first route
            nextId = 0;
        }
        var route = new BreadcrumbTrack(nextId, name, 0);
        routes.add(route);
        settings.ensureRouteId(nextId);
        settings.setRouteReversed(nextId, false);
        settings.setRouteName(nextId, route.name);
        settings.setRouteEnabled(nextId, true);
        settings.setRouteColour(nextId, settings.defaultRouteColour);
        return route;
    }

    function nextAvailableRouteId() as Number? {
        // ie. we might have storageIndex=0, storageIndex=3 so we should allocate storageIndex=1
        for (var i = 0; i < settings.routeMax(); ++i) {
            if (haveRouteId(i)) {
                continue;
            }

            return i;
        }

        return null;
    }

    function haveRouteId(routeId as Number) as Boolean {
        for (var j = 0; j < routes.size(); ++j) {
            if (routes[j].storageIndex == routeId) {
                return true;
            }
        }

        return false;
    }

    function clearRoutes() as Void {
        for (var i = 0; i < settings.routeMax(); ++i) {
            BreadcrumbTrack.clearRoute(ROUTE_KEY, i);
        }
        routes = [];
        settings.clearRoutes();
    }

    function clearRoute(routeId as Number) as Void {
        clearRouteId(routeId);
        settings.clearRoute(routeId);
    }

    function clearRouteId(routeId as Number) as Void {
        BreadcrumbTrack.clearRoute(ROUTE_KEY, routeId);
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (route.storageIndex == routeId) {
                routes.remove(route); // remove only safe because we return and stop itteration
                return;
            }
        }
    }

    function reverseRouteId(routeId as Number) as Void {
        for (var i = 0; i < routes.size(); ++i) {
            var route = routes[i];
            if (route.storageIndex == routeId) {
                route.reverse();
                return;
            }
        }
    }

    function purgeRoutes() as Void {
        routes = [];
    }
}
