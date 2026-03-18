import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets 

DraggableDesktopWidget {
    id: root
    property var pluginApi: null

    // Increased width slightly to 300 to accommodate long kernel strings
    readonly property real _width: Math.round(300 * widgetScale)
    readonly property real _height: Math.round(165 * widgetScale)
    
    implicitWidth:  _width
    implicitHeight: _height

    property string kernelVal: "Loading..."
    property string uptimeVal: "Loading..."

    // --- Data Fetching ---
    Process {
        id: uptimeProc
        command: ["sh", "-c", "awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); if(d>0) printf \"%dd \", d; printf \"%dh %dm\", h, m}' /proc/uptime"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { if (text.trim() !== "") root.uptimeVal = text.trim(); }
        }
    }

    Process {
        id: kernelProc
        command: ["uname", "-r"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.kernelVal = text.trim() }
    }

    Timer { interval: 60000; running: true; repeat: true; onTriggered: uptimeProc.running = true }

    // --- UI Layout ---
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        opacity: 0.85
        radius: Style.radiusM
        border.color: Color.mOutlineVariant
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                rowSpacing: Style.marginS

                NText { 
                    text: "Distribution"
                    color: Color.mOnSurfaceVariant
                    font.pointSize: 11 
                }
                NText { 
                    text: "Arch Linux"
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: 11
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight 
                }

                // Row 2: Kernel (Modified for no truncation)
                NText { 
                    text: "Kernel"
                    color: Color.mOnSurfaceVariant
                    font.pointSize: 11
                }
                NText { 
                    text: root.kernelVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: 11
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    // Ensures the text doesn't elide or wrap
                    elide: Text.ElideNone 
                    wrapMode: Text.NoWrap
                }

                NText { 
                    text: "Uptime"
                    color: Color.mOnSurfaceVariant
                    font.pointSize: 11
                }
                NText { 
                    text: root.uptimeVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: 11
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight 
                }
            }
        }
    }
}
