// layout inspired by https://github.com/vtrifonov-esfiddle/ConnectIqDataPickers
// but I have simplified the ui significantly

import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

(:settingsView)
class PositionPickerGeneric {
    private var choices as Array<String>;
    private var choicePositions as Array<[Float, Float]>;
    private var halfWidth as Number?;
    protected var myText as WatchUi.Text;
    var halfHitboxSize as Number = 35;
    var currentSelected as Number = 0; // needs to always be a valid index of choices array

    function initialize(choices as Array<String>) {
        self.choices = choices;
        choicePositions = [];
        halfWidth = null;

        myText = new WatchUi.Text({
            :text => "",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_SMALL,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER,
        });
    }

    function onLayout(dc as Dc) as Void {
        halfWidth = dc.getWidth() / 2;
        choicePositions = pointsOnCircle(
            halfWidth,
            halfWidth,
            halfWidth - halfHitboxSize,
            choices.size()
        );
    }

    private function pointsOnCircle(
        centerX as Number,
        centerY as Number,
        radius as Number,
        numPoints as Number
    ) as Array<[Float, Float]> {
        var points = new [numPoints];

        var angleIncrement = (2 * Math.PI) / numPoints;

        var x0 = (centerX + radius).toFloat();
        var y0 = centerY.toFloat();
        points[0] = [x0, y0];
        var x = x0;
        var y = y0;

        for (var i = 1; i < numPoints; i++) {
            var angle = i * angleIncrement;

            x = centerX + radius * Math.cos(angle).toFloat();
            y = centerY + radius * Math.sin(angle).toFloat();

            points[i] = [x, y];
        }

        // adjust the hitbox to be the max size between the points
        halfHitboxSize = distance(x0, y0, x, y).toNumber() / 2;

        return points as Array<[Float, Float]>;
    }

