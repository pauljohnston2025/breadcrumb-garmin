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

  function onKey(keyEvent as WatchUi.KeyEvent) {
    System.println("got key event: " + keyEvent.getKey());  // e.g. KEY_MENU = 7
    return false;
  }

  // see BreadcrumbDataFieldView if touch stops working
  function onTap(evt as WatchUi.ClickEvent) as Boolean {
    // System.println("got tap (x,y): (" + evt.getCoordinates()[0] + "," +
    //                evt.getCoordinates()[1] + ")");

    var coords = evt.getCoordinates();
    var x = coords[0];
    var y = coords[1];
    var renderer = _breadcrumbContext.trackRenderer();

    if (renderer.handleClearRoute(x, y))
    {
      return true;
    }

    var hitboxSize = renderer.hitboxSize;
    var halfHitboxSize = hitboxSize / 2.0f;

    // perhaps put this into new class to handle touch events, and have a
    // renderer for that ui would allow us to switch out ui and handle touched
    // differently also will alow setting the scren height
    if (  y > renderer.modeSelectY - halfHitboxSize 
       && y < renderer.modeSelectY + halfHitboxSize  
       && x > renderer.modeSelectX - halfHitboxSize
       && x < renderer.modeSelectX + halfHitboxSize) {
      renderer.cycleMode();
      return true;
    }
    else if (y < hitboxSize) {
      renderer.incScale();
      return true;
    } else if(y > renderer._screenSize - hitboxSize) {
      renderer.decScale();
      return true;
    }
    else if(x > renderer._screenSize - hitboxSize) {
      renderer.resetScale();
      return true;
    }
    else if(x < hitboxSize) {
      renderer.toggleZoomAtPace();
      return true;
    }
    
    return false;
  }
}