import Toybox.WatchUi;
import Toybox.System;

// see BreadcrumbDataFieldView if touch stops working
class BreadcrumbDataFieldDelegate extends WatchUi.InputDelegate {
  var _breadcrumbView as BreadcrumbView;

  function initialize(breadcrumbView as BreadcrumbView) {
    _breadcrumbView = breadcrumbView;
    InputDelegate.initialize();
  }

  function onKey(keyEvent as WatchUi.KeyEvent) {
    System.println(keyEvent.getKey());  // e.g. KEY_MENU = 7
    return true;
  }

  // see BreadcrumbDataFieldView if touch stops working
  function onTap(evt as WatchUi.ClickEvent) {
    return _breadcrumbView.onTap(evt);
  }

  function onSwipe(swipeEvent as WatchUi.SwipeEvent) {
    System.println(swipeEvent.getDirection());  // e.g. SWIPE_DOWN = 2
    return true;
  }
}