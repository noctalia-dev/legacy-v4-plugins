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

    readonly property int mountedCount: {
        let c = 0
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].isMounted) c++
        }
        return c
    }

    // ===== SETTINGS SHORTCUTS =====

    readonly property bool autoMount:          pluginApi?.pluginSettings?.autoMount          ?? false
    readonly property string fileBrowser:      pluginApi?.pluginSettings?.fileBrowser        || "yazi"
    readonly property string terminalCommand:  pluginApi?.pluginSettings?.terminalCommand    || "kitty"
    readonly property bool showNotifications:  pluginApi?.pluginSettings?.showNotifications  ?? true
    readonly property bool hideWhenEmpty:      pluginApi?.pluginSettings?.hideWhenEmpty      ?? false

    // ===== INIT =====

    Component.onCompleted: {
        refreshDevices()
    }

    onDevicesChanged: {
      if(!root.autoMount) {
        return
      }

      for (let i = 0; i < devices.length; i++) {
            const dev = devices[i]

            if (!dev.isMounted && dev.autoMount && dev.fstype) {
                mountDevice(dev.path, dev.label)
            }
      }
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
                // Trigger refresh on USB add/remove events
                if (line.startsWith("ACTION=add") || line.startsWith("ACTION=remove")) {
                    refreshDebounce.restart()
                }
            }
        }

        onExited: exitCode => {
            // Restart watcher if it dies unexpectedly
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
        onTriggered: {
            refreshDevices()
        }
    }

    // ===== DEVICE ENUMERATION =====

    // lsblk -J gives us structured JSON with all block device info
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
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(String(stdout.text))
                    root.devices = internal.parseDevices(data.blockdevices || [])
                    root.devicesChanged()
                } catch (e) {
                    console.warn("[usb-drive-manager] Failed to parse lsblk output:", e)
                }
            }
        }
    }

    // ===== DISK USAGE =====

    // df gives us used/free space for mounted devices
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
            refreshDebounce.restart()
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
            refreshDebounce.restart()
        }
    }

    // ===== INTERNAL HELPERS =====

    QtObject {
        id: internal

        // Parse lsblk JSON output and extract USB partitions
        function parseDevices(blockdevices) {
            const result = []

            function processDevice(dev, parentPath, parentIsUsb) {
                const isUsb = parentIsUsb || dev.tran === "usb" || dev.hotplug === true || dev.hotplug === "1"
                const isRemovable = dev.rm === true || dev.rm === "1"

                // Process children (partitions) of USB devices
                if (dev.children && dev.children.length > 0) {
                    for (const child of dev.children) {
                        processDevice(child, dev.path || ("/dev/" + dev.name), isUsb)
                    }
                }

                // Only include partitions (or whole-disk if no partitions) with a filesystem
                const hasFs = dev.fstype && dev.fstype.length > 0
                const isPartition = parentPath !== null

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
                        freeSize:    "",
                        autoMount:   root.autoMount
                    })
                }
            }

            for (const dev of blockdevices) {
                processDevice(dev, null, false)
            }

            if(!root.autoMount) {
              return result
            }

            return result.map((dev) => Object.assign(dev, { 
              autoMount: root.devices.find(oldDev => oldDev.path === dev.path)?.autoMount ?? true
            }))
        }

        // Parse df output and update device usage stats
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

            // Update devices with usage info
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
        deviceQuery.running = false
        deviceQuery.running = true
        // Also refresh disk usage after a short delay
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
        if (mountProc.running) return
        mountProc.devicePath = devicePath
        mountProc.deviceLabel = deviceLabel
        mountProc.command = ["udisksctl", "mount", "-b", devicePath]
        mountProc.running = true
    }

    function unmountDevice(devicePath, deviceLabel) {
        if (unmountProc.running) return
        // prevent auto mount after manually unmount
        devices.find(dev => dev.path === devicePath).autoMount = false

        unmountProc.devicePath = devicePath
        unmountProc.deviceLabel = deviceLabel
        unmountProc.command = ["udisksctl", "unmount", "-b", devicePath]
        unmountProc.running = true

    }

    function ejectDevice(devicePath, parentPath, deviceLabel) {
        // First unmount the partition, then power off the parent disk
        const target = parentPath || devicePath
        if (ejectProc.running) return
        ejectProc.devicePath = target
        ejectProc.deviceLabel = deviceLabel
        ejectProc.command = [
            "sh", "-c",
            "udisksctl unmount -b " + devicePath + " 2>/dev/null; udisksctl power-off -b " + target
        ]
        ejectProc.running = true
    }

    function openInFileBrowser(mountpoint) {
        const browser = root.fileBrowser || "yazi"
        if (browser === "yazi" || browser === "ranger" || browser === "lf" || browser === "nnn") {
            // Terminal file managers need a terminal emulator
            const term = root.terminalCommand || "kitty"
            const termLower = term.toLowerCase()
            // Ptyxis, GNOME Terminal, and WezTerm prefer `--` instead of `-e`
            const flag = (termLower.indexOf("ptyxis") !== -1
                       || termLower.indexOf("gnome-terminal") !== -1
                       || termLower.indexOf("wezterm") !== -1) ? "--" : "-e"
            Quickshell.execDetached([term, flag, browser, mountpoint])
        } else {
            Quickshell.execDetached([browser, mountpoint])
        }
    }

    function unmountAll() {
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i]
            // prevent auto mount after manually unmount
            dev.autoMount = false

            if (dev.isMounted) {
                Quickshell.execDetached(["udisksctl", "unmount", "-b", dev.path])
            }
        }
        if (root.showNotifications) {
            ToastService.showNotice(
                pluginApi?.tr("notifications.unmount-all")
            )
        }
        refreshDebounce.restart()
    }

    function ejectAll() {
        const ejected = []
        for (let i = 0; i < devices.length; i++) {
            const dev = devices[i]
            const parent = dev.parentPath || dev.path
            if (!ejected.includes(parent)) {
                ejected.push(parent)
                Quickshell.execDetached([
                    "sh", "-c",
                    "udisksctl unmount -b " + dev.path + " 2>/dev/null; udisksctl power-off -b " + parent
                ])
            }
        }
        if (root.showNotifications) {
            ToastService.showNotice(
                pluginApi?.tr("notifications.eject-all")
            )
        }
        refreshDebounce.restart()
    }

    function buildTooltip() {
        if (mountedCount === 0) {
            return pluginApi?.tr("bar.tooltip-empty")
        }
        return pluginApi?.tr("bar.tooltip-count")?.replace("%1", mountedCount)
    }
}
