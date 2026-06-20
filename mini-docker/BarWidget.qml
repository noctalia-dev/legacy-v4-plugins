import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.System
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    property real baseSize: Style.capsuleHeight
    property bool applyUiScale: false
    property string tooltipText: dockerAvailable ? (pluginApi ? pluginApi.tr("tooltip.running_containers").arg(runningCount) : "Containers: " + runningCount) : (pluginApi ? pluginApi.tr("tooltip.docker_not_available") : "Docker not available")
    property string tooltipDirection: BarService.getTooltipDirection()
    property string density: Settings.data.bar.density
    property bool enabled: true
    property bool allowClickWhenDisabled: false
    property bool hovering: false
    property color colorBg: Style.capsuleColor
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor ?? "none"
    readonly property string statusStateKey: cfg.statusState ?? defaults.statusState ?? "all"
    property color colorFg: Color.resolveColorKey(iconColorKey)
    readonly property string activeColorKey: cfg.activeColor ?? defaults.activeColor ?? "success"
    readonly property string inactiveColorKey: cfg.inactiveColor ?? defaults.inactiveColor ?? "error"
    readonly property color activeColor: Color.resolveColorKey(activeColorKey)
    readonly property color inactiveColor: Color.resolveColorKey(inactiveColorKey)
    property color colorBgHover: Color.mHover
    property color colorFgHover: Color.mOnHover
    property color colorBorder: Style.capsuleBorderColor
    property color colorBorderHover: Style.capsuleBorderColor
    property real customRadius: Style.radiusL
    property bool dockerAvailable: false
    property int runningCount: 0

    signal entered()
    signal exited()
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(int angleDelta)

    readonly property real contentWidth: applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)
    readonly property real contentHeight: applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Component.onCompleted: dockerCheckProcess.running = true

    Process {
        id: dockerCountProcess

        command: ["docker", "ps", "-q"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                runningCount = output === "" ? 0 : output.split('\n').length;
            }
        }
    }

    Timer {
        interval: (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.refreshInterval) || 5000
        running: true
        repeat: true
        onTriggered: {
            if (dockerAvailable)
                dockerCountProcess.running = true;
        }
    }

    Process {
        id: dockerCheckProcess

        running: false
        command: ["docker", "--version"]
        onExited: (code, status) => {
            dockerAvailable = (code === 0);
            if (dockerAvailable)
                dockerCountProcess.running = true;
        }
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        opacity: root.enabled ? (dockerAvailable ? Style.opacityFull : Style.opacityMedium) : Style.opacityMedium
        color: hovering ? colorBgHover : colorBg
        radius: Math.min((customRadius >= 0 ? customRadius : Style.iRadiusL), width / 2)
        border.color: hovering ? colorBorderHover : colorBorder
        border.width: Style.capsuleBorderWidth

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        NIcon {
            id: icon

            anchors.centerIn: parent
            icon: "brand-docker"
            color: dockerAvailable ? (hovering ? colorFgHover : colorFg) : Color.mOnSurfaceVariant
        }

        Rectangle {
            z: 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 3
            anchors.rightMargin: 3
            width: 6
            height: 6
            radius: 3
            color: runningCount > 0 ? activeColor : inactiveColor
            visible: dockerAvailable && statusStateKey !== "hidden" && (statusStateKey !== "running-only" || runningCount > 0)
            border.width: 1
            border.color: visualCapsule.color
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": pluginApi?.tr("menu.settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]
        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);
            if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            root.hovering = true;
            root.entered();
        }
        onExited: {
            root.hovering = false;
            root.exited();
        }
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi && dockerAvailable)
                    pluginApi.openPanel(root.screen);
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, root.screen);
            }
        }
        onPressAndHold: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, root.screen);
            } else {
                root.rightClicked();
            }
        }
        onWheel: (wheel) => {
            return root.wheel(wheel.angleDelta.y);
        }
    }
}
