import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Rectangle {
    id: root
    
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    implicitWidth: Style.barHeight
    implicitHeight: Style.barHeight
    radius: Style.radiusS
    
    color: "transparent"

    NIcon {
        anchors.centerIn: parent
        icon: "device-desktop"
        color: Color.mPrimary
        width: 20
        height: 20
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onEntered: root.color = Color.mSurfaceVariant
        onExited: root.color = "transparent"

        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, root)
            }
        }
    }
}