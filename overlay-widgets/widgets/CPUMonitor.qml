import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System

Item {
    id: root
    property var pluginApi: null
    
    readonly property real cpuUsage: SystemStatService.cpuUsage || 0
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            
            NIcon {
                icon: "cpu"
                pointSize: Style.fontSizeL
                color: Color.mPrimary
            }
            
            NText {
                text: "CPU Usage"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                Layout.fillWidth: true
            }
            
            NText {
                text: Math.round(cpuUsage) + "%"
                pointSize: Style.fontSizeL
                font.weight: Font.Bold
                color: Color.mPrimary
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            radius: Style.radiusS
            color: Color.mSurfaceVariant
            border.color: Color.mOutline
            border.width: 1
            
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 2
                width: (parent.width - 4) * (cpuUsage / 100)
                radius: Style.radiusS - 1
                color: {
                    if (cpuUsage < 50) return Color.mPrimary;
                    if (cpuUsage < 80) return "#FFA500";
                    return Color.mError;
                }
                
                Behavior on width {
                    NumberAnimation { duration: 300 }
                }
            }
        }
        
        // NText {
        //     text: "Cores: " + (SystemStatService.cpuCores || "N/A")
        //     pointSize: Style.fontSizeS
        //     color: Color.mOnSurfaceVariant
        // }
    }
}
