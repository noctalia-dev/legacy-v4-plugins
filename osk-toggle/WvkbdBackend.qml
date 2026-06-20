import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    property bool _visible: false
    // Inverted so BarWidget's direct mapping matches wvkbd-toggle's icon convention.
    readonly property bool keyboardActive: !_visible
    property bool wvkbdOk: false
    property bool available: wvkbdOk

    readonly property string unavailableTooltipKey: "tooltip.noWvkbd"
    readonly property string wvkbdBin: pluginApi?.pluginSettings?.wvkbdBin ?? "wvkbd-mobintl"
    readonly property list<string> wvkbdBinParts: wvkbdBin.trim().split(/\s+/)

    // True when wvkbd should be made visible as soon as it finishes starting up.
    // Used both at startup (restoring a pre-existing visible instance) and after
    // an unexpected exit (relaunch-then-show).
    property bool _pendingShow: false

    // True when wvkbd is being killed in order to relaunch under a new binary name.
    property bool _pendingRestart: false

    onWvkbdBinChanged: {
        if (!wvkbd.running) {
            availabilityChecker.running = true
            return
        }
        root._pendingShow = root._visible
        root._pendingRestart = true
        wvkbd.running = false
    }

    // --- 1. Availability: check binary exists on PATH ---
    Process {
        id: availabilityChecker
        command: ["which", root.wvkbdBinParts[0]]
        onExited: (exitCode, exitStatus) => {
            root.wvkbdOk = exitCode === 0
            if (root.wvkbdOk && !wvkbd.running) preemptChecker.running = true
        }
        Component.onCompleted: running = true
    }

    // --- 2. Detect any pre-existing wvkbd instance ---
    Process {
        id: preemptChecker
        command: ["pgrep", "-x", root.wvkbdBinParts[0]]
        onExited: (exitCode, exitStatus) => {
            root._pendingShow = exitCode === 0  // assume visible if already running
            if (exitCode === 0) {
                preemptKill.running = true
            } else {
                wvkbd.running = true
            }
        }
    }

    // --- 3. Kill pre-existing instance so we can take ownership ---
    Process {
        id: preemptKill
        command: ["pkill", "-x", root.wvkbdBinParts[0]]
        onExited: (exitCode, exitStatus) => {
            wvkbd.running = true
        }
    }

    // --- 4. Our owned wvkbd process — always running, starts hidden ---
    Process {
        id: wvkbd
        command: [...wvkbdBinParts, "--hidden"]
        onRunningChanged: {
            if (running && root._pendingShow) {
                root._pendingShow = false
                showTimer.restart()
            }
        }
        onExited: (exitCode, exitStatus) => {
            root._visible = false
            if (root._pendingRestart) {
                root._pendingRestart = false
                availabilityChecker.running = true
            }
        }
    }

    // --- Brief delay after launch before signalling (wvkbd needs to init) ---
    Timer {
        id: showTimer
        interval: 300
        onTriggered: {
            wvkbd.signal(10)  // SIGUSR1 = show
            root._visible = true
        }
    }

    Component.onDestruction: {
        if (wvkbd.running) wvkbd.running = false
    }

    function recheckState() {
        availabilityChecker.running = true
    }

    function toggleKeyboard() {
        if (!wvkbd.running) {
            root._pendingShow = true
            wvkbd.running = true
            return
        }
        if (root._visible) {
            wvkbd.signal(12)  // SIGUSR2 = hide
            root._visible = false
        } else {
            wvkbd.signal(10)  // SIGUSR1 = show
            root._visible = true
        }
    }
}
