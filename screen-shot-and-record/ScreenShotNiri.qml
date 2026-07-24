import QtQuick
import Quickshell.Io
import qs.Commons

ScreenShot {
    id: root
    readonly property bool enableWindowsSelection: pluginApi?.pluginSettings?.enableWindowsSelection
                                                   ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableWindowsSelection
                                                   ?? true

    property list<var> windowRegions: []
    property var hoveredWindow: null
    property var winMap: ({})

    onEnableWindowsSelectionChanged: {
        if (!root.enableWindowsSelection) {
            root.windowRegions = []
            root.hoveredWindow = null
        }
    }

    onNonRecordingStart: () => {
        Logger.d("ScreenShot", "[Niri] onNonRecordingStart enableWindowsSelection=", root.enableWindowsSelection)
        if (root.enableWindowsSelection) {
            root.windowRegions = []
            niriWindowsProc.running = true
        }
    }

    onTargetChanged: {
        if (root.enableWindowsSelection && (root.target === "record" || root.target === "recordsound")) {
            root.windowRegions = []
            niriWindowsProc.running = true
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
        id: niriWindowsProc
        command: ["niri", "msg", "-j", "windows"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const windows = JSON.parse(text)
                    root.winMap = {}
                    for (const w of windows) {
                        root.winMap[String(w.id)] = w
                    }
                    niriGeomProc.running = true
                } catch (e) {
                    root.windowRegions = []
                    Logger.w("ScreenShot", "[Niri] windows parse error:", e)
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.windowRegions = []
                Logger.w("ScreenShot", "[Niri] niriWindowsProc failed")
            }
        }
    }

    Process {
        id: niriGeomProc
        command: ["niri", "msg", "-j", "window-geometries"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const geometries = JSON.parse(text)
                    root.windowRegions = root.computeRegions(geometries)
                    Logger.d("ScreenShot", "[RegionSelector][Niri] Found", root.windowRegions.length, "windows on", root.screen?.name)
                } catch (e) {
                    root.windowRegions = []
                    Logger.w("ScreenShot", "[Niri] geometries parse error:", e)
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.windowRegions = []
            }
        }
    }

    function computeRegions(geometries) {
        if (!Array.isArray(geometries)) {
            Logger.w("ScreenShot", "[Niri] computeRegions: geometries is not an array")
            return []
        }

        const focusedEntry = Object.entries(root.winMap).find(([id, w]) => w.is_focused === true)
        if (!focusedEntry) {
            Logger.d("ScreenShot", "[Niri] computeRegions: no focused window")
            return []
        }
        const activeWsId = Number(focusedEntry[1].workspace_id ?? 0)

        const outputName = String(root.screen?.name ?? "")
        const outputWidth = Number(root.screen?.width ?? 0)
        const outputHeight = Number(root.screen?.height ?? 0)


        const result = []
        for (const g of geometries) {
            const win = root.winMap[String(g.id)]
            if (!win) continue
            if (Number(win.workspace_id ?? 0) !== activeWsId) continue

            const l = win.layout
            const tileX = Number(g.x)
            const tileY = Number(g.y)
            const winOffX = Number(l.window_offset_in_tile[0] ?? 0)
            const winOffY = Number(l.window_offset_in_tile[1] ?? 0)
            const winW = Number(l.window_size[0] ?? 0)
            const winH = Number(l.window_size[1] ?? 0)

            if (winW <= 0 || winH <= 0) continue

            const visX = tileX + winOffX
            const visY = tileY + winOffY

            if (visX + winW < 0 || visX > outputWidth || visY + winH < 0 || visY > outputHeight) continue

            result.push({
                x: Math.round(visX) - root.monitorOffsetX,
                y: Math.round(visY) - root.monitorOffsetY,
                width: Math.round(winW),
                height: Math.round(winH),
                title: String(win.title ?? ""),
                cls: String(win.app_id ?? ""),
                address: String(g.id ?? ""),
                floating: win.is_floating === true
            })
        }

        result.sort((a, b) => Number(a.floating) - Number(b.floating))

        return result
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
