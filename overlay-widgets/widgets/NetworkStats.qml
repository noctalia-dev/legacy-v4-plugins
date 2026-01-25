import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.System

Item {
    id: root
    property var pluginApi: null
    
    readonly property real networkRx: SystemStatService.networkRx || 0
    readonly property real networkTx: SystemStatService.networkTx || 0
    
    function formatBytes(bytes) {
        if (bytes === 0) return "0 B";
        var k = 1024;
        var sizes = ["B", "KB", "MB", "GB", "TB"];
        var i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i];
    }
    
    function formatSpeed(bytes) {
        return formatBytes(bytes) + "/s";
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            
            NIcon {
                icon: "network"
                pointSize: Style.fontSizeL
                color: Color.mPrimary
            }
            
            NText {
                text: "Network"
                pointSize: Style.fontSizeM
                font.weight: Font.Medium
                color: Color.mOnSurface
                Layout.fillWidth: true
            }
        }
        
        RowLayout {
            id: statsRow
            Layout.fillWidth: true
            spacing: Style.marginS
            
            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                clip: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Style.marginXS
                    
                    NIcon {
                        icon: "download"
                        pointSize: Style.fontSizeM
                        color: Color.mPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    NText {
                        text: "Download"
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    
                    NText {
                        text: formatSpeed(networkRx)
                        pointSize: Style.fontSizeM
                        font.weight: Font.Medium
                        color: Color.mOnSurface
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
            
            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                clip: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Style.marginXS
                    
                    NIcon {
                        icon: "upload"
                        pointSize: Style.fontSizeM
                        color: Color.mPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    
                    NText {
                        text: "Upload"
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    
                    NText {
                        text: formatSpeed(networkTx)
                        pointSize: Style.fontSizeM
                        font.weight: Font.Medium
                        color: Color.mOnSurface
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
