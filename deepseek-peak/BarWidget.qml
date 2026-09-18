import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    // Injected properties
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // Settings
    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string displayMode: cfg.displayMode ?? defaults.displayMode ?? "compact"
    readonly property color offPeakColor: cfg.offPeakColor ?? defaults.offPeakColor ?? "#4ade80"
    readonly property color peakColor: cfg.peakColor ?? defaults.peakColor ?? "#f87171"
    readonly property color driftColor: cfg.driftColor ?? defaults.driftColor ?? "#fbbf24"
    readonly property bool showTooltip: cfg.showTooltip ?? defaults.showTooltip ?? true
    readonly property string weekendMode: cfg.weekendMode ?? defaults.weekendMode ?? "beijing-anchored"

    // Optional shared state from Main.qml: used for drift only. Tier/countdown
    // are computed locally so the bar keeps working even if Main is missing.
    readonly property bool drift: pluginApi?.mainInstance?.drift ?? false

    // Local schedule state (peak.js is inlined below; see tools/sync_peak.py)
    property bool isPeak: false
    property int secondsToNext: 0
    property int _ticks: 999
    property string countdownText: formatHMS(0)
    property string stateText: ""
    property string tooltipFormat: ""

    // BEGIN peak.js (generated - edit peak.js and run tools/sync_peak.py)
// Shared pure logic for the DeepSeek peak/off-peak widget.
// Mirrors deepseek-peak/schedule.json (peak 01:00-04:00 + 06:00-10:00 UTC,
// Mon-Fri; weekend off-peak anchored to Beijing Sat/Sun = Fri 16:00Z-Sun 16:00Z).
//
// Single source of truth: tools/sync_peak.py inlines this file's body between
// the generated markers in BarWidget.qml and Panel.qml (the Noctalia v4 plugin
// loader cannot resolve relative .js imports from plugin QML).
//
// JS day convention: Date.getUTCDay() Sun=0..Sat=6 (differs from Python
// datetime.weekday() Mon=0..Sun=6 used in tests/test_schedule.py).

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

// Canonical peak windows, mirrored from deepseek-peak/schedule.json.
// tests/test_logic.js asserts these stay in sync with that file.
function scheduleWindows() {
    return [["01:00", "04:00"], ["06:00", "10:00"]];
}

function scheduleText() {
    return "01:00-04:00, 06:00-10:00 UTC";
}

function formatHMS(s) {
    s = Math.max(0, Math.floor(s));
    return pad(Math.floor(s / 3600)) + ":" + pad(Math.floor((s % 3600) / 60)) + ":" + pad(s % 60);
}

function isPeakAt(date, weekendMode) {
    var h = date.getUTCHours() + date.getUTCMinutes() / 60;
    if (weekendMode === "utc") {
        var uDay = date.getUTCDay();
        if (uDay === 0 || uDay === 6)
            return false;
        return (h >= 1 && h < 4) || (h >= 6 && h < 10);
    }
    var day = date.getUTCDay();
    var bjDay = new Date(date.getTime() + 8 * 3600 * 1000).getUTCDay();
    if (bjDay === 0 || bjDay === 6)
        return false;
    if (day === 6)
        return false;
    if (day === 5 && date.getUTCHours() >= 16)
        return false;
    if (day === 0 && date.getUTCHours() < 16)
        return false;
    return (h >= 1 && h < 4) || (h >= 6 && h < 10);
}

// Two-phase scan: coarse 60s steps to find the flip minute, then 1s refine
// inside that minute. Second-exact, ~228 iterations max instead of up to 10080.
function secondsUntilNext(date, weekendMode) {
    var peak = isPeakAt(date, weekendMode);
    var coarse = 0;
    for (var s = 60; s <= 7 * 86400; s += 60) {
        var d = new Date(date.getTime() + s * 1000);
        if (isPeakAt(d, weekendMode) !== peak) {
            coarse = s;
            break;
        }
    }
    if (coarse === 0)
        return 0;
    for (var t = coarse - 59; t <= coarse; t++) {
        var e = new Date(date.getTime() + t * 1000);
        if (isPeakAt(e, weekendMode) !== peak)
            return t;
    }
    return coarse;
}

function isWeekendOffDay(date, weekendMode) {
    if (weekendMode === "utc") {
        var uDay = date.getUTCDay();
        return uDay === 0 || uDay === 6;
    }
    var bjDay = new Date(date.getTime() + 8 * 3600 * 1000).getUTCDay();
    return bjDay === 0 || bjDay === 6;
}

