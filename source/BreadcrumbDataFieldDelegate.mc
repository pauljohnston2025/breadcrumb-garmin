import Toybox.WatchUi;
import Toybox.System;

// see BreadcrumbDataFieldView if touch stops working
class BreadcrumbDataFieldDelegate extends WatchUi.InputDelegate {
  var _breadcrumbContext as BreadcrumbContext;

  function initialize(breadcrumbContext as BreadcrumbContext) {
    InputDelegate.initialize();
    _breadcrumbContext = breadcrumbContext;
  }

  function onKey(keyEvent as WatchUi.KeyEvent) {
    System.println("got key event: " + keyEvent.getKey());  // e.g. KEY_MENU = 7
    return false;
  }

  // see BreadcrumbDataFieldView if touch stops working
  function onTap(evt as WatchUi.ClickEvent) {
    System.println("got tap (x,y): (" + evt.getCoordinates()[0] + "," +
                   evt.getCoordinates()[1] + ")");

    var coords = evt.getCoordinates();
    var x = coords[0];
    var y = coords[1];

    // perhaps put this into new class to handle touch events, and have a
    // renderer for that ui would allow us to switch out ui and handle touched
    // differently also will alow setting the scren height
    if (y < 50) {
      _breadcrumbContext.trackRenderer().incScale();
    } else if(y > 310) {
      _breadcrumbContext.trackRenderer().decScale();
    }
    else if(x > 310) {
      _breadcrumbContext.trackRenderer().resetScale();
    }
    else if(x < 50) {
      _breadcrumbContext.trackRenderer().toggleFullView();
    }
    return false;
  }
}