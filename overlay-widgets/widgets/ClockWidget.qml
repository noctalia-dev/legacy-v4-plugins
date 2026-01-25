import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    
    // Transparent background
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        
        // Small white frame
        Rectangle {
            anchors.centerIn: parent
            width: timeText.implicitWidth + 20
            height: timeText.implicitHeight + 10
            color: "transparent"
            border.color: "white"
            border.width: 1
            radius: 4
            
            // Time text
            NText {
                id: timeText
                anchors.centerIn: parent
                text: Qt.formatDateTime(new Date(), "HH:mm")
                pointSize: Style.fontSizeL
                font.weight: Font.Medium
                color: "white"
            }
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            timeText.text = Qt.formatDateTime(new Date(), "HH:mm");
        }
    }
}
