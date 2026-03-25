import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
    id: root
    property var pluginApi: null

    // ── Settings (reactive, with defaults) ───────────────
    property var cfg: pluginApi?.pluginSettings || ({})
    property var def: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property bool captureEnabled: cfg.captureEnabled ?? def.captureEnabled ?? true
    readonly property string evtestDevice: cfg.evtestDevice || def.evtestDevice || "/dev/input/event3"
    
    // Dynamic theme colors fallback if user does not supply custom
    property bool useCustomColors: cfg.useCustomColors ?? def.useCustomColors ?? false
    readonly property color  pillColor:    useCustomColors ? (cfg.pillColor || def.pillColor || Color.mPrimary) : Color.mPrimary
    readonly property color  pillBg:       useCustomColors ? (cfg.pillBg    || def.pillBg    || Color.mSurface) : Color.mSurface
    
    readonly property string position:     cfg.position    || def.position    || "bottom"
    readonly property int    marginPx:     cfg.marginPx    ?? def.marginPx    ?? 60
    readonly property int    hideDelaySec: cfg.hideDelaySec ?? def.hideDelaySec ?? 2

    // ── State ────────────────────────────────────────────
    property var  keyList: []
    property bool shiftHeld: false
    property bool ctrlHeld:  false
    property bool altHeld:   false
    property bool metaHeld:  false
    property bool capsLockOn: false
    property bool comboEmitted: false
    readonly property int maxKeys: 12

    // Arrays are not reactive by default, use var
    property var disabledScreens: cfg.disabledScreens || def.disabledScreens || []

    // Build modifier prefix from held state
    readonly property string modPrefix: {
        var p = "";
        if (metaHeld)  p += "󰴈 +";
        if (ctrlHeld)  p += "CTRL+";
        if (altHeld)   p += "ALT+";
        return p;
    }

    function emitDisplay(display) {
        var list = keyList.slice();
        if (list.length >= maxKeys) list = [];
        list.push(display);
        keyList = list;

        root.showOsd();
        hideTimer.restart();
    }

    // ── evtest process ───────────────────────────────────
    Process {
        id: evtest
        command: ["evtest", root.evtestDevice]
        running: root.captureEnabled

        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }

        onExited: (code, status) => {
            if (root.captureEnabled)
                Qt.callLater(() => evtest.running = true);
        }
    }

    // ── IPC handler (toggle via keybinding) ──────────────
    IpcHandler {
        target: "plugin:show-keys"

        function toggle(): void {
            root.captureEnabled = !root.captureEnabled;
            if (pluginApi) {
                pluginApi.pluginSettings.captureEnabled = root.captureEnabled;
                pluginApi.saveSettings();
            }
        }
    }

    // ── Event parsing ────────────────────────────────────
    function handleLine(line) {
        if (line.indexOf("type 1 (EV_KEY)") === -1) return;

        var m = line.match(/\(KEY_([^)]+)\).*value (\d+)/);
        if (!m) return;

        var keycode = m[1];
        var value   = parseInt(m[2]);
        if (value === 2) return;          // ignore repeat

        var isMod = false;
        var modName = "";
        if (/SHIFT$/.test(keycode))       { isMod = true; modName = "SHIFT"; }
        else if (/CTRL$/.test(keycode))   { isMod = true; modName = "CTRL"; }
        else if (/ALT$/.test(keycode))    { isMod = true; modName = "ALT"; }
        else if (/META$/.test(keycode))   { isMod = true; modName = "META"; }

        if (value === 1) { // Press
            if (keycode === "CAPSLOCK") capsLockOn = !capsLockOn;

            if (isMod) {
                if (modName === "SHIFT") shiftHeld = true;
                if (modName === "CTRL")  ctrlHeld  = true;
                if (modName === "ALT")   altHeld   = true;
                if (modName === "META")  metaHeld  = true;
                comboEmitted = false; 
            } else {
                comboEmitted = true;
            }
            return;
        }

        if (value === 0) { // Release
            if (isMod) {
                var emitStandalone = !comboEmitted;

                if (modName === "SHIFT") shiftHeld = false;
                if (modName === "CTRL")  ctrlHeld  = false;
                if (modName === "ALT")   altHeld   = false;
                if (modName === "META")  metaHeld  = false;

                if (emitStandalone) {
                    var mLabel = "";
                    if (modName === "SHIFT") mLabel = "SHIFT";
                    if (modName === "CTRL")  mLabel = "CTRL";
                    if (modName === "ALT")   mLabel = "ALT";
                    if (modName === "META")  mLabel = "󰴈";

                    var mDisplay = modPrefix + mLabel;
                    emitDisplay(mDisplay);
                    comboEmitted = true; 
                }
                return;
            }

            var label = keyLabel(keycode);
            if (label === "") return;

            // Compute currentPrefix (with or without SHIFT depending on whether it was consumed by keyLabel)
            var p = modPrefix;
            if (shiftHeld && !isShiftConsumed(keycode)) {
                 p += "SHIFT+";
            }

            var keyDisplay = p + label;
            emitDisplay(keyDisplay);
        }
    }

    // Helper to determine if SHIFT is naturally consumed by the symbol map
    function isShiftConsumed(k) {
        if (!shiftHeld) return false;
        // Digits and symbols in shiftMap consume it (e.g., producing "!" instead of "SHIFT+1")
        if (/^\d$/.test(k)) return true;
        if (shiftMap[k] !== undefined) return true;
        // If it's a letter, we explicitly do NOT consume shift, so it renders as SHIFT+A
        if (/^[A-Z]$/.test(k)) return false;
        
        return false;
    }

    // ── Key label (case-aware via CapsLock & ShiftMap) ───
    readonly property var shiftMap: ({
        "1":"!",  "2":"@",  "3":"#",  "4":"$",  "5":"%",
        "6":"^",  "7":"&",  "8":"*",  "9":"(",  "0":")",
        "MINUS":"_",       "EQUAL":"+",
        "LEFTBRACE":"{",   "RIGHTBRACE":"}",
        "SEMICOLON":":",   "APOSTROPHE":"\"",
        "GRAVE":"~",       "BACKSLASH":"|",
        "COMMA":"<",       "DOT":">",  "SLASH":"?"
    })
    readonly property var normalMap: ({
        "MINUS":"-",       "EQUAL":"=",
        "LEFTBRACE":"[",   "RIGHTBRACE":"]",
        "SEMICOLON":";",   "APOSTROPHE":"'",
        "GRAVE":"`",       "BACKSLASH":"\\",
        "COMMA":",",       "DOT":".",  "SLASH":"/"
    })

    readonly property var specialMap: ({
        "BACKSPACE":"󰁮",  "ENTER":"󰌑",   "ESC":"󱊷",
        "SPACE":"󱁐",      "TAB":"󰌒",     "DELETE":"󰆴",
        "UP":"↑",         "DOWN":"↓",    "LEFT":"←",   "RIGHT":"→",
        "HOME":"Home",    "END":"End",
        "PAGEUP":"PgUp",  "PAGEDOWN":"PgDn",
        "INSERT":"Ins",   "CAPSLOCK":"Caps",
        "NUMLOCK":"Num",  "SCROLLLOCK":"Scr",
        "SYSRQ":"PrtSc",  "PAUSE":"Pause"
    })

    function keyLabel(k) {
        // Special keys (icons, unaffected by shift/caps)
        if (specialMap[k] !== undefined) return specialMap[k];
        // F-keys
        if (/^F\d+$/.test(k)) return k;
        // KP keys
        if (k.indexOf("KP") === 0) return k;

        // Single alpha → evaluated by CapsLock state only (SHIFT is handled as a combo prefix)
        if (/^[A-Z]$/.test(k)) {
            return root.capsLockOn ? k : k.toLowerCase();
        }

        // Digit keys & symbols
        if (shiftHeld) {
            if (shiftMap[k] !== undefined) return shiftMap[k];
        }

        // Fallback to normal maps
        if (/^\d$/.test(k)) return k;
        if (normalMap[k] !== undefined) return normalMap[k];

        return k;
    }

    // ── Global Timers for OSD ────────────────────────────
    signal showOsd()
    signal hideOsd()

    Timer {
        id: hideTimer
        interval: root.hideDelaySec * 1000
        onTriggered: {
            root.hideOsd();
            clearTimer.start();
        }
    }

    Timer {
        id: clearTimer
        interval: 250
        onTriggered: {
            root.keyList = [];
        }
    }

    // ── Multi-Monitor OSD Windows ────────────────────────
    Variants {
        // Only instantiate windows for screens that are NOT disabled
        model: Quickshell.screens.filter(screen => root.disabledScreens.indexOf(screen.name) === -1)

        PanelWindow {
            id: osdWindow
            required property var modelData
            screen: modelData

            visible: false
            color: "transparent"

            anchors {
                top:    root.position === "top"
                bottom: root.position !== "top"
                left: true
                right: true
            }
            margins.top:    root.position === "top"  ? root.marginPx : 0
            margins.bottom: root.position !== "top"  ? root.marginPx : 0

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "show-keys-osd"
            implicitHeight: 52

            Connections {
                target: root
                function onShowOsd() {
                    osdWindow.visible = true;
                    osdContent.opacity = 1;
                }
                function onHideOsd() {
                    osdContent.opacity = 0;
                }
            }

            Item {
                id: osdContent
                anchors.fill: parent
                opacity: 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

                onOpacityChanged: {
                    // Automatically hide window when fully faded out
                    if (opacity === 0) {
                        osdWindow.visible = false;
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: root.keyList

                        Rectangle {
                            width: pillText.implicitWidth + 20
                            height: 36
                            radius: 8
                            color: Qt.alpha(root.pillBg, 0.8)
                            border.color: Qt.alpha(root.pillColor, 0.27)
                            border.width: 1

                            Text {
                                id: pillText
                                anchors.centerIn: parent
                                text: modelData
                                color: root.pillColor
                                font.pixelSize: 16
                                font.family: "monospace"
                                font.bold: true
                            }

                            scale: 0.7
                            Component.onCompleted: scale = 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                            }
                        }
                    }
                }
            }
        }
    }
}
