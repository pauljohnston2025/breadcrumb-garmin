import Toybox.Position;
import Toybox.Lang;
import Toybox.Activity;

class BreadcrumbContext {
  var _breadcrumbRenderer as BreadcrumbRenderer;
  var _route as BreadcrumbTrack or Null;
  var _track as BreadcrumbTrack;

  // Set the label of the data field here.
  function initialize() {
    _track = new BreadcrumbTrack();
    _breadcrumbRenderer = new BreadcrumbRenderer();
  }

  function trackRenderer() as BreadcrumbRenderer { return _breadcrumbRenderer; }
  function track() as BreadcrumbTrack { return _track; }
  function route() as BreadcrumbTrack or Null { return _route; }
}