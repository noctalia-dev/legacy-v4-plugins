import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons

ScreenShot {
    id: root
    readonly property bool enableWindowsSelection: pluginApi?.pluginSettings?.enableWindowsSelection
                                                   ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableWindowsSelection
                                                   ?? true

    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(root.screen)
    readonly property int activeWorkspaceId: hyprlandMonitor?.activeWorkspace?.id ?? 0

    property list<var> windowRegions: []
    property var hoveredWindow: null

    onEnableWindowsSelectionChanged: {
        if (!root.enableWindowsSelection) {
            root.windowRegions = []
            root.hoveredWindow = null
        }
    }

    onNonRecordingStart: () => {
        if (root.enableWindowsSelection) {
            hyprctlProc.running = true
        }
    }

    onTargetChanged: {
        if (root.enableWindowsSelection && (root.target === "record" || root.target === "recordsound")) {
            hyprctlProc.running = true
        }
    }

    resolveFallbackRegion: () => {
        if (!root.hoveredWindow) {
            return null
        }

        return {
            x: root.hoveredWindow.x,
            y: root.hoveredWindow.y,
            width: root.hoveredWindow.width,
            height: root.hoveredWindow.height
        }
    }

    Process {
        id: hyprctlProc
        command: ["hyprctl", "-j", "clients"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const clients = JSON.parse(text)
                    root.windowRegions = root.extractHyprWindowRegions(clients)
                    Logger.d("ScreenShot", "[RegionSelector][Hyprland] Found", root.windowRegions.length, "windows on", root.screen?.name)
                } catch (e) {
                    root.windowRegions = []
                    Logger.w("ScreenShot", "[RegionSelector][Hyprland] hyprctl parse error:", e)
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.windowRegions = []
            }
        }
    }

    function extractHyprWindowRegions(clients) {
        if (!Array.isArray(clients)) {
            return []
        }

        const outputName = String(root.screen?.name ?? "")
        const outputNameLower = outputName.toLowerCase()
        const workspaceId = Number(root.activeWorkspaceId)
        const monitorId = Number(root.hyprlandMonitor?.id ?? NaN)

        return clients
            .filter(client => {
                const isMapped = client?.mapped !== false
                const isHidden = client?.hidden === true
                const rawMonitor = client?.monitor
                const monitorName = String(client?.monitorName ?? "").toLowerCase()
                const monitorFromField = String(rawMonitor ?? "").toLowerCase()
                const clientMonitorId = Number(client?.monitorID ?? rawMonitor ?? NaN)

                // Hyprland JSON differs across versions: monitor may be a name,
                // numeric ID, or monitorName/monitorID may be provided.
                const onOutput = outputName === ""
                              || monitorName === outputNameLower
                              || monitorFromField === outputNameLower
                              || (!Number.isNaN(monitorId) && clientMonitorId === monitorId)

                if (workspaceId > 0) {
                    return isMapped && !isHidden && onOutput && Number(client?.workspace?.id ?? 0) === workspaceId
                }

                return isMapped && !isHidden && onOutput
            })
            .map(client => ({
                x: Number(client?.at?.[0] ?? 0) - root.monitorOffsetX,
                y: Number(client?.at?.[1] ?? 0) - root.monitorOffsetY,
                width: Number(client?.size?.[0] ?? 0),
                height: Number(client?.size?.[1] ?? 0),
                title: String(client?.title ?? ""),
                cls: String(client?.class ?? ""),
                address: String(client?.address ?? "")
            }))
            .filter(window => window.width > 0 && window.height > 0)
    }

    function findWindowAt(x, y) {
        for (let i = root.windowRegions.length - 1; i >= 0; i--) {
            const w = root.windowRegions[i]
            if (x >= w.x && x <= w.x + w.width && y >= w.y && y <= w.y + w.height) {
                return w
            }
        }

        return null
    }
}