    function onUpdate(dc as Dc) as Void {
        var bgColour = backgroundColourInner();
        dc.setColor(Graphics.COLOR_WHITE, bgColour);
        dc.clear();
        dc.setPenWidth(4);
        dc.drawText(
            choicePositions[0][0],
            choicePositions[0][1],
            Graphics.FONT_SMALL,
            "OK",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        for (var i = 0; i < choicePositions.size(); ++i) {
            var point = choicePositions[i];
            var pointX = point[0];
            var pointY = point[1];
            var choice = self.choices[i];
            dc.drawText(
                pointX,
                pointY,
                Graphics.FONT_SMALL,
                choice,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
        var selected = choicePositions[currentSelected];
        dc.drawCircle(selected[0], selected[1], halfHitboxSize);

        myText.draw(dc);
    }

    function confirm() as Void {
        var position = choicePositions[currentSelected];
        onTap(position[0].toNumber(), position[1].toNumber());
    }

    function previousSelection() as Void {
        --currentSelected;
        if (currentSelected < 0) {
            currentSelected = choicePositions.size() - 1;
        }
        forceRefresh();
    }

    function nextSelection() as Void {
        ++currentSelected;
        if (currentSelected >= choicePositions.size()) {
            currentSelected = 0;
        }
        forceRefresh();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onTap(x as Number, y as Number) as Boolean {
        // for touch devices if we press the ok button exit immediately
        var tapIndex = indexOfTap(x, y);
        if (tapIndex == null) {
            return false;
        }

        return performAction(tapIndex);
    }

    function indexOfTap(x as Number, y as Number) as Number? {
        for (var i = 0; i < choicePositions.size(); i++) {
            var point = choicePositions[i];
            var pointX = point[0];
            var pointY = point[1];

            // Check if the tap is within the hit box
            if (inHitbox(x, y, pointX, pointY, halfHitboxSize.toFloat())) {
                currentSelected = i;
                return i;
            }
        }

        return null;
    }

    // performAction for the current index
    // eg.
    // onReading(myLookupThingToDo[tapIndex]);
    // WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    protected function performAction(tapIndex as Number) as Boolean {
        return false;
    }
    protected function onReading(value as String) as Void;
    protected function backgroundColourInner() as Number {
        return Graphics.COLOR_BLACK;
    }
}

(:settingsView)
class NumberPicker extends PositionPickerGeneric {
    private var _charset as String;
    public var maxLength as Number;
    public var currentVal as String;

    function initialize(charset as String, maxLength as Number) {
        self._charset = charset;
        self.maxLength = maxLength;
        self.currentVal = "";

        var stringArr = ["OK"] as Array<String>;
        for (var i = 0; i < charset.length(); ++i) {
            stringArr.add(charset.substring(i, i + 1) as String);
        }

        PositionPickerGeneric.initialize(stringArr);
    }

    function performAction(tapIndex as Number) as Boolean {
        if (currentSelected == 0) {
            // we are on the 'OK' button
            onReading(currentVal);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        if (currentVal.length() >= maxLength) {
            return false; // can't handle it
        }

        if (tapIndex != 0) {
            currentVal += self._charset.substring(tapIndex -1, tapIndex);
        }

        myText.setText(currentVal);

        forceRefresh();
        return true;
    }

    function onBack() as Void {
        if (currentVal.length() <= 0) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return;
        }

        var subStr = currentVal.substring(null, -1);
        if (subStr != null) {
            currentVal = subStr;
            myText.setText(currentVal);
            forceRefresh();
        }
    }

    protected function backgroundColourInner() as Number {
        return backgroundColour(currentVal);
    }

    protected function backgroundColour(value as String) as Number {
        return Graphics.COLOR_BLACK;
    }
}

(:settingsView)
class SettingsFloatPicker extends NumberPicker {
    private var callback as (Method(value as Float) as Void);
    private var parent as Renderable;
    private var defaultVal as Float;
    function initialize(
        callback as (Method(value as Float) as Void),
        defaultVal as Float,
        parent as Renderable
    ) {
        NumberPicker.initialize("0123456789.", 10);
        self.defaultVal = defaultVal;
        self.callback = callback;
        self.parent = parent;
    }

    protected function onReading(value as String) as Void {
        callback.invoke(Settings.parseFloatRaw("key", value, defaultVal));
        parent.rerender();
    }
}

(:settingsView)
class SettingsNumberPicker extends NumberPicker {
    private var callback as (Method(value as Number) as Void);
    private var parent as Renderable;
    private var defaultVal as Number;

    function initialize(
        callback as (Method(value as Number) as Void),
        defaultVal as Number,
        parent as Renderable
    ) {
        NumberPicker.initialize("-0123456789", 10);
        self.defaultVal = defaultVal;
        self.callback = callback;
        self.parent = parent;
    }

    protected function onReading(value as String) as Void {
        callback.invoke(Settings.parseNumberRaw("key", value, defaultVal));
        parent.rerender();
    }
}

(:settingsView)
class SettingsColourPickerTransparency extends NumberPicker {
    private var callback as (Method(value as Number) as Void);
    private var parent as Renderable;
    private var defaultVal as Number;
    private var allowTransparent as Boolean;
    function initialize(
        callback as (Method(value as Number) as Void),
        defaultVal as Number,
        parent as Renderable,
        allowTransparent as Boolean
    ) {
        var defaultOptions = "0123456789ABCDEF";
        if (allowTransparent) {
            defaultOptions += "T"; // transparent
        }
        NumberPicker.initialize(defaultOptions, 6);
        self.defaultVal = defaultVal;
        self.callback = callback;
        self.parent = parent;
        self.allowTransparent = allowTransparent;
    }

    protected function onReading(value as String) as Void {
        if (value.find("T") != null) {
            callback.invoke(Graphics.COLOR_TRANSPARENT); // transparent
        } else {
            callback.invoke(Settings.parseColourRaw("key", value, defaultVal, allowTransparent));
        }

        parent.rerender();
    }

    protected function backgroundColour(value as String) as Number {
        if (value.find("T") != null) {
            return Graphics.COLOR_TRANSPARENT;
        }

        return Settings.parseColourRaw("key", value, Graphics.COLOR_BLACK, allowTransparent);
    }
}

class SettingsColourPicker extends SettingsColourPickerTransparency {
    function initialize(
        callback as (Method(value as Number) as Void),
        defaultVal as Number,
        parent as Renderable
    ) {
        SettingsColourPickerTransparency.initialize(callback, defaultVal, parent, false);
    }
}

(:settingsView)
class RerenderIgnoredView extends WatchUi.View {
    function initialize() {
        View.initialize();

        // for some reason WatchUi.requestUpdate(); was not working so im pushing this view just to remove it, which should force a re-render
        // note: this seems to be a problem with datafields settings views on physical devices, appears to work fine on the sim
        // timer = new Timer.Timer();
        // need a timer running of this, since button presses from within the delegate were not triggering a reload
        // timer.start(method(:onTimer), 1000, true);
        // but timers are not available in the settings view (or at all in datafield)
        // "Module 'Toybox.Timer' not available to 'Data Field'"
    }

    function onLayout(dc as Dc) as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:settingsView)
function forceRefresh() as Void {
    WatchUi.requestUpdate(); // sometimes does not work, but lets call it anyway
    WatchUi.pushView(new RerenderIgnoredView(), null, WatchUi.SLIDE_IMMEDIATE);
}

(:settingsView)
class NumberPickerView extends WatchUi.View {
    private var picker as NumberPicker;

    function initialize(picker as NumberPicker) {
        self.picker = picker;
        View.initialize();

        // timer = new Timer.Timer();
        // need a timer running of this, since button presses from within the delegate were not triggering a reload
        // timer.start(method(:onTimer), 1000, true);
        // but timers are not available in the settings view (or at all in datafield)
        // "Module 'Toybox.Timer' not available to 'Data Field'"
    }

    function onLayout(dc as Dc) as Void {
        picker.onLayout(dc);
    }

    function onUpdate(dc as Dc) as Void {
        picker.onUpdate(dc);
        // logT("onUpdate");
        // Some exampls have the line below, do not do that, screen goes black (though it does work in the examples, guess just not when lanunched from menu?)
        // View.onUpdate(dc);
    }
}

(:settingsView)
class NumberPickerDelegate extends WatchUi.BehaviorDelegate {
    private var picker as PositionPickerGeneric;

    function initialize(picker as PositionPickerGeneric) {
        self.picker = picker;
        WatchUi.BehaviorDelegate.initialize();
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        logT(
            "got number picker tap (x,y): (" +
                evt.getCoordinates()[0] +
                "," +
                evt.getCoordinates()[1] +
                ")"
        );

        var coords = evt.getCoordinates();
        var x = coords[0];
        var y = coords[1];

        return picker.onTap(x, y);
    }

    // for touch devices this is touching a section on the screen (we want to handle the onTap instead)
    // for non touch its the 'confirm' button
    // function onSelect() as Boolean {
    //     logT("got number picker onselect: ");
    //     picker.confirm();
    //     WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    //     return true;
    // }

    function onPreviousPage() as Boolean {
        logT("got number picker onPreviousPage: ");
        // fr255 the up/down buttons are on the left so up should go more clockwise ie. nextSelection
        // some other watches might be the other way around though, need to test (or wait for complaints)
        picker.nextSelection();
        return true;
    }

    function onNextPage() as Boolean {
        logT("got number picker onNextPage: ");
        // fr255 the up/down buttons are on the left so down should go more counter-clockwise ie. previousSelection
        // some other watches might be the other way around though, need to test (or wait for complaints)
        picker.previousSelection();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        logT("got number picker key event: " + key);
        if (key == WatchUi.KEY_ENTER) {
            picker.confirm();
            return true;
        }

        return false;
    }

    function onBack() as Boolean {
        // logT("got back");
        picker.onBack();
        return true;
    }
}
