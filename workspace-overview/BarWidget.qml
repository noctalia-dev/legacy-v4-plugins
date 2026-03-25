import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var screen: null

    // Ensures the widget occupies space in the bar
    implicitWidth: Style.baseWidgetSize
    implicitHeight: Style.baseWidgetSize
    
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    // Use NIcon instead of NIconButton to avoid circular background with inverted colors
    NIcon {
        id: widgetIcon
        anchors.centerIn: parent
        icon: "layout-dashboard"
        // Default icon color: white/light gray, like the others. 
        // Add hover color if the mouse is over.
        color: mouseArea.containsMouse ? Color.mPrimary : Color.mOnSurface
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, root)
            }
        }
    }
}
