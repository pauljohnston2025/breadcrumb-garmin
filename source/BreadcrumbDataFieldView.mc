import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Communications;
import Toybox.Graphics;

// note to get this to work on the simulator need to modify simulator.json and add isTouchable
// this is already on edgo devices with touch, but not the venu2s, even though I tested and it worked on the actual device
// C:\Users\RandomGuy2.1\AppData\Roaming\Garmin\ConnectIQ\Devices\venu2s\simulator.json
// "datafields": {
// 				"isTouchable": true,
//                 "datafields": [
// note: this only allows taps, cannot handle swipes/holds etc. (need to test on real device)
class BreadcrumbDataFieldView extends WatchUi.DataField {
  var _breadcrumbView as BreadcrumbView;
  var _breadcrumbContext as BreadcrumbContext;

  // Set the label of the data field here.
  function initialize(breadcrumbView as BreadcrumbView,
                      breadcrumbContext as BreadcrumbContext) {
    _breadcrumbContext = breadcrumbContext;
    _breadcrumbView = breadcrumbView;
    DataField.initialize();
  }

  function onLayout(dc as Dc) as Void {
    System.println("onLayout");
    var obscurityFlags = DataField.getObscurityFlags();

    // Top left quadrant so we'll use the top left layout
    if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
      View.setLayout(Rez.Layouts.TopLeftLayout(dc));

      // Top right quadrant so we'll use the top right layout
    } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
      View.setLayout(Rez.Layouts.TopRightLayout(dc));

      // Bottom left quadrant so we'll use the bottom left layout
    } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
      View.setLayout(Rez.Layouts.BottomLeftLayout(dc));

      // Bottom right quadrant so we'll use the bottom right layout
    } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
      View.setLayout(Rez.Layouts.BottomRightLayout(dc));

      // Use the generic, centered layout
    } else {
      View.setLayout(Rez.Layouts.MainLayout(dc));
      var labelView = View.findDrawableById("label") as Text;
      labelView.locY = labelView.locY - 16;
      var valueView = View.findDrawableById("value") as Text;
      valueView.locY = valueView.locY + 7;
    }

    (View.findDrawableById("label") as Text).setText(Rez.Strings.label);
  }

  function compute(info as Activity.Info) as Void {
    System.println("computing data field");
    _breadcrumbContext.onPosition(info.altitude, info.currentLocation);
  }

  function onUpdate(dc as Dc) as Void {
    System.println("onUpdate data field");
    _breadcrumbView.displayBreadCrumb(dc); 
  }

  function onMessage() as Void { System.println("got a message"); }
}