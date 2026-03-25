import QtQuick
import Quickshell
import qs.Widgets
import qs.Commons
import qs.Services.UI

NIconButton {
    id: root
    property ShellScreen screen
    property var pluginApi: null
    icon: "crosshair"
    tooltipText: pluginApi?.tr("widget.tooltip")
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    colorBg: Style.capsuleColor
    colorBorder: "transparent"
    colorBorderHover: "transparent"
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    onClicked: {
        if (pluginApi) pluginApi.togglePanel(screen, this)
    }
}
