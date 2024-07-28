import Toybox.ActivityRecording;
import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Communications;


class BreadcrumbDataFieldApp extends Application.AppBase {
    var _view as BreadcrumbDataFieldView;
    var _bcView as BreadcrumbView;
    var _breadcrumbContext as BreadcrumbContext;

    function initialize() {
        AppBase.initialize();
        _breadcrumbContext = new BreadcrumbContext(); 
        _bcView = _breadcrumbContext.breadcrumbView();
        _view = new BreadcrumbDataFieldView(_bcView, _breadcrumbContext);
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        if(Communications has :registerForPhoneAppMessages) {
            System.println("registering for phone messages");
            Communications.registerForPhoneAppMessages( method(:onPhone));
        }
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        
        return [ _view , new BreadcrumbDataFieldDelegate(_bcView)];
    }

    function onPhone(msg as Communications.Message) as Void {
        System.println("got message");
        _view.onMessage();
    }
}

function getApp() as BreadcrumbDataFieldApp {
    return Application.getApp() as BreadcrumbDataFieldApp;
}