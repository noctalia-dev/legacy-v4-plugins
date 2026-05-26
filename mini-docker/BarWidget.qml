import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.System
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    readonly property var main: pluginApi?.mainInstance
    readonly property var runningCount: main?.runningCount
    readonly property var dockerAvailable: main?.dockerAvailable
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    icon: "brand-docker"
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    tooltipText: dockerAvailable ? (pluginApi ? pluginApi.tr("tooltip.running_containers").arg(runningCount) : "Containers: " + runningCount) : (pluginApi ? pluginApi.tr("tooltip.docker_not_available") : "Docker not available")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    colorBg: Style.capsuleColor
    colorFg: Color.mOnSurface
    customRadius: Style.radiusL

    colorBgHover: Color.mHover
    colorFgHover: Color.mOnHover
    colorBorder: "transparent"
    colorBorderHover: "transparent"

    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    opacity: dockerAvailable ? 1 : 0.25

    Loader {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenterOffset: parent.baseSize / 4
        anchors.verticalCenterOffset: -parent.baseSize / 4
        z: 2
        active: dockerAvailable
        sourceComponent: Rectangle {
            id: badge
            height: 7
            width: height
            radius: Style.radiusXS
            color: runningCount > 0 ? "#4caf50" : "#f44336"
            border.color: Color.mSurface
            border.width: Style.borderS
        }
    }

    onClicked: {
        if (pluginApi && dockerAvailable)
            pluginApi.openPanel(root.screen);
    }
}
