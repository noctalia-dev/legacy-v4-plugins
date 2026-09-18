import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

// Shared state owner: schedule math, the policy-drift checker, and the
// translated display strings rendered by BarWidget.qml and Panel.qml.
// Both components read this instance through pluginApi.mainInstance.
Item {
    id: root
    property var pluginApi: null

    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string weekendMode: cfg.weekendMode ?? defaults.weekendMode ?? "beijing-anchored"
    readonly property bool autoCheck: cfg.autoCheck ?? defaults.autoCheck ?? true
    readonly property bool offlineOnly: cfg.offlineOnly ?? defaults.offlineOnly ?? false
    readonly property int checkIntervalH: cfg.checkIntervalH ?? defaults.checkIntervalH ?? 6
    readonly property string customSourceUrl: cfg.customSourceUrl ?? defaults.customSourceUrl ?? ""
    readonly property string sourceUrl: customSourceUrl !== "" ? customSourceUrl : "https://api-docs.deepseek.com/quick_start/pricing/"
    readonly property var fallbackUrls: ["https://api-docs.deepseek.com/quick_start/pricing/", "https://www.deepseek.com/en/pricing"]
    property int checkTimeoutMs: 10000

    property bool isPeak: false
    property int secondsToNext: 0
    property bool drift: false
    property double checkedAtMs: 0
    property var nowDate: new Date()
    property int _ticks: 999

    // Display strings rebuilt every tick so late-arriving translations are used.
    property string countdownHMS: formatHMS(0)
    property string panelStateText: ""
    property string countdownLabel: ""
    property string localLine: ""
    property string utcLine: ""
    property string beijingLine: ""
    property string costText: ""
    property string checkedText: ""
    property string driftText: ""

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

    function t(key, params) {
        return pluginApi?.tr(key, params);
    }

    function lineFor(tz) {
        var w = windowLine(root.nowDate, root.weekendMode, tz);
        return w === null ? t("panel.weekendAllDay") : w;
    }
    function refreshTexts() {
        countdownHMS = formatHMS(secondsToNext);
        panelStateText = isPeak ? t("panel.peak") : t("panel.offPeak");
        countdownLabel = isPeak ? t("panel.offPeakIn") : t("panel.peakIn");
        localLine = t("panel.local") + "    " + lineFor("local");
        utcLine = t("panel.utc") + "      " + lineFor("utc");
        beijingLine = t("panel.beijing") + "  " + lineFor("beijing");
        costText = t("panel.cost");
        var ci = checkedInfo(root.nowDate.getTime(), root.checkedAtMs);
        var relative = (ci.key !== "" && ci.key !== "checked.date") ? t(ci.key, {n: ci.n}) : ci.text;
        checkedText = t("panel.checked") + "   " + relative;
        driftText = t("panel.drift");
    }
    function update() {
        var now = new Date();
        nowDate = now;
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

    // --- Policy-drift checker -------------------------------------------------
    function tryUrl(idx, urls) {
        if (idx >= urls.length)
            return;
        var xhr = new XMLHttpRequest();
        var settled = false;
        function fail() {
            if (!settled) {
                settled = true;
                tryUrl(idx + 1, urls);
            }
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || settled)
                return;
            if (xhr.status === 200) {
                settled = true;
                var m = xhr.responseText.match(/Peak hours are ([^<]+)/);
                if (m && !sameWindows(extractWindows(m[1]), extractWindows(scheduleText()))) {
                    drift = true;
                    ToastService.showNotice(t("notice.policyChanged"), m[1].trim());
                } else if (m) {
                    drift = false;
                }
                checkedAtMs = Date.now();
                refreshTexts();
            } else {
                fail();
            }
        };
        try {
            xhr.timeout = checkTimeoutMs;
        } catch (e) {}
        try {
            xhr.ontimeout = fail;
        } catch (e2) {}
        try {
            xhr.open("GET", urls[idx]);
            xhr.send();
        } catch (e3) {
            fail();
        }
    }
    function checkDrift() {
        if (!autoCheck || offlineOnly)
            return;
        var urls = [sourceUrl];
        for (var i = 0; i < fallbackUrls.length; i++) {
            if (urls.indexOf(fallbackUrls[i]) === -1)
                urls.push(fallbackUrls[i]);
        }
        tryUrl(0, urls);
    }

    Component.onCompleted: update()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.update()
    }
    // First check shortly after startup, then every checkIntervalH hours.
    Timer {
        interval: 30000
        running: true
        repeat: false
        onTriggered: root.checkDrift()
    }
    Timer {
        interval: Math.max(1, root.checkIntervalH) * 3600000
        running: root.autoCheck && !root.offlineOnly
        repeat: true
        onTriggered: root.checkDrift()
    }

    IpcHandler {
        target: "plugin:deepseek-peak"

        function refresh(): string {
            root.checkDrift();
            return "policy check triggered";
        }
        function status(): string {
            return (root.isPeak ? "peak" : "off-peak") + " · " + root.countdownHMS + (root.drift ? " · drift" : "");
        }
    }
}
