import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen: null
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var cfg:      pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // ── Per-screen bar properties ─────────────────────────────────────────────
    readonly property string screenName:    screen?.name ?? ""
    readonly property string barPosition:   Settings.getBarPositionForScreen(screenName)
    readonly property bool   isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real   capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real   barFontSize:   Style.getBarFontSizeForScreen(screenName)
    readonly property string fixedFont:     Settings.data?.ui?.fontFixed ?? "monospace"
    readonly property bool   compact:       cfg.compactMode ?? defaults.compactMode ?? false

    // ── State ─────────────────────────────────────────────────────────────────
    property string governor:      "—"
    property string turboState:    "—"
    property bool   daemonRunning: false
    property string forceOverride: "default"
    property string turboOverride: "auto"   // "never" | "always" | "auto"
    property bool   pkexecFailed:  false

    // Battery state (sysfs — more reliable than UPower on this system)
    property int    batCapacity:   -1       // -1 = no battery
    property string batStatus:     ""       // Charging / Discharging / Full
    property real   batWatts:      0.0
    property string batDevice:     ""       // BAT0, BAT1, etc.

    readonly property color govColor: {
        if (governor === "performance") return Color.mTertiary
        if (governor === "powersave")   return Color.mPrimary
        return Color.mOnSurface
    }

    // ── Widget dimensions ─────────────────────────────────────────────────────
    readonly property real contentWidth: compact
        ? capsuleHeight
        : (content.implicitWidth + Style.marginM * 2)
    readonly property real contentHeight: capsuleHeight

    implicitWidth:  contentWidth
    implicitHeight: contentHeight

    Component.onCompleted: {
        if (pluginApi) pluginApi.mainInstance = root
    }

    // ── Sysfs: governor ───────────────────────────────────────────────────────
    FileView {
        id: governorFile
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        printErrors: false
        onLoaded: root.governor = text().trim() || "—"
    }

    FileView {
        id: noTurboFile
        path: "/sys/devices/system/cpu/intel_pstate/no_turbo"
        printErrors: false
        onLoaded: {
            let v = text().trim()
            if (v !== "") root.turboState = (v === "0") ? "on" : "off"
        }
    }

    FileView {
        id: boostFile
        path: "/sys/devices/system/cpu/cpufreq/boost"
        printErrors: false
        onLoaded: {
            if (noTurboFile.text().trim() !== "") return
            let v = text().trim()
            if (v !== "") root.turboState = (v === "1") ? "on" : "off"
        }
    }

    // ── Battery — sysfs ──────────────────────────────────────────────────────
    Process {
        id: batFinder
        command: ["sh", "-c", "for d in /sys/class/power_supply/*/type; do [ \"$(cat $d 2>/dev/null)\" = 'Battery' ] && basename $(dirname $d) && exit 0; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let dev = text.trim()
                if (dev !== "") { root.batDevice = dev; batUevent.reload() }
            }
        }
    }

    FileView {
        id: batUevent
        path: root.batDevice !== "" ? "/sys/class/power_supply/" + root.batDevice + "/uevent" : "/dev/null"
        printErrors: false
        onLoaded: {
            let cap = -1, status = "", currentUa = 0, voltageUv = 0
            for (let line of text().split("\n")) {
                if (line.startsWith("POWER_SUPPLY_CAPACITY="))   cap = parseInt(line.split("=")[1]) || -1
                else if (line.startsWith("POWER_SUPPLY_STATUS=")) status = line.split("=")[1]?.trim() ?? ""
                else if (line.startsWith("POWER_SUPPLY_CURRENT_NOW=")) currentUa = parseInt(line.split("=")[1]) || 0
                else if (line.startsWith("POWER_SUPPLY_VOLTAGE_NOW=")) voltageUv = parseInt(line.split("=")[1]) || 0
            }
            root.batCapacity = cap
            root.batStatus   = status
            root.batWatts    = (voltageUv > 0 && currentUa > 0)
                ? Math.round((voltageUv / 1e6) * (currentUa / 1e6) * 10) / 10
                : 0.0
        }
    }

    // ── Override state — read pickle files ───────────────────────────────────
    // Pickle is binary but contains the string value — grep works fine
    Process {
        id: overrideReader
        // Try common paths: NixOS uses /run/, classic installs use /opt/auto-cpufreq/
        command: ["sh", "-c",
            "for f in /run/override.pickle /opt/auto-cpufreq/override.pickle; do " +
            "  [ -f \"$f\" ] && strings \"$f\" | grep -oE '(powersave|performance)' | head -1 && exit 0; " +
            "done; echo 'default'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let v = text.trim()
                if (v === "powersave" || v === "performance") root.forceOverride = v
                else root.forceOverride = "default"
            }
        }
    }

    Process {
        id: turboOverrideReader
        command: ["sh", "-c",
            "for f in /run/turbo-override.pickle /opt/auto-cpufreq/turbo-override.pickle; do " +
            "  [ -f \"$f\" ] && strings \"$f\" | grep -oE '(never|always)' | head -1 && exit 0; " +
            "done; echo 'auto'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let v = text.trim()
                root.turboOverride = (v === "never" || v === "always") ? v : "auto"
            }
        }
    }

    // ── Daemon check ──────────────────────────────────────────────────────────
    Process {
        id: daemonChecker
        command: ["systemctl", "is-active", "--quiet", "auto-cpufreq"]
        running: false
        onExited: (code) => { root.daemonRunning = (code === 0) }
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    Process {
        id: forceProc
        running: false
        onExited: (code) => {
            if (code === 0) { root.pkexecFailed = false; root.refreshAll() }
            else if (code === 126 || code === 127) root.pkexecFailed = true
        }
    }

    Process {
        id: turboProc
        running: false
        onExited: (code) => {
            if (code === 0) { root.pkexecFailed = false; root.refreshAll() }
            else if (code === 126 || code === 127) root.pkexecFailed = true
        }
    }

    function setForce(mode) {
        forceProc.command = ["pkexec", "auto-cpufreq", "--force=" + mode]
        forceProc.running = false
        forceProc.running = true
        // don't set locally — refreshAll() will read real state from pickle
    }

    function setTurbo(mode) {
        turboProc.command = ["pkexec", "auto-cpufreq", "--turbo=" + mode]
        turboProc.running = false
        turboProc.running = true
    }

    function refreshAll() {
        governorFile.reload()
        noTurboFile.reload()
        boostFile.reload()
        daemonChecker.running = false
        daemonChecker.running = true
        overrideReader.running = false
        overrideReader.running = true
        turboOverrideReader.running = false
        turboOverrideReader.running = true
        if (root.batDevice === "") { batFinder.running = false; batFinder.running = true }
        else batUevent.reload()
    }

    // ── Poll timer ────────────────────────────────────────────────────────────
    Timer {
        interval: root.cfg.refreshInterval ?? root.defaults.refreshInterval ?? 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAll()
    }

    // ── Visual capsule (correct noctalia pattern) ─────────────────────────────
    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width:  root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color:  mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: Style.marginS

            NIcon {
                icon: "cpu"
                color: mouseArea.containsMouse ? Color.mOnHover : root.govColor
                pointSize: Style.fontSizeM
                applyUiScale: false
            }

            ColumnLayout {
                visible: !root.compact
                spacing: 1
                Layout.rightMargin: Style.marginS

                NText {
                    text: root.governor
                    pointSize: root.barFontSize
                    font.family: root.fixedFont
                    font.weight: Font.Bold
                    color: mouseArea.containsMouse ? Color.mOnHover : root.govColor
                }

                NText {
                    visible: root.turboState !== "—"
                    text: "turbo: " + root.turboState
                    pointSize: root.barFontSize * 0.85
                    color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
                }
            }
        }
    }

    // ── Context menu ──────────────────────────────────────────────────────────
    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.force-performance"),  "action": "force-performance", "icon": "gauge",    "enabled": root.daemonRunning },
            { "label": pluginApi?.tr("menu.force-powersave"),    "action": "force-powersave",   "icon": "leaf",     "enabled": root.daemonRunning },
            { "label": pluginApi?.tr("menu.force-reset"),        "action": "force-reset",        "icon": "refresh",  "enabled": root.forceOverride !== "default" },
            { "label": pluginApi?.tr("menu.turbo-on"),           "action": "turbo-on",           "icon": "bolt",     "enabled": root.daemonRunning },
            { "label": pluginApi?.tr("menu.turbo-off"),          "action": "turbo-off",          "icon": "bolt",     "enabled": root.daemonRunning },
            { "label": pluginApi?.tr("menu.turbo-auto"),         "action": "turbo-auto",         "icon": "cpu",      "enabled": root.daemonRunning },
            { "label": pluginApi?.tr("actions.widget-settings"), "action": "widget-settings",    "icon": "settings" }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)
            if      (action === "widget-settings")   BarService.openPluginSettings(screen, pluginApi.manifest)
            else if (action === "force-performance") root.setForce("performance")
            else if (action === "force-powersave")   root.setForce("powersave")
            else if (action === "force-reset")       root.setForce("reset")
            else if (action === "turbo-on")          root.setTurbo("always")
            else if (action === "turbo-off")         root.setTurbo("never")
            else if (action === "turbo-auto")        root.setTurbo("auto")
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                pluginApi?.togglePanel(root.screen, root)
            else
                PanelService.showContextMenu(contextMenu, root, screen)
        }
        onEntered: TooltipService.show(root, root.governor + " · turbo: " + root.turboState, BarService.getTooltipDirection())
        onExited:  TooltipService.hide()
    }
}
