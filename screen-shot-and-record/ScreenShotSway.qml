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

    onEnableWindowsSelectionChanged: {
        if (!root.enableWindowsSelection) {
            root.windowRegions = []
            root.hoveredWindow = null
        }
    }

    onNonRecordingStart: () => {
        if (root.enableWindowsSelection) {
            swayTreeProc.running = true
        }
    }
    onTargetChanged: {
        if (root.enableWindowsSelection && (root.target === "record" || root.target === "recordsound")) {
            swayTreeProc.running = true
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
        id: swayTreeProc
        command: ["swaymsg", "-t", "get_tree", "-r"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const tree = JSON.parse(text)
                    root.windowRegions = root.extractSwayWindowRegions(tree)
                    Logger.d("ScreenShot", "[RegionSelector][Sway] Found", root.windowRegions.length, "windows on", root.screen?.name)
                } catch (e) {
                    root.windowRegions = []
                    Logger.w("ScreenShot", "[RegionSelector][Sway] get_tree parse error:", e)
                }
            }
        }
        onExited: (code) => {
            Logger.d("ScreenShot", "[Sway] swayTreeProc onExited code=", code)
            if (code !== 0) {
                root.windowRegions = []
                Logger.w("ScreenShot", "[Sway] swayTreeProc failed, cleared windowRegions")
            }
        }
    }


    function extractSwayWindowRegions(tree) {
        const outputName = String(root.screen?.name ?? "")

        if (outputName === "") {
            Logger.w("ScreenShot", "[Sway] extractSwayWindowRegions: empty outputName")
            return []
        }

        const outputs = (tree?.nodes ?? []).filter(node => node?.type === "output" && String(node?.name ?? "") === outputName)

        if (outputs.length === 0) {
            Logger.w("ScreenShot", "[Sway] extractSwayWindowRegions: no matching outputs")
            return []
        }

        const result = []
        for (let i = 0; i < outputs.length; i++) {
            const output = outputs[i]
            const workspaces = (output?.nodes ?? []).filter(node => node?.type === "workspace")

            let selectedWorkspaces = workspaces.filter(ws => ws?.focused === true)
            if (selectedWorkspaces.length === 0) {
                selectedWorkspaces = workspaces.filter(ws => ws?.visible === true)
            }
            if (selectedWorkspaces.length === 0) {
                selectedWorkspaces = workspaces
            }


            for (let j = 0; j < selectedWorkspaces.length; j++) {
                root.collectWorkspaceWindows(selectedWorkspaces[j], result)
            }
        }

        return result
    }

    function collectWorkspaceWindows(workspaceNode, result) {
        const stack = [workspaceNode]
        const seenWindowKeys = ({})
        let processedCount = 0
        while (stack.length > 0) {
            const node = stack.pop()
            if (!node) {
                continue
            }

            const nodes = node.nodes ?? []
            const floatingNodes = node.floating_nodes ?? []
            for (let i = 0; i < floatingNodes.length; i++) {
                stack.push(floatingNodes[i])
            }
            for (let i = 0; i < nodes.length; i++) {
                stack.push(nodes[i])
            }

            const isCon = node.type === "con"
            const isFloatingCon = node.type === "floating_con"
            const isLeaf = nodes.length === 0 && floatingNodes.length === 0
            const rect = node.rect
            const hasRect = rect && Number(rect.width) > 0 && Number(rect.height) > 0
            const hasWindowMeta = node.app_id || node.window || node.window_properties
            const isSelectableWindowNode = (isCon || isFloatingCon) && isLeaf && hasWindowMeta

            if (!isSelectableWindowNode || !hasRect) {
                continue
            }

            processedCount++

            const windowTitle = String(node.name ?? "")
            const windowClass = String(node.app_id ?? node.window_properties?.class ?? "")
            const windowAddress = String(node.id ?? "")
            const dedupeKey = windowAddress !== ""
                              ? windowAddress
                              : [Number(rect.x), Number(rect.y), Number(rect.width), Number(rect.height), windowTitle, windowClass].join("|")
            if (seenWindowKeys[dedupeKey]) {
                continue
            }
            seenWindowKeys[dedupeKey] = true

            result.push({
                x: Number(rect.x) - root.monitorOffsetX,
                y: Number(rect.y) - root.monitorOffsetY,
                width: Number(rect.width),
                height: Number(rect.height),
                title: windowTitle,
                cls: windowClass,
                address: windowAddress
            })
        }
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