// tz: "utc" | "beijing" | "local". Local uses the engine's local timezone at
// the given date (DST-correct); no Intl needed (Qt QML lacks Intl options).
function fmtHM(now, hour, minute, tz) {
    if (tz === "utc")
        return pad(hour) + ":" + pad(minute);
    if (tz === "beijing")
        return pad((hour + 8) % 24) + ":" + pad(minute);
    var d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hour, minute, 0));
    return pad(d.getHours()) + ":" + pad(d.getMinutes());
}

function windowLine(now, weekendMode, tz) {
    // null = weekend: the host shows its localized "off-peak all day".
    if (isWeekendOffDay(now, weekendMode))
        return null;
    return fmtHM(now, 1, 0, tz) + "-" + fmtHM(now, 4, 0, tz) + " · " + fmtHM(now, 6, 0, tz) + "-" + fmtHM(now, 10, 0, tz);
}

// Semantic relative "last checked" info: the host translates `key` with
// `{n}`. Keys live in deepseek-peak/i18n/*.json under "checked".
function checkedInfo(nowMs, checkedMs) {
    if (!checkedMs)
        return {key: "", n: 0, text: ""};
    var diff = Math.max(0, Math.floor((nowMs - checkedMs) / 1000));
    if (diff < 60)
        return {key: "checked.justNow", n: 0, text: ""};
    if (diff < 3600)
        return {key: "checked.minutesAgo", n: Math.floor(diff / 60), text: ""};
    if (diff < 86400)
        return {key: "checked.hoursAgo", n: Math.floor(diff / 3600), text: ""};
    var d = new Date(checkedMs);
    return {
        key: "checked.date",
        n: 0,
        text: pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + " " + pad(d.getHours()) + ":" + pad(d.getMinutes())
    };
}

// Window-set compare for policy drift: wording/spacing changes on the official
// page must not flag; only a real change of the HH:MM windows does.
function extractWindows(text) {
    var out = [];
    var re = /(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})/g;
    var m;
    while ((m = re.exec(text)) !== null)
        out.push(m[1] + "-" + m[2]);
    return out.sort();
}

function sameWindows(a, b) {
    if (a.length !== b.length)
        return false;
    for (var i = 0; i < a.length; i++)
        if (a[i] !== b[i])
            return false;
    return true;
}
// END peak.js (generated)

    // Per-screen bar properties (multi-monitor and vertical bar support)
    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property color stateColor: drift ? driftColor : (isPeak ? peakColor : offPeakColor)

    // Content dimensions follow the bar capsule: the loader extends the
    // click area to full bar height, the visual stays at content size.
    readonly property real contentWidth: contentRow.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: capsuleHeight

    implicitWidth: isBarVertical ? capsuleHeight : contentWidth
    implicitHeight: isBarVertical ? contentWidth : contentHeight

    function t(key, params) {
        return pluginApi?.tr(key, params);
    }
    function refreshTexts() {
        countdownText = formatHMS(secondsToNext);
        stateText = isPeak ? t("bar.peak") : t("bar.offPeak");
        tooltipFormat = (isPeak ? t("bar.tooltipPeak") : t("bar.tooltipOffPeak")) + " — " + t("bar.nextFlip") + " " + countdownText + (drift ? " — " + t("bar.driftSuffix") : "");
    }
    function update() {
        var now = new Date();
        isPeak = isPeakAt(now, weekendMode);
        if (_ticks >= 30 || secondsToNext <= 1) {
            secondsToNext = secondsUntilNext(now, weekendMode);
            _ticks = 0;
        } else {
            secondsToNext = Math.max(0, secondsToNext - 1);
            _ticks += 1;
        }
        refreshTexts();
    }

    Component.onCompleted: update()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    // Visual capsule - centered within the full click area
    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color: mouseArea.containsMouse ? Qt.lighter(Style.capsuleColor, 1.12) : Style.capsuleColor
        border.color: mouseArea.containsMouse ? root.stateColor : Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginS

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: "circle-filled"
                color: root.stateColor
            }
            NText {
                Layout.alignment: Qt.AlignVCenter
                visible: root.displayMode !== "icon"
                text: root.displayMode === "full" ? root.stateText + " " + root.countdownText : root.countdownText
                pointSize: root.barFontSize
                color: Color.mOnSurface
            }
        }
    }

    // Right-click menu
    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": pluginApi?.tr("menu.settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]
        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings" && pluginApi)
                BarService.openPluginSettings(screen, pluginApi.manifest);
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (root.showTooltip && root.tooltipFormat !== "")
                TooltipService.show(root, root.tooltipFormat, "auto");
        }
        onExited: TooltipService.hide(root)
        onClicked: function (mouse) {
            TooltipService.hide(root);
            if (!pluginApi)
                return;
            if (mouse.button === Qt.LeftButton)
                pluginApi.togglePanel(root.screen, root);
            else if (mouse.button === Qt.RightButton)
                PanelService.showContextMenu(contextMenu, root, screen);
        }
    }
}
