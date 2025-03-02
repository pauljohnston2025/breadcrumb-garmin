import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;
import Toybox.Application;

class BreadcrumbContext {
  var _breadcrumbRenderer as BreadcrumbRenderer;
  var _route as BreadcrumbTrack or Null;
  var _track as BreadcrumbTrack;

  // Set the label of the data field here.
  function initialize() {
    _breadcrumbRenderer = new BreadcrumbRenderer(me);
    _route = null;
    _track = new BreadcrumbTrack();

    var route = BreadcrumbTrack.readFromDisk(ROUTE_KEY);
    if (route != null) {
      _route = route;
    }
  }

  function trackRenderer() as BreadcrumbRenderer { return _breadcrumbRenderer; }
  function track() as BreadcrumbTrack { return _track; }
  function route() as BreadcrumbTrack or Null { return _route; }
  function newRoute() as BreadcrumbTrack {
    _route = new BreadcrumbTrack();
    return _route;
  }
  function clearRoute() as Void {
    newRoute();
    _route.writeToDisk(ROUTE_KEY);
  }
}