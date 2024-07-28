import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

// note to get this to work on the simulator need to modify simulator.json and
// add isTouchable this is already on edgo devices with touch, but not the
// venu2s, even though I tested and it worked on the actual device
// C:\Users\RandomGuy2.1\AppData\Roaming\Garmin\ConnectIQ\Devices\venu2s\simulator.json
// "datafields": {
// 				"isTouchable": true,
//                 "datafields": [
// note: this only allows taps, cannot handle swipes/holds etc. (need to test on
// real device)
class BreadcrumbDataFieldView extends WatchUi.DataField {
  var _breadcrumbContext as BreadcrumbContext;

  // Set the label of the data field here.
  function initialize(breadcrumbContext as BreadcrumbContext) {
    _breadcrumbContext = breadcrumbContext;
    DataField.initialize();
  }

  function onLayout(dc as Dc) as Void {
    // for now we render everything in the onUpdate view, and assume only 1 data
    // screen
  }

  function compute(info as Activity.Info) as Void {
    System.println("computing data field");
    _breadcrumbContext.track().onActivityInfo(info);
    _breadcrumbContext.trackRenderer().onActivityInfo(info);
  }

  function onUpdate(dc as Dc) as Void {
    System.println("onUpdate data field");

    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();

    var renderer = _breadcrumbContext.trackRenderer();
    var route = _breadcrumbContext.route();

    renderer.renderUi(dc);
    if (route != null) {
      renderer.renderTrack(dc, route, Graphics.COLOR_BLUE);
    }
    renderer.renderTrack(dc, _breadcrumbContext.track(), Graphics.COLOR_RED);
  }
}