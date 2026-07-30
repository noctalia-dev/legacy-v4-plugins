import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    readonly property string screenName: screen ? screen.name : ""

    baseSize: Style.getCapsuleHeightForScreen(screenName)
    applyUiScale: false
    icon: "device-desktop"
    tooltipText: pluginApi ? pluginApi.tr("panel.display-configuration") : "Display Configuration"
    tooltipDirection: BarService.getTooltipDirection(screenName)

    colorBg: Style.capsuleColor
    colorFg: Color.mOnSurface
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    colorBorder: "transparent"
    colorBorderHover: "transparent"

    onClicked: pluginApi.openPanel(root.screen, this)
}
