import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets


Item {
    id: root

    // ── 必须由 PluginService 注入的属性 ──────
    property var    pluginApi: null
    property var    screen
    property string widgetId: ""
    property string section:  ""

    // ── 每屏 bar 属性（多显示器支持）──────────
    readonly property string screenName:    screen?.name ?? ""
    readonly property string barPosition:   Settings.getBarPositionForScreen(screenName)
    readonly property bool   isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real   capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real   barFontSize:   Style.getBarFontSizeForScreen(screenName)

    // ── 插件设置 ─────────────────────────────
    readonly property int  barCount:   pluginApi?.pluginSettings?.bars   ?? 12
    readonly property int  framerate:  pluginApi?.pluginSettings?.framerate ?? 30  //  帧率控制
    readonly property real barWidth:   pluginApi?.pluginSettings?.barWidth ?? 6
    readonly property real barRadius:  pluginApi?.pluginSettings?.barRadius ?? 0
    readonly property string barColorMode:
        pluginApi?.pluginSettings?.barColorMode ??
        pluginApi?.manifest?.metadata?.defaultSettings?.barColorMode ??
        "primary"
    readonly property color barCustomColor:
        pluginApi?.pluginSettings?.barCustomColor ??
        pluginApi?.manifest?.metadata?.defaultSettings?.barCustomColor ??
        "#ff4d4d"
    readonly property string barVerticalAlign:
        pluginApi?.pluginSettings?.barVerticalAlign ??
        pluginApi?.manifest?.metadata?.defaultSettings?.barVerticalAlign ??
        "center"

    readonly property color barColor:
        barColorMode === "custom" ? barCustomColor : Color.resolveColorKey(barColorMode)

    // ── 状态 ─────────────────────────────────
    property bool  audioActive: false
    property double lastActiveMs: 0
    property var   barValues:   []   // 长度 = barCount，每项为 0-10 的数字，来自 cava 输出，映射到条高

    // ── 布局尺寸 ──────────────────────────────
    readonly property real barSpacing: 2
    readonly property real totalW:     barCount * barWidth + (barCount - 1) * barSpacing + Style.marginM * 2

    // 控制整个胶囊显隐
    readonly property bool shouldShow: audioActive
    readonly property real contentWidth:  shouldShow ? totalW : 0
    readonly property real contentHeight: shouldShow ? capsuleHeight : 0

    implicitWidth:  contentWidth
    implicitHeight: contentHeight

    visible: opacity > 0.01
    opacity: shouldShow ? 1.0 : 0.0

    // ── 胶囊背景 ─────────────────────────────
    Rectangle {
        id: capsule
        x:      Style.pixelAlignCenter(parent.width,  width)
        y:      Style.pixelAlignCenter(parent.height, height)
        width:  root.contentWidth
        height: root.contentHeight
        color:  Style.capsuleColor
        radius: Style.radiusM

        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, capsule, root.screen)
                }
            }
        }

        // ── 频谱条 ───────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: root.barVerticalAlign === "center" ? parent.verticalCenter : undefined
            anchors.bottom: root.barVerticalAlign === "bottom" ? parent.bottom : undefined
            anchors.bottomMargin: root.barVerticalAlign === "bottom" ? 0 : 0
            spacing: root.barSpacing

            Repeater {
                model: root.barCount
                delegate: Item {
                    width: root.barWidth
                    height: capsule.height

                    Rectangle {
                        id: bar
                        width: root.barWidth
                        property real normalized: (root.barValues.length > index)
                                                ? root.barValues[index] / 16.0
                                                : 0.0
                        property real maxBarHeight: root.barVerticalAlign === "bottom"
                                                    ? (capsule.height - Style.marginS - 3)
                                                    : (capsule.height - Style.marginS * 2)
                        height: root.barVerticalAlign === "bottom" ? Math.max(0.4, normalized * maxBarHeight) : Math.max(0.4, normalized * maxBarHeight / 2)
                        anchors.bottom: root.barVerticalAlign === "bottom" ? parent.bottom : parent.verticalCenter
                        anchors.bottomMargin: root.barVerticalAlign === "bottom" ? 3 : 0
                        radius: barRadius
                        bottomLeftRadius: root.barVerticalAlign === "bottom" ? barRadius : 0
                        bottomRightRadius: root.barVerticalAlign === "bottom" ? barRadius : 0
                        color: root.barColor

                        Behavior on height {
                            NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }
                    }

                    // 镜像条，仅 center 模式显示,解决垂直居中抖动问题
                    Rectangle {
                        visible: root.barVerticalAlign === "center"
                        width: bar.width
                        height: bar.height
                        anchors.top: parent.verticalCenter
                        radius: bar.radius
                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                        color: bar.color
                        transform: Scale {
                            yScale: -1
                            origin.y: bar.height / 2 - 0.2 //消除中间的缝隙
                        }
                    }
                }
            }
        }
    }

    // ── 淡入淡出动画 ─────────────────────────
    Behavior on implicitWidth {
        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
    }

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: function(action) {
            contextMenu.close()
            PanelService.closeContextMenu(root.screen)
            if (action === "widget-settings") {
                BarService.openPluginSettings(root.screen, root.pluginApi.manifest)
            }
        }
    }

   
    Timer {
        id: bridgeRestartTimer
        interval: 400
        repeat: false
        onTriggered: {
            bridge.running = false
            bridge.running = true
        }
    }
    
    function scheduleBridgeRestart() {
        bridgeRestartTimer.restart()
    }

    onBarCountChanged: scheduleBridgeRestart()
    onFramerateChanged: scheduleBridgeRestart()

    // ── Process：运行后台桥接脚本 ─────────────
    Process {
        id: bridge
        // 使用插件目录内的脚本；Quickshell 把 Qt.resolvedUrl 作为文件路径
        command: ["bash", Qt.resolvedUrl("cava-bridge.sh").toString().replace("file://", ""),
                  root.barCount.toString(),
                  root.framerate.toString()]
        running: true

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                if (line.startsWith("ACTIVE:")) {
                    root.audioActive = true
                    root.lastActiveMs = Date.now()
                    var data = line.substring(7)  // 去掉 "ACTIVE:"
                    // data 形如 "0;3;7;2;5;4;1;2;6;7;2;4;" 分号分隔的原始数字
                    var parts = data.split(";")
                    var vals = []
                    for (var i = 0; i < parts.length && vals.length < root.barCount; i++) {
                        var n = parseInt(parts[i], 10)
                        if (!isNaN(n)) vals.push(n)
                    }
                    // 补齐
                    while (vals.length < root.barCount) vals.push(0)
                    root.barValues = vals
                } else if (line === "IDLE") {
                    root.audioActive = false
                    // 重置所有条到 0
                    var zeros = []
                    for (var j = 0; j < root.barCount; j++) zeros.push(0)
                    root.barValues = zeros
                }
            }
        }
    }

    Timer {
        id: idleGuard
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!root.audioActive) {
                return
            }

            if (Date.now() - root.lastActiveMs > 1500) {
                root.audioActive = false
                var zeros = []
                for (var i = 0; i < root.barCount; i++) zeros.push(0)
                root.barValues = zeros
            }
        }
    }

    // ── 脚本路径调试日志 ──────────────────────
    Component.onCompleted: {
        Logger.i("CavaVisualizer", "Widget loaded, bars:", root.barCount)
    }

    Component.onDestruction: {
        bridge.running = false
    }
}