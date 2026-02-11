import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

// see BreadcrumbDataFieldView if touch stops working
class BreadcrumbDataFieldDelegate extends WatchUi.InputDelegate {
    var _breadcrumbContext as BreadcrumbContext;

    function initialize(breadcrumbContext as BreadcrumbContext) {
        InputDelegate.initialize();
        _breadcrumbContext = breadcrumbContext;
    }

    // see BreadcrumbDataFieldView if touch stops working
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        if (getApp()._view.imageAlert != null) {
            // any touch cancels the alert
            getApp()._view.imageAlert = null;
            return true;
        }
        // logT("got tap (x,y): (" + evt.getCoordinates()[0] + "," +
        //                evt.getCoordinates()[1] + ")");

        var coords = evt.getCoordinates();
        var x = coords[0];
        var y = coords[1];
        var renderer = _breadcrumbContext.breadcrumbRenderer;
        var settings = _breadcrumbContext.settings;
        var cachedValues = _breadcrumbContext.cachedValues;

        var hitboxSize = renderer.hitboxSize;
        var halfHitboxSize = hitboxSize / 2.0f;

        if (settings.uiMode == UI_MODE_NONE) {
            return false;
        }

        if (cachedValues.seeding()) {
            // we are displaying the tile seed screen, only allow cancel
            if (y < hitboxSize) {
                // top of screen
                cachedValues.cancelCacheCurrentMapArea();
            }
            return true;
        }

        if (renderer.handleStartCacheRoute(x, y)) {
            return true;
        }

        if (renderer.handleStartMapEnable(x, y)) {
            return true;
        }

        if (renderer.handleStartMapDisable(x, y)) {
            return true;
        }

        if (renderer.handleClearRoute(x, y)) {
            // returns true if it handles touches on top left
            // also blocks input if we are in the menu
            return true;
        }

        // perhaps put this into new class to handle touch events, and have a
        // renderer for that ui would allow us to switch out ui and handle touched
        // differently also will alow setting the scren height
        if (inHitbox(x, y, renderer.modeSelectX, renderer.modeSelectY, halfHitboxSize)) {
            // top right
            settings.nextMode();
            return true;
        }

        if (settings.mode == MODE_DEBUG || settings.mode == MODE_ELEVATION) {
            return false;
        }

        var xHalfPhysical = cachedValues.xHalfPhysical; // local lookup faster
        var yHalfPhysical = cachedValues.yHalfPhysical; // local lookup faster

        if (inHitbox(x, y, renderer.returnToUserX, renderer.returnToUserY, halfHitboxSize)) {
            // return to users location
            // bottom left
            // reset scale to user tracking mode (we auto set it when enterring move mode so we do not get weird zooms when we are panning)
            // there is a chance the user already had a custom scale set (by pressing the +/- zoom  buttons on the track page)
            // but we will just clear it when they click 'go back to user', and it will now be whatever is in the 'zoom at pace' settings
            renderer.returnToUser();
            return true;
        }

        if (settings.mode == MODE_MAP_MOVE_ZOOM) {
            if (y < yHalfPhysical) {
                // anywhere top half of screen other than the mode button checked above
                renderer.incScale();
                return true;
            }

            renderer.decScale();
            return true;
        }
        
        if (settings.mode == MODE_MAP_MOVE_UP_DOWN) {
            if (y < yHalfPhysical) {
                // anywhere top half of screen other than the mode button checked above
                cachedValues.moveFixedPositionUp();
                return true;
            }

            cachedValues.moveFixedPositionDown();
            return true;
        }
        
         if (settings.mode == MODE_MAP_MOVE_LEFT_RIGHT) {
            if (x < xHalfPhysical) {
                // anywhere left half of screen other than the mode button checked above
                cachedValues.moveFixedPositionLeft();
                return true;
            }

            cachedValues.moveFixedPositionRight();
            return true;
        }

        if (inHitbox(x, y, renderer.clearRouteX, renderer.clearRouteY, halfHitboxSize)) {
            // top left
            if (settings.mode == MODE_MAP_MOVE) {
                renderer.incScale();
                return true;
            }
        }

        if (inHitbox(x, y, renderer.mapEnabledX, renderer.mapEnabledY, halfHitboxSize)) {
            // bottom right
            if (settings.mode == MODE_MAP_MOVE) {
                renderer.decScale();
                return true;
            }
        }

        if (y < hitboxSize) {
            // top of screen
            if (settings.mode == MODE_MAP_MOVE) {
                cachedValues.moveFixedPositionUp();
                return true;
            } else if (settings.mode == MODE_NORMAL) {
                renderer.incScale();
                return true;
            }
        } else if (y > cachedValues.physicalScreenHeight - hitboxSize) {
            // bottom of screen
            if (settings.mode == MODE_MAP_MOVE) {
                cachedValues.moveFixedPositionDown();
                return true;
            } else if (settings.mode == MODE_NORMAL) {
                renderer.decScale();
                return true;
            }
        } else if (x > cachedValues.physicalScreenWidth - hitboxSize) {
            // right of screen
            if (settings.mode == MODE_MAP_MOVE) {
                cachedValues.moveFixedPositionRight();
                return true;
            }
            // handled by handleStartCacheRoute
            // cachedValues.startCacheCurrentMapArea();
            return true;
        } else if (x < hitboxSize) {
            // left of screen
            if (settings.mode == MODE_MAP_MOVE) {
                cachedValues.moveFixedPositionLeft();
                return true;
            } else if (settings.mode == MODE_NORMAL) {
                settings.nextZoomAtPaceMode();
                return true;
            }
        }

        return false;
    }
}
