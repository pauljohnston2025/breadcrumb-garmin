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
    private var halfHitboxSize as Number = 35;
    private var currentSelected as Number = 0; // needs to always be a valid index of choices array

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
    protected function backgroundColourInner() as Number {
        return Graphics.COLOR_BLACK;
    }
}

(:settingsView)
class SingleLetterPicker extends PositionPickerGeneric {
    private var charset as String;
    private var onReading as (Method(value as String) as Void);

    function initialize(charset as String, onReading as (Method(value as String) as Void)) {
        self.charset = charset;
        self.onReading = onReading;

        var stringArr = [] as Array<String>;
        for (var i = 0; i < charset.length(); ++i) {
            stringArr.add(charset.substring(i, i + 1) as String);
        }

        PositionPickerGeneric.initialize(stringArr as Array<String>);
    }

    function performAction(tapIndex as Number) as Boolean {
        onReading.invoke(self.charset.substring(tapIndex, tapIndex + 1) as String);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

enum /*TextEditor*/ {
    TEXT_EDITOR_OK,
    TEXT_EDITOR_DEL,
    TEXT_EDITOR_LEFT,
    TEXT_EDITOR_RIGHT,

    TEXT_EDITOR_MAX,
}

(:settingsView)
class TextEditorPicker extends PositionPickerGeneric {
    private var onReading as (Method(value as String) as Void);
    private var currentVal as String;
    private var parent as Renderable;
    private var pickers as Array<SingleLetterPicker>;
    private var cursorIndex as Number = 0; // Track cursor position

    function initialize(
        onReading as (Method(value as String) as Void),
        initialValue as String,
        parent as Renderable
    ) {
        self.currentVal = initialValue;
        self.onReading = onReading;
        self.parent = parent;
        self.cursorIndex = initialValue.length(); // Start at the end

        self.pickers = [
            new SingleLetterPicker("abcdefghijklm", method(:addLetter)),
            new SingleLetterPicker("nopqrstuvwxyz", method(:addLetter)),
            new SingleLetterPicker("ABCDEFGHIJKLM", method(:addLetter)),
            new SingleLetterPicker("NOPQRSTUVWXYZ", method(:addLetter)),
            new SingleLetterPicker("0123456789", method(:addLetter)),
            new SingleLetterPicker("`~!@#$%^&*()-_=+", method(:addLetter)),
            new SingleLetterPicker("[]{}\\|;:'\"/,.<>?", method(:addLetter)),
        ];

        PositionPickerGeneric.initialize([
            "OK",
            "del",
            "<<",
            ">>",
            "a-m",
            "n-z",
            "A-M",
            "N-Z",
            "0-9",
            "~-=",
            "[-?",
        ]);

        updateDisplayText();
        forceRefresh();
    }

    private const MAX_DISPLAY_CHARS = 12;

    private function updateDisplayText() as Void {
        var totalLen = currentVal.length();

        // 1. If it fits entirely, just do the one-time build
        if (totalLen < MAX_DISPLAY_CHARS) {
            myText.setText(
                currentVal.substring(0, cursorIndex) + "|" + currentVal.substring(cursorIndex, null)
            );
            return;
        }

        // 2. Calculate the window around the cursorIndex
        // We want the cursor roughly in the middle
        var halfWindow = MAX_DISPLAY_CHARS / 2;
        var windowStart = cursorIndex - halfWindow;
        var windowEnd = cursorIndex + halfWindow;

        // 3. Clamp the window to string boundaries
        if (windowStart < 0) {
            windowEnd -= windowStart; // Shift the end right
            windowStart = 0;
        }

        if (windowEnd > totalLen) {
            windowStart -= windowEnd - totalLen; // Shift the start left
            windowEnd = totalLen;
            if (windowStart < 0) {
                windowStart = 0;
            }
        }

        // 4. Build the final display string with minimal allocations
        // This creates 2 small strings and joins them with the cursor
        var leftPart = currentVal.substring(windowStart, cursorIndex);
        var rightPart = currentVal.substring(cursorIndex, windowEnd);

        myText.setText(leftPart + "|" + rightPart);
    }

    function addLetter(letter as String) as Void {
        // Insert letter at cursor position
        var prefix = currentVal.substring(0, cursorIndex);
        var suffix = currentVal.substring(cursorIndex, null);
        if (prefix == null || suffix == null) {
            return; // something went horribly wrong
        }
        currentVal = prefix + letter + suffix;

        cursorIndex++; // Move cursor forward
        updateDisplayText();
        // forceRefresh(); do not push another view the SingleLetterPicker will pop its view and we will render
    }

    protected function performAction(tapIndex as Number) as Boolean {
        if (tapIndex == TEXT_EDITOR_OK) {
            onReading.invoke(currentVal);
            parent.rerender();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        } else if (tapIndex == TEXT_EDITOR_DEL) {
            return deleteChar();
        } else if (tapIndex == TEXT_EDITOR_LEFT) {
            if (cursorIndex > 0) {
                cursorIndex--;
                updateDisplayText();
                forceRefresh();
            }
            return true;
        } else if (tapIndex == TEXT_EDITOR_RIGHT) {
            if (cursorIndex < currentVal.length()) {
                cursorIndex++;
                updateDisplayText();
                forceRefresh();
            }
            return true;
        }

        var picker = self.pickers[tapIndex - TEXT_EDITOR_MAX];
        WatchUi.pushView(
            new $.NumberPickerView(picker),
            new $.NumberPickerDelegate(picker),
            WatchUi.SLIDE_IMMEDIATE
        );
        return true;
    }

    function deleteChar() as Boolean {
        if (cursorIndex > 0) {
            // Delete character BEFORE the cursor
            var prefix = currentVal.substring(0, cursorIndex - 1);
            var suffix = currentVal.substring(cursorIndex, null);
            if (prefix == null || suffix == null) {
                return false; // something went horribly wrong
            }
            currentVal = prefix + suffix;
            cursorIndex--;
            updateDisplayText();
            forceRefresh();
        }
        return true;
    }

    function onBack() as Void {
        // deleteChar();
        // just dismiss the ui, no changes
        // its not like the number pickers where the string is small and we can re-type it
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
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

        PositionPickerGeneric.initialize(stringArr as Array<String>);
    }

    function performAction(tapIndex as Number) as Boolean {
        if (tapIndex == 0) {
            // we are on the 'OK' button
            onReading(currentVal);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        if (currentVal.length() >= maxLength) {
            return false; // can't handle it
        }

        if (tapIndex != 0) {
            currentVal += self._charset.substring(tapIndex - 1, tapIndex);
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

    protected function onReading(value as String) as Void;
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
    private var picker as PositionPickerGeneric;

    function initialize(picker as PositionPickerGeneric) {
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
