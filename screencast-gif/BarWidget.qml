import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    property var pluginApi: null

    readonly property bool recording: pluginApi?.mainInstance?.recordingActive ?? false
    readonly property string screenName: screen?.name ?? ""

    baseSize: Style.getCapsuleHeightForScreen(screenName)
    applyUiScale: false
    customRadius: Style.radiusL
    icon: "circle-filled"
    tooltipText: recording
                 ? pluginApi?.tr("widget.tooltip.recording")
                 : pluginApi?.tr("widget.tooltip.idle")
    tooltipDirection: BarService.getTooltipDirection(screenName)
    colorBg: recording ? Color.mError : Style.capsuleColor
    colorFg: recording ? Color.mOnError : Color.mOnSurface
    colorBgHover: recording ? Color.mError : Color.mHover
    colorFgHover: recording ? Color.mOnError : Color.mOnHover
    colorBorder: Style.capsuleBorderColor
    colorBorderHover: Style.capsuleBorderColor

    onClicked: pluginApi?.mainInstance?.trigger()
}
