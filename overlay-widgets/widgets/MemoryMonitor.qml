import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System

Item {
    id: root
    property var pluginApi: null
    
    readonly property real memoryUsage: SystemStatService.memoryUsage || 0
    readonly property real totalMemory: SystemStatService.totalMemory || 0
    readonly property real usedMemory: SystemStatService.usedMemory || 0
    
    function formatBytes(bytes) {
        if (bytes === 0) return "0 B";
        var k = 1024;
        var sizes = ["B", "KB", "MB", "GB", "TB"];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i];
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            
            NIcon {
                icon: "memory"
                pointSize: Style.fontSizeL
                color: Color.mPrimary
            }
            
            NText {
                text: "Memory"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                Layout.fillWidth: true
            }
            
            NText {
                text: Math.round(memoryUsage) + "%"
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
                width: (parent.width - 4) * (memoryUsage / 100)
                radius: Style.radiusS - 1
                color: {
                    if (memoryUsage < 60) return Color.mPrimary;
                    if (memoryUsage < 85) return "#FFA500";
                    return Color.mError;
                }
                
                Behavior on width {
                    NumberAnimation { duration: 300 }
                }
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS
            
            NText {
                text: "Used: " + formatBytes(usedMemory)
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }
            
            NText {
                text: "Total: " + formatBytes(totalMemory)
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
            }
        }
    }
}
