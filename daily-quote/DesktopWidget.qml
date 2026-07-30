import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.System
import qs.Services.UI
import qs.Widgets

DraggableDesktopWidget {
    id: root
    property var pluginApi: null

    // --- Read from widgetData (injected by DesktopWidgets.qml) ---
    readonly property string storedQuote: widgetData?.currentQuote ?? ""
    readonly property string storedAuthor: widgetData?.currentAuthor ?? ""
    readonly property string storedDate: widgetData?.lastDate ?? ""
    readonly property string scrambleSpeed: widgetData?.scrambleSpeed ?? "medium"
    readonly property string scrambleChars: widgetData?.scrambleChars ?? "mix"
    readonly property bool showAuthor: widgetData?.showAuthor ?? true
    readonly property bool autoChangeDaily: widgetData?.autoChangeDaily ?? true
    readonly property string quoteFont: widgetData?.quoteFont ?? ""
    readonly property string authorFont: widgetData?.authorFont ?? ""
    readonly property string quoteColor: widgetData?.quoteColor ?? "primary"
    readonly property string textAlign: widgetData?.textAlign ?? "left"
    readonly property bool showGradientOverlay: widgetData?.showGradientOverlay ?? true
    readonly property string gradientDirection: widgetData?.gradientDirection ?? "vertical"

    // --- Adaptive gradient color: dark mode = black, light mode = white ---
    readonly property real _gradR: Settings.data.colorSchemes.darkMode ? 0 : 1
    readonly property real _gradG: Settings.data.colorSchemes.darkMode ? 0 : 1
    readonly property real _gradB: Settings.data.colorSchemes.darkMode ? 0 : 1

    // --- Resolved alignment ---
    readonly property int _effectiveAlign: textAlign === "center" ? Qt.AlignHCenter : textAlign === "right" ? Qt.AlignRight : Qt.AlignLeft

    // --- Resolved colors from color key ---
    readonly property color resolvedTextColor: Color.resolveColorKey(quoteColor)
    readonly property color resolvedOnTextColor: Color.resolveOnColorKey(quoteColor)

    // --- Internal display state ---
    property string displayedQuote: ""
    property string displayedAuthor: ""

    // --- Scramble engine ---
    property var _charStates: []
    property bool _isAnimating: false
    property string _targetText: ""
    property int _revealIndex: 0       // next char to start scrambling
    property int _activeCount: 0       // chars with iteration >= 1 (being scrambled)
    property bool _pendingPersist: false
    property bool _selfUpdate: false

    readonly property var _charSets: ({
        "ascii": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
        "symbols": "!@#$%^&*()_+-=[]{}|;:<>?/~\u2591\u2592\u2593\u2588\u2584\u2580\u25A0\u25A1\u2557\u2551\u255A\u255D\u2310\u00AC\u2569\u2566\u2560\u2550\u256C",
        "mix": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*\u2591\u2592\u2593\u2588\u2584\u2580\u25A0\u25A1\u2557\u255A\u255D\u2551\u2569\u2566\u2560\u2550\u256C"
    })
    readonly property string _charSet: _charSets[scrambleChars] || _charSets["mix"]

    readonly property var speedPresets: ({
        "fast":   { "tick": 30,  "iterations": 3, "revealPerTick": 3 },
        "medium": { "tick": 35,  "iterations": 5, "revealPerTick": 2 },
        "slow":   { "tick": 50,  "iterations": 7, "revealPerTick": 1 }
    })
    readonly property var speedConfig: speedPresets[scrambleSpeed] || speedPresets["medium"]

    // --- Sizing ---
    implicitWidth: Math.round(320 * widgetScale)
    implicitHeight: Math.round(contentLayout.implicitHeight + Style.marginL * 2 * widgetScale)
    width: implicitWidth
    height: implicitHeight

    // --- Built-in quote pool (loaded from quotes.json) ---
    property var builtinQuotes: []
    readonly property string _quotesPath: pluginApi ? pluginApi.pluginDir + "/quotes.json" : ""

    FileView {
        id: quotesFileView
        path: root._quotesPath || undefined
        watchChanges: true
        onLoaded: {
            try {
                var data = JSON.parse(quotesFileView.text());
                if (Array.isArray(data) && data.length > 0) {
                    root.builtinQuotes = data;
                    // Trigger init if widget data was already injected but quotes weren't loaded yet
                    if (root.widgetData && !root.initialized) {
                        root._tryInit();
                    }
                }
            } catch (e) {
                Logger.w("DailyQuote", "Failed to parse quotes.json:", e.message);
            }
        }
        onFileChanged: reload()
    }

    // --- Deferred init: wait for both widgetData and quotes ---
    function _tryInit() {
        if (initialized || !widgetData || builtinQuotes.length === 0) return;
        initialized = true;
        var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (storedQuote && storedDate === today) {
            displayedQuote = storedQuote;
            displayedAuthor = storedAuthor;
            _startScramble(storedQuote, false);
        } else {
            refreshQuote();
        }
    }

    // --- Scramble engine ---
    function _startScramble(text, animate) {
        _tickTimer.stop();
        _targetText = text;
        _revealIndex = 0;
        _activeCount = 0;

        if (!animate) {
            _isAnimating = false;
            var states = [];
            for (var i = 0; i < text.length; i++) {
                states.push({ "settled": true, "iteration": speedConfig.iterations + 1, "current": text.charAt(i) });
            }
            _charStates = states;
            _updateDisplay();
            return;
        }

        _isAnimating = true;
        var states = [];
        for (var i = 0; i < text.length; i++) {
            if (text.charAt(i) === " ") {
                states.push({ "settled": true, "iteration": 0, "current": " " });
            } else {
                states.push({
                    "settled": false,
                    "iteration": 0,
                    "current": _charSet.charAt(Math.floor(Math.random() * _charSet.length))
                });
            }
        }
        _charStates = states;
        _updateDisplay();
        _tickTimer.start();
    }

    // --- Persist current quote to widgetData ---
    function _persistQuote() {
        _selfUpdate = true;
        if (widgetIndex >= 0 && screen) {
            DesktopWidgetRegistry.updateWidgetData(screen.name, widgetIndex, {
                "currentQuote": displayedQuote,
                "currentAuthor": displayedAuthor,
                "lastDate": Qt.formatDate(new Date(), "yyyy-MM-dd")
            });
        }
        Qt.callLater(function() { _selfUpdate = false; });
    }

    // --- Refresh: new quote + scramble animation ---
    function refreshQuote() {
        var pool = builtinQuotes.concat(widgetData?.userQuotes || []);
        if (pool.length === 0) {
            displayedQuote = "Agrega tu primera frase en la configuracion";
            displayedAuthor = "";
            _startScramble(displayedQuote, false);
            _persistQuote();
            return;
        }
        var attempts = 0;
        var selected;
        do {
            selected = pool[Math.floor(Math.random() * pool.length)];
            attempts++;
        } while (pool.length > 1 && selected.text === displayedQuote && attempts < 10);

        displayedQuote = selected.text;
        displayedAuthor = selected.author || "";
        _pendingPersist = true;
        _startScramble(displayedQuote, true);
    }

    function _updateDisplay() {
        var html = "";
        var settledColor = root.resolvedTextColor.toString();
        var accentR = root.resolvedTextColor.r;
        var accentG = root.resolvedTextColor.g;
        var accentB = root.resolvedTextColor.b;

        for (var i = 0; i < _charStates.length; i++) {
            var s = _charStates[i];
            var ch = s.current;
            if (ch === "<") ch = "&lt;";
            else if (ch === ">") ch = "&gt;";
            else if (ch === "&") ch = "&amp;";
            else if (ch === "\"") ch = "&quot;";

            if (s.settled || _targetText.charAt(i) === " ") {
                html += "<span style=\"color:" + settledColor + "\">" + ch + "</span>";
            } else if (s.iteration === 0) {
                var dimColor = Qt.rgba(accentR, accentG, accentB, 0.3);
                html += "<span style=\"color:" + dimColor.toString() + "\">" + ch + "</span>";
            } else {
                var progress = s.iteration / (speedConfig.iterations + 1);
                var alpha = 0.5 + (progress * 0.5);
                var scrambleColor = Qt.rgba(accentR, accentG, accentB, alpha);
                html += "<span style=\"color:" + scrambleColor.toString() + "\">" + ch + "</span>";
            }
        }
        scrambleDisplay.text = html;
    }

    // --- Single animation timer ---
    Timer {
        id: _tickTimer
        interval: root.speedConfig.tick
        repeat: true
        running: false

        onTriggered: {
            var states = root._charStates.slice();
            var changed = false;

            // 1) Reveal: activate next characters
            for (var r = 0; r < root.speedConfig.revealPerTick; r++) {
                if (root._revealIndex >= states.length) break;
                if (root._targetText.charAt(root._revealIndex) !== " ") {
                    states[root._revealIndex] = {
                        "settled": false,
                        "iteration": 1,
                        "current": root._charSet.charAt(Math.floor(Math.random() * root._charSet.length))
                    };
                    changed = true;
                }
                root._revealIndex++;
            }

            // 2) Scramble: advance all active chars
            var allSettled = true;
            for (var i = 0; i < states.length; i++) {
                if (states[i].settled) continue;
                if (states[i].iteration === 0) { allSettled = false; continue; }

                allSettled = false;
                var iter = states[i].iteration + 1;
                if (iter > root.speedConfig.iterations) {
                    states[i] = { "settled": true, "iteration": iter, "current": root._targetText.charAt(i) };
                } else {
                    states[i] = { "settled": false, "iteration": iter, "current": root._charSet.charAt(Math.floor(Math.random() * root._charSet.length)) };
                }
                changed = true;
            }

            if (changed) {
                root._charStates = states;
                root._updateDisplay();
            }

            if (allSettled) {
                _tickTimer.stop();
                root._isAnimating = false;
                if (root._pendingPersist) {
                    root._pendingPersist = false;
                    root._persistQuote();
                }
            }
        }
    }

    // Safety net: force-end animation if stuck (max 8s)
    Timer {
        id: _animationWatchdog
        interval: 8000
        repeat: false
        running: root._isAnimating
        onTriggered: {
            if (root._isAnimating) {
                _tickTimer.stop();
                root._isAnimating = false;
                // Force-settle all remaining chars
                var states = root._charStates.slice();
                for (var i = 0; i < states.length; i++) {
                    if (!states[i].settled) {
                        states[i] = { "settled": true, "iteration": root.speedConfig.iterations + 1, "current": root._targetText.charAt(i) };
                    }
                }
                root._charStates = states;
                root._updateDisplay();
                if (root._pendingPersist) {
                    root._pendingPersist = false;
                    root._persistQuote();
                }
            }
        }
    }

    // --- Init ---
    property bool initialized: false
    onWidgetDataChanged: {
        if (!widgetData) return;
        if (_isAnimating) return;
        if (_selfUpdate) return;
        _tryInit();
    }

    // --- Midnight auto-change ---
    Timer {
        interval: 60000
        repeat: true
        running: root.initialized && root.autoChangeDaily
        onTriggered: {
            var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
            if (root.storedDate !== today) root.refreshQuote();
        }
    }

    // --- Click anywhere to refresh ---
    MouseArea {
        id: clickArea
        anchors.fill: parent
        z: 2
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: root._isAnimating ? Qt.BusyCursor : Qt.PointingHandCursor
        onClicked: {
            if (!root._isAnimating) root.refreshQuote();
        }
    }

    // --- Gradient overlay (when background is off) ---
    Rectangle {
        id: gradientOverlay
        anchors.fill: parent
        z: 0
        visible: !root.showBackground && root.showGradientOverlay
        radius: root.roundedCorners ? Math.min(Math.round(Style.radiusL * widgetScale), Style.radiusL, width / 2, height / 2) : 0
        gradient: Gradient {
            orientation: root.gradientDirection === "horizontal" ? Gradient.Horizontal : Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.rgba(root._gradR, root._gradG, root._gradB, 0.35)
            }
            GradientStop {
                position: 0.6
                color: Qt.rgba(root._gradR, root._gradG, root._gradB, 0.15)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(root._gradR, root._gradG, root._gradB, 0.05)
            }
        }
    }

    // --- Visual content ---
    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        z: 1
        anchors.leftMargin: Math.round(Style.marginL * widgetScale)
        anchors.rightMargin: Math.round(Style.marginL * widgetScale)
        anchors.topMargin: Math.round(Style.marginM * widgetScale)
        anchors.bottomMargin: Math.round(Style.marginM * widgetScale)
        spacing: Math.round(Style.marginS * widgetScale)

    Text {
        id: scrambleDisplay
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        textFormat: Text.RichText
        wrapMode: Text.WordWrap
        horizontalAlignment: root._effectiveAlign
        color: Color.mOnSurface
        font.pointSize: Math.round(Style.fontSizeM * widgetScale)
        font.family: root.quoteFont || "monospace"
    }

    NText {
        id: authorText
        Layout.fillWidth: true
        text: root.displayedAuthor ? "\u2014 " + root.displayedAuthor : ""
        color: root.resolvedTextColor
        pointSize: Math.round(Style.fontSizeS * widgetScale)
        family: root.authorFont || Settings.data.ui.fontDefault
        font.italic: true
        horizontalAlignment: root._effectiveAlign
        visible: root.showAuthor && root.displayedAuthor !== ""
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    // Subtle hint
    NText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        text: root._isAnimating ? "" : "click anywhere to refresh"
        color: root.resolvedTextColor
        pointSize: Math.round(Style.fontSizeXS * widgetScale)
        opacity: clickArea.containsMouse && !root._isAnimating ? 0.6 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    }
}
