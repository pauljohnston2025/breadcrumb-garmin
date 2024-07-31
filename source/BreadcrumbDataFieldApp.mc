import Toybox.ActivityRecording;
import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;

enum Protocol {
  PROTOCOL_ROUTE_DATA = 0,
}

class BreadcrumbDataFieldApp extends Application.AppBase {
  var _view as BreadcrumbDataFieldView;
  var _breadcrumbContext as BreadcrumbContext;

  function initialize() {
    AppBase.initialize();
    _breadcrumbContext = new BreadcrumbContext();
    _view = new BreadcrumbDataFieldView(_breadcrumbContext);
  }

  // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
      if (Communications has : registerForPhoneAppMessages) {
        System.println("registering for phone messages");
        Communications.registerForPhoneAppMessages(method( : onPhone));
      }
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as[Views] or
        [Views, InputDelegates] {
          return [ _view, new BreadcrumbDataFieldDelegate(_breadcrumbContext) ];
        }

        function
        onPhone(msg as Communications.Message) as Void {
      var data = msg.data as Array<Number> or Null;
      if (data == null || data.size() < 1) {
        System.println("Bad message: " + data);
        return;
      }

      if (data[0] == PROTOCOL_ROUTE_DATA) {
        // protocol:
        //  RawData... [x, y, z]...  // latitude <float> and longitude <float>
        //  in degrees, altitude <float> too

        var rawData = data.slice(1, null);
        if (rawData.size() % 3 == 0) {
          var route = _breadcrumbContext.newRoute();
          for (var i = 0; i < rawData.size(); i += 3) {
            route.addPointRaw(rawData[i].toFloat(), rawData[i + 1].toFloat(),
                              rawData[i + 2].toFloat());
          }
          return;
        }

        System.println("Failed to parse route data, bad length: " +
                       rawData.size() + " remainder: " + rawData.size() % 3);
        return;
      }

      System.println("Unknown message type: " + data[0]);
    }
}

function getApp() as BreadcrumbDataFieldApp {
  return Application.getApp() as BreadcrumbDataFieldApp;
}