import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System

Item {
    id: root
    property var pluginApi: null
    
    readonly property real cpuUsage: SystemStatService.cpuUsage || 0
    readonly property real memoryUsage: SystemStatService.memoryUsage || 0
    readonly property string hostname: SystemStatService.hostname || "Unknown"
    readonly property string kernel: SystemStatService.kernel || "Unknown"
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            
            NIcon {
                icon: "info"
                pointSize: Style.fontSizeL
                color: Color.mPrimary
            }
            
            NText {
                text: "System Info"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                Layout.fillWidth: true
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                
                NText {
                    text: "Hostname:"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.preferredWidth: 80
                }
                
                NText {
                    text: hostname
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                
                NText {
                    text: "Kernel:"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.preferredWidth: 80
                }
                
                NText {
                    text: kernel
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                
                NText {
                    text: "CPU:"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.preferredWidth: 80
                }
                
                NText {
                    text: Math.round(cpuUsage) + "%"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                
                NText {
                    text: "Memory:"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.preferredWidth: 80
                }
                
                NText {
                    text: Math.round(memoryUsage) + "%"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }
            }
        }
    }
}
