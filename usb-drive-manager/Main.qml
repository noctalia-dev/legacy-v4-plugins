import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var devices: []
    property bool loading: false
    property bool autoMountPending: false
    property var previousDevicePaths: []
    property var mountQueue: []
    property var ejectQueue: []

    readonly property int mountedCount: {
        let c = 0
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].isMounted)
                c++
        }
        return c
    }

    // ===== SETTINGS SHORTCUTS =====

    readonly property bool autoMount:          pluginApi?.pluginSettings?.autoMount          ?? false
    readonly property string fileBrowser:      pluginApi?.pluginSettings?.fileBrowser        || "yazi"
    readonly property string terminalCommand:  pluginApi?.pluginSettings?.terminalCommand    || "kitty"
    readonly property bool showNotifications:  pluginApi?.pluginSettings?.showNotifications  ?? true
    readonly property bool hideWhenEmpty:      pluginApi?.pluginSettings?.hideWhenEmpty      ?? false
    readonly property string iconName:         pluginApi?.pluginSettings?.iconName            || pluginApi?.manifest?.metadata?.defaultSettings?.iconName || "usb"

    // ===== INIT =====

    Component.onCompleted: {
        refreshDevices()
    }

    // ===== IPC =====

    IpcHandler {
        target: "plugin:usb-drive-manager"

        function refresh() {
            root.refreshDevices()
        }

        function unmountAll() {
            root.unmountAll()
        }
    }

    // ===== DEVICE MONITORING =====

    // udevadm monitor watches for block device add/remove events
    Process {
        id: deviceWatcher
        command: ["udevadm", "monitor", "--subsystem-match=block", "--property"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("ACTION=add")) {
                    root.autoMountPending = root.autoMount
                    refreshDebounce.restart()
                } else if (line.startsWith("ACTION=remove")) {
                    root.autoMountPending = false
                    refreshDebounce.restart()
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                restartWatcherTimer.start()
            }
        }
    }

    Timer {
        id: restartWatcherTimer
        interval: 3000
        repeat: false
        onTriggered: deviceWatcher.running = true
    }

    // Debounce rapid udev events (e.g. partition table re-read)
    Timer {
        id: refreshDebounce
        interval: 800
        repeat: false
        onTriggered: refreshDevices()
    }

    // ===== DEVICE ENUMERATION =====

    Process {
        id: deviceQuery
        command: [
            "lsblk", "-J",
            "-o", "NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,HOTPLUG,TRAN,MODEL,VENDOR,RM,PATH,PKNAME"
        ]
        running: false

        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            root.loading = false

            const shouldAutoMount = root.autoMountPending && root.autoMount
            root.autoMountPending = false

            if (exitCode === 0) {
                try {
                    const data = JSON.parse(String(stdout.text))
                    const nextDevices = internal.parseDevices(data.blockdevices || [])
                    const previousPaths = root.previousDevicePaths || []

                    root.devices = nextDevices
                    root.devicesChanged()

                    if (shouldAutoMount) {
                        const mountCandidates = internal.getAutoMountCandidates(previousPaths, nextDevices)
                        if (mountCandidates.length > 0) {
                            Qt.callLater(() => root.queueMountDevices(mountCandidates))
                        }
                    }
                } catch (e) {
                    console.warn("[usb-drive-manager] Failed to parse lsblk output:", e)
                }
            }
        }
    }

    // ===== DISK USAGE =====

    Process {
        id: dfQuery
        command: ["df", "--output=target,pcent,used,avail", "-h"]
        running: false

        stdout: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                internal.parseDfOutput(String(stdout.text))
            }
        }
    }

    // ===== ACTION PROCESSES =====

    Process {
        id: mountProc
        property string devicePath: ""
        property string deviceLabel: ""
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.showNotifications) {
                    ToastService.showNotice(
                        pluginApi?.tr("notifications.mounted"),
                        mountProc.deviceLabel || mountProc.devicePath
                    )
                }
            } else {
                const errMsg = String(stderr.text).trim()
                ToastService.showError(
                    pluginApi?.tr("notifications.mount-failed"),
                    errMsg || mountProc.devicePath
                )
            }

            root.autoMountPending = false
            refreshDebounce.restart()
            root.processNextMount()
        }
    }

    Process {
        id: unmountProc
        property string devicePath: ""
        property string deviceLabel: ""
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.showNotifications) {
                    ToastService.showNotice(
                        pluginApi?.tr("notifications.unmounted"),
                        unmountProc.deviceLabel || unmountProc.devicePath
                    )
                }
            } else {
                const errMsg = String(stderr.text).trim()
                ToastService.showError(
                    pluginApi?.tr("notifications.unmount-failed"),
                    errMsg || unmountProc.devicePath
                )
            }

            root.autoMountPending = false
            refreshDebounce.restart()
        }
    }

    Process {
        id: ejectProc
        property string devicePath: ""
        property string deviceLabel: ""
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                if (root.showNotifications) {
                    ToastService.showNotice(
                        pluginApi?.tr("notifications.ejected"),
                        ejectProc.deviceLabel || ejectProc.devicePath
                    )
                }
            } else {
                const errMsg = String(stderr.text).trim()
                ToastService.showError(
                    pluginApi?.tr("notifications.eject-failed"),
                    errMsg || ejectProc.devicePath
                )
            }

            root.autoMountPending = false
            refreshDebounce.restart()
            root.processNextEject()
        }
    }

    // ===== INTERNAL HELPERS =====

    QtObject {
        id: internal

        function parseDevices(blockdevices) {
            const result = []

            function processDevice(dev, parentPath, parentIsUsb) {
                const isUsb = parentIsUsb || dev.tran === "usb" || dev.hotplug === true || dev.hotplug === "1"
                const isRemovable = dev.rm === true || dev.rm === "1"

                if (dev.children && dev.children.length > 0) {
                    for (const child of dev.children) {
                        processDevice(child, dev.path || ("/dev/" + dev.name), isUsb)
                    }
                }

                const hasFs = dev.fstype && dev.fstype.length > 0

                if ((isUsb || isRemovable) && hasFs) {
                    const mountpoint = dev.mountpoint || ""
                    result.push({
                        name:        dev.name || "",
                        path:        dev.path || ("/dev/" + dev.name),
                        parentPath:  parentPath || dev.path || ("/dev/" + dev.name),
                        label:       dev.label || dev.name || "",
                        size:        dev.size || "",
                        fstype:      dev.fstype || "",
                        mountpoint:  mountpoint,
                        isMounted:   mountpoint.length > 0,
                        model:       dev.model || "",
                        vendor:      dev.vendor ? dev.vendor.trim() : "",
                        usedPercent: 0,
                        usedSize:    "",
                        freeSize:    ""
                    })
                }
            }

            for (const dev of blockdevices) {
                processDevice(dev, null, false)
            }

            return result
        }

        function collectDevicePaths(deviceList) {
            const paths = []

            for (let i = 0; i < deviceList.length; i++) {
                const dev = deviceList[i]
                if (!dev || !dev.path)
                    continue
                paths.push(dev.path)
            }

            return paths
        }

        function getAutoMountCandidates(previousPaths, nextDevices) {
            const previous = previousPaths || []
            const candidates = []

            for (let i = 0; i < nextDevices.length; i++) {
                const dev = nextDevices[i]
                if (!dev || !dev.path || !dev.fstype || dev.isMounted)
                    continue
                if (previous.indexOf(dev.path) !== -1)
                    continue

                candidates.push({
                    path: dev.path,
                    label: dev.label || dev.name || dev.path
                })
            }

            return candidates
        }

        function getMountedPathsForTarget(targetPath) {
            const mounted = []

            for (let i = 0; i < root.devices.length; i++) {
                const dev = root.devices[i]
                if (!dev || !dev.isMounted || !dev.path)
                    continue

                const parent = dev.parentPath || dev.path
                if (dev.path === targetPath || parent === targetPath) {
                    mounted.push(dev.path)
                }
            }

            return mounted
        }

        function shellQuote(text) {
            return "'" + String(text || "").replace(/'/g, "'\\''") + "'"
        }

        function buildEjectCommand(targetPath, mountedPaths) {
            const steps = ["set -e"]

            for (let i = 0; i < mountedPaths.length; i++) {
                steps.push("udisksctl unmount -b " + shellQuote(mountedPaths[i]))
            }

            steps.push("udisksctl power-off -b " + shellQuote(targetPath))
            return steps.join("\n")
        }

        function parseDfOutput(text) {
            const lines = text.split("\n")
            const usageMap = {}

            for (let i = 1; i < lines.length; i++) {
                const parts = lines[i].trim().split(/\s+/)
                if (parts.length >= 4) {
                    const mountpoint = parts[0]
                    const pcent = parseInt(parts[1]) || 0
                    const used = parts[2] || ""
                    const avail = parts[3] || ""
                    usageMap[mountpoint] = { pcent, used, avail }
                }
            }

            const updated = root.devices.map(dev => {
                if (dev.isMounted && usageMap[dev.mountpoint]) {
                    const u = usageMap[dev.mountpoint]
                    return Object.assign({}, dev, {
                        usedPercent: u.pcent,
                        usedSize:    u.used,
                        freeSize:    u.avail
                    })
                }
                return dev
            })

            root.devices = updated
            root.devicesChanged()
        }
    }

    // ===== PUBLIC API =====

    function refreshDevices() {
        root.loading = true
        root.previousDevicePaths = internal.collectDevicePaths(root.devices)
        deviceQuery.running = false
        deviceQuery.running = true
        dfTimer.restart()
    }

    Timer {
        id: dfTimer
        interval: 1200
        repeat: false
        onTriggered: {
            dfQuery.running = false
            dfQuery.running = true
        }
    }

    function mountDevice(devicePath, deviceLabel) {
        queueMountDevices([{
            path: devicePath,
            label: deviceLabel
        }])
    }

    function queueMountDevices(devicesToMount) {
        if (!devicesToMount || devicesToMount.length === 0)
            return

        const queue = root.mountQueue.slice()

        for (let i = 0; i < devicesToMount.length; i++) {
            const dev = devicesToMount[i]
            if (!dev || !dev.path)
                continue

            let alreadyQueued = false
            for (let j = 0; j < queue.length; j++) {
                if (queue[j].path === dev.path) {
                    alreadyQueued = true
                    break
                }
            }

            const alreadyRunning = mountProc.running && mountProc.devicePath === dev.path
            if (!alreadyQueued && !alreadyRunning) {
                queue.push({
                    path: dev.path,
                    label: dev.label || dev.path
                })
            }
        }

        root.mountQueue = queue
        processNextMount()
    }

    function processNextMount() {
        if (mountProc.running || root.mountQueue.length === 0)
            return

        const queue = root.mountQueue.slice()
        const next = queue.shift()
        root.mountQueue = queue

        if (!next || !next.path) {
            processNextMount()
            return
        }

        mountProc.devicePath = next.path
        mountProc.deviceLabel = next.label || next.path
        mountProc.command = ["udisksctl", "mount", "-b", next.path]
        mountProc.running = true
    }

    function unmountDevice(devicePath, deviceLabel) {
        if (unmountProc.running)
            return

        unmountProc.devicePath = devicePath
        unmountProc.deviceLabel = deviceLabel
        unmountProc.command = ["udisksctl", "unmount", "-b", devicePath]
        unmountProc.running = true
    }

    function ejectDevice(devicePath, parentPath, deviceLabel) {
        const target = parentPath || devicePath
        const queue = root.ejectQueue.slice()

        let alreadyQueued = false
        for (let i = 0; i < queue.length; i++) {
            if (queue[i].target === target) {
                alreadyQueued = true
                break
            }
        }

        const alreadyRunning = ejectProc.running && ejectProc.devicePath === target
        if (alreadyQueued || alreadyRunning)
            return

        queue.push({
            target: target,
            label: deviceLabel || target
        })
        root.ejectQueue = queue
        processNextEject()
    }

    function processNextEject() {
        if (ejectProc.running || root.ejectQueue.length === 0)
            return

        const queue = root.ejectQueue.slice()
        const next = queue.shift()
        root.ejectQueue = queue

        if (!next || !next.target) {
            processNextEject()
            return
        }

        const mountedPaths = internal.getMountedPathsForTarget(next.target)

        ejectProc.devicePath = next.target
        ejectProc.deviceLabel = next.label || next.target
        ejectProc.command = [
            "sh", "-c",
            internal.buildEjectCommand(next.target, mountedPaths)
        ]
        ejectProc.running = true
    }

    function openInFileBrowser(mountpoint) {
        const browser = root.fileBrowser || "yazi"
        if (browser === "yazi" || browser === "ranger" || browser === "lf" || browser === "nnn") {
            const term = root.terminalCommand || "kitty"
            Quickshell.execDetached([term, "-e", browser, mountpoint])
        } else {
            Quickshell.execDetached([browser, mountpoint])
        }
    }

    function unmountAll() {
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i]
            if (dev.isMounted) {
                Quickshell.execDetached(["udisksctl", "unmount", "-b", dev.path])
            }
        }

        if (root.showNotifications) {
            ToastService.showNotice(
                pluginApi?.tr("notifications.unmount-all")
            )
        }

        root.autoMountPending = false
        refreshDebounce.restart()
    }

    function ejectAll() {
        const targets = []

        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i]
            if (!dev)
                continue

            const parent = dev.parentPath || dev.path
            if (targets.indexOf(parent) !== -1)
                continue

            targets.push(parent)
            ejectDevice(dev.path, parent, dev.label || dev.name || parent)
        }
    }

    function buildTooltip() {
        if (mountedCount === 0) {
            return pluginApi?.tr("bar.tooltip-empty")
        }
        return pluginApi?.tr("bar.tooltip-count")?.replace("%1", mountedCount)
    }
}
