import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null
    property ShellScreen screen
    
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property real ratioStart: mainInstance?.ratioStart ?? 0
    readonly property real ratioWidth: mainInstance?.ratioWidth ?? 1

    implicitWidth: 160
    implicitHeight: Style.capsuleHeight

    Rectangle {
        id: track
        anchors.fill: parent
        anchors.margins: 8
        color: Color.mSurfaceVariant
        opacity: 0.3
        radius: 4
        clip: true
        
        border.width: 1
        border.color: Qt.rgba(Color.mOnSurface.r, Color.mOnSurface.g, Color.mOnSurface.b, 0.1)

        Rectangle {
            id: viewportIndicator
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            
            width: Math.max(12, parent.width * Math.min(1.0, root.ratioWidth))
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.ratioStart))
            
            color: Color.mPrimary
            radius: 3
            opacity: 0.8

            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            
            // Inner shine for a polished look
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "white"
                opacity: 0.15
                radius: 2
            }
        }
    }
}
