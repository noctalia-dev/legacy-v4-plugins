import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Widgets
import QtQuick.Layouts
import qs.Services.Compositor

PanelWindow {
    id: root
    property var pluginApi: null
    visible: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "noctalia-shell:regionSelector"
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    property var target: ""
    property bool enableCross: pluginApi?.pluginSettings?.enableCross
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableCross
                               ?? true

    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(root.screen)
    readonly property int activeWorkspaceId: hyprlandMonitor?.activeWorkspace?.id ?? 0
    readonly property real monitorOffsetX: hyprlandMonitor?.x ?? 0
    readonly property real monitorOffsetY: hyprlandMonitor?.y ?? 0

    property list<var> windowRegions: []

    Process {
        id: screenshotProc
        property string outputName: root.screen ? root.screen.name : "unknown"
        property string filename: "/tmp/screen-%1.png".arg(outputName.replace(/[^a-zA-Z0-9_-]/g, "_"))

        command: ["grim", "-o", outputName, filename]
        running: false

        onStarted: {
            Logger.d("ScreenShot","Taking full screen shot of output '%1' to %2".arg(outputName).arg(filename))
            Logger.d("ScreenShot", "Screen name:", root.screen.name)
            root.visible = false
        }

        onExited: (code, status) => {
            if (code === 0) {



                Logger.d("ScreenShot", "[RegionSelector] Full Screen Shot saved to %1".arg(filename))
                root.visible = true
            } else {
                Logger.w("ScreenShot", "[RegionSelector] Full Screen Shot failed with exit code:", code)
                Logger.w("ScreenShot", "Command was: grim -o %1 %2".arg(outputName).arg(filename))
                root.closed()
            }
        }
    }

    // 启动时拉取窗口列表
    Process {
        id: hyprctlProc
        command: ["hyprctl", "-j", "clients"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const clients = JSON.parse(text);
                    const ws = root.activeWorkspaceId;
                    const ox = root.monitorOffsetX;
                    const oy = root.monitorOffsetY;
                    root.windowRegions = clients
                        .filter(w => w.workspace.id === ws && !w.hidden && w.mapped)
                        .map(w => ({
                            x: w.at[0] - ox,
                            y: w.at[1] - oy,
                            width: w.size[0],
                            height: w.size[1],
                            title: w.title,
                            cls: w.class,
                            address: w.address
                        }));

                    Logger.d("ScreenShot", "[RegionSelector] Found", root.windowRegions.length, "windows on workspace", root.activeWorkspaceId);
                } catch (e) {
                    Logger.w("ScreenShot", "[RegionSelector] hyprctl parse error:", e)
                }
            }
        }
    }

    Process {
        id: checkRecordingProc
        command: ["pidof", "wf-recorder"]
        running: false
        onExited: (exitCode) => {
            if (exitCode === 0) {
                if (root.target === "record" || root.target === "recordsound"){
                    Logger.d("ScreenShot", `bash '` + pluginApi.pluginDir + `/record.sh'`)
                    Quickshell.execDetached(["bash", pluginApi.pluginDir + "/record.sh"])
                    root.visible = false
                    root.closed()
                }
            }
        }
    }

    function startCapture() {
        checkRecordingProc.running = true

        if (!(root.target === "record" || root.target === "recordsound")) {
            screenshotProc.running = true
        }
        hyprctlProc.running = pluginApi?.pluginSettings?.enableWindowsSelection
                              ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableWindowsSelection
                              ?? true
    }

    property real mouseX: 0
    property real mouseY: 0
    property bool mouseInside: false

    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property bool dragging: false
    property var mouseButton: null

    property var hoveredWindow: null
    property var selectedWindow: null

    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)
    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)

    function findWindowAt(x, y) {
        for (let i = root.windowRegions.length - 1; i >= 0; i--) {
            const w = root.windowRegions[i];
            if (x >= w.x && x <= w.x + w.width &&
                y >= w.y && y <= w.y + w.height) {
                return w;
            }
        }
        return null;
    }

    function processRegion(x, y, width, height, mode) {
        // 获取显示器名称并清理
        var outputName = root.screen ? root.screen.name : "unknown"
        var safeOutputName = outputName.replace(/[^a-zA-Z0-9_-]/g, "_")

        // 生成带显示器名称的文件名
        var tempFile = "/tmp/screen-%1.png".arg(safeOutputName)
        const scaleRatio = CompositorService.getDisplayScale(root.screen.name)
        const scaledX = Math.round(x * scaleRatio)
        const scaledY = Math.round(y * scaleRatio)
        const scaledWidth = Math.round(width * scaleRatio)
        const scaledHeight = Math.round(height * scaleRatio)

        Logger.d("ScreenShot", "[Panel] Scaled values (ratio:", scaleRatio, "):",
                    scaledX, scaledY, scaledWidth, scaledHeight)

        Logger.d("ScreenShot", root.target)
        if (root.target === "screenshot") {
            if (mode === "copy") {
                const copyCmd = `magick '${tempFile}' -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} - | wl-copy`
                Logger.d("ScreenShot", "[Panel] Executing copy command:", copyCmd)
                Quickshell.execDetached(["sh", "-c", copyCmd])
            } else if (mode === "edit") {
                const editor = pluginApi?.pluginSettings?.screenshotEditor
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.screenshotEditor
                               ?? "swappy"

                const editCmd = `magick '${tempFile}' -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} - | ${editor} -f -`
                Logger.d("ScreenShot", "[Panel] Executing edit command:", editCmd)
                Quickshell.execDetached(["sh", "-c", editCmd])
            }
        } else if (root.target === "search") {
            const searchCmd = `magick '${tempFile}' -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} '${tempFile}' && xdg-open \"https://lens.google.com/uploadbyurl?url=$(curl -sF files[]=@'${tempFile}' https://uguu.se/upload | jq -r '.files[0].url')\"`
            Logger.d("ScreenShot", "[Panel] Executing search command:", searchCmd)
            Quickshell.execDetached(["sh", "-c", searchCmd])
        } else if (root.target === "ocr") {
            const ocrCmd = `magick '${tempFile}' -crop ${scaledWidth}x${scaledHeight}+${scaledX}+${scaledY} '${tempFile}' && tesseract '${tempFile}' stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\n' '+' | sed 's/\+$//') | wl-copy`
            Logger.d("ScreenShot", "[Panel] Executing ocr command:", ocrCmd)
            Quickshell.execDetached(["sh", "-c", ocrCmd])
        } else if (root.target === "record" || root.target === "recordsound") {


            const scriptPath = pluginApi.pluginDir + '/record.sh'

            const globalX = Math.round((x + root.monitorOffsetX))
            const globalY = Math.round((y + root.monitorOffsetY))
            const globalW = Math.round(width)
            const globalH = Math.round(height)

            const region = `${globalX},${globalY} ${globalW}x${globalH}`

            const soundFlag = root.target === "recordsound" ? " --sound" : ""

            const recordCmd = `bash '${scriptPath}' --region '${region}' ${soundFlag}`
            Logger.d("ScreenShot", "[Panel] Executing record command:", recordCmd)

            Quickshell.execDetached(["bash", "-c" , recordCmd])
        }
    }

    function finish() {
        const mode = (root.mouseButton === Qt.RightButton) ? "edit" : "copy"

        if (root.regionWidth > 0 && root.regionHeight > 0) {
            root.processRegion(root.regionX, root.regionY, root.regionWidth, root.regionHeight, mode)
        } else if (root.hoveredWindow) {
            root.processRegion(
                root.hoveredWindow.x,
                root.hoveredWindow.y,
                root.hoveredWindow.width,
                root.hoveredWindow.height,
                mode
            )
        }

        root.visible = false
        root.closed()
    }

    ScreencopyView {
        anchors.fill: parent
        live: false
        captureSource: root.screen



        Repeater {
            model: root.windowRegions
            delegate: Rectangle {
                required property var modelData
                z: 1
                x: modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                color: targeted ? "#22ffffff" : "transparent"
                border.color: targeted ? "#aaffffff" : "#55ffffff"
                border.width: targeted ? 3 : 1
                visible: !root.dragging

                readonly property bool targeted:
                    root.hoveredWindow !== null &&
                    root.hoveredWindow.address === modelData.address

                Behavior on border.width { NumberAnimation { duration: 80 } }
                Behavior on color { ColorAnimation { duration: 80 } }
            }
        }

        Rectangle {
            id: darkenOverlay
            z: 1
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: root.regionX - border.width
                topMargin: root.regionY - border.width
            }
            width: root.regionWidth + border.width * 2
            height: root.regionHeight + border.width * 2
            color: "transparent"
            border.color: "#88111111"
            border.width: Math.max(root.width, root.height)
            visible: root.dragging
        }

        Rectangle {
            z: 2
            x: root.regionX
            y: root.regionY
            width: root.regionWidth
            height: root.regionHeight
            color: "transparent"
            border.color: "#cccccc"
            border.width: 2
            visible: root.dragging
        }

        Text {
            z: 3
            x: root.regionX + root.regionWidth - width - 8
            y: root.regionY + root.regionHeight + 8
            text: root.dragging ? `${Math.round(root.regionWidth)} x ${Math.round(root.regionHeight)}` : ""
            color: "#cccccc"
            font.pixelSize: 13
            visible: root.dragging
        }

        // 十字准星
        Rectangle {
            visible: root.mouseInside && root.enableCross
            opacity: 0.4
            z: 2
            x: root.mouseX
            anchors { top: parent.top; bottom: parent.bottom }
            width: 1
            color: "#cccccc"
        }
        Rectangle {
            visible: root.mouseInside && root.enableCross
            opacity: 0.4
            z: 2
            y: root.mouseY
            anchors { left: parent.left; right: parent.right }
            height: 1
            color: "#cccccc"
        }

        // 背景遮罩
        Rectangle {
            anchors.fill: parent
            color: "#88111111"
            visible: !root.dragging
            z: 0
        }



        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            z: 10

            onPositionChanged: (mouse) => {
                root.mouseX = mouse.x
                root.mouseY = mouse.y
                root.mouseInside = true
                if (root.dragging) {
                    root.draggingX = mouse.x
                    root.draggingY = mouse.y
                } else {
                    root.hoveredWindow = root.findWindowAt(mouse.x, mouse.y)
                }
            }
            onExited: {
                root.mouseInside = false
                root.hoveredWindow = null
            }
            onPressed: (mouse) => {
                root.dragStartX = mouse.x
                root.dragStartY = mouse.y
                root.draggingX = mouse.x
                root.draggingY = mouse.y
                root.dragging = true
                root.mouseButton = mouse.button

                if (root.hoveredWindow) {
                    root.selectedWindow = root.hoveredWindow
                } else {
                    root.selectedWindow = null
                }
            }
            onReleased: (mouse) => {
                root.dragging = false

                const dragDistance = Math.sqrt(
                    Math.pow(root.draggingX - root.dragStartX, 2) +
                    Math.pow(root.draggingY - root.dragStartY, 2)
                );

                if (dragDistance == 0 && root.hoveredWindow) {
                    Logger.d("ScreenShot", "[RegionSelector] Click detected on window:", root.hoveredWindow.cls);
                }

                root.finish()
            }
        }

    }

    NBox {
        id: rowBackground
        color: Color.mPrimary
        radius: Style.radiusM
        width: rowLayout.implicitWidth + Style.marginL * 2
        height: rowLayout.implicitHeight + Style.marginM * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.marginM
        z: 20

        RowLayout {
            z: 20
            id: rowLayout
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
                icon: iconForTarget(root.target)
                color: Color.mOnPrimary
            }

            NText {
                text: labelForTarget(root.target)
                color: Color.mOnPrimary
            }

            NButton {
                z: 20
                icon: "close"
                backgroundColor: Color.mError
                textColor: Color.mOnError
                onClicked: {
                    root.visible = false
                    root.closed()
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutQuad } }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.visible = false
                root.closed()
                event.accepted = true
            }
        }
    }

    function iconForTarget(t: string): string {
        switch (t) {
            case "screenshot": return "screenshot"
            case "ocr": return "text-recognition"
            case "search": return "photo-search"
            case "record": return "camera"
            case "recordsound": return "camera-spark"
            default: return "bug"
        }
    }

    function labelForTarget(t: string): string {
        switch (t) {
            case "screenshot": return pluginApi?.tr("panel.target.screenshot")
            case "ocr": return pluginApi?.tr("panel.target.ocr")
            case "search": return pluginApi?.tr("panel.target.search")
            case "record": return pluginApi?.tr("panel.target.record")
            case "recordsound": return pluginApi?.tr("panel.target.recordsound")
            default: return pluginApi?.tr("panel.target.bug")
        }
    }

    // 键盘支持
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.visible = false
                event.accepted = true
                root.closed()
            }
        }

        Component.onCompleted: {
            forceActiveFocus()
        }
    }
}
