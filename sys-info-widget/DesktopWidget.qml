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

    readonly property real _width: Math.round(320 * widgetScale)
    readonly property real _height: Math.round(380 * widgetScale)

    implicitWidth:  _width
    implicitHeight: _height

    // --- Data Variables ---
    property string distroVal: pluginApi?.tr("widget.loading")
    property string kernelVal: "..."
    property string uptimeVal: "..."
    property string lanaddressVal: "..."
    property string ipaddressVal: "..."
    property string cpuUsage: "..."
    property string cpuTemp: "..."
    property string memUsage: "..."
    property string rootDisk: "..."
    property string homeDisk: "..."

    // --- Data Fetching ---
    Process {
        id: distroProc
        command: ["sh", "-c", "grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.distroVal = text.trim()
        }
    }

    Process {
        id: kernelProc
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.kernelVal = text.trim()
        }
    }

    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/up //; s/ days*/d/; s/ hours*/h/; s/ minutes*/m/; s/,//g'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.uptimeVal = text.trim()
        }
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4\"%\"}'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.cpuUsage = text.trim()
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c", "sensors | grep 'Package id 0' | awk '{print $4}' | tr -d '+'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.cpuTemp = text.trim()
        }
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free -h | awk '/Mem:/ {print $3 \" / \" $2}'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.memUsage = text.trim()
        }
    }

    Process {
        id: rootDiskProc
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.rootDisk = text.trim()
        }
    }

    Process {
        id: homeDiskProc
        command: ["sh", "-c", "df -h /home | awk 'NR==2 {print $3 \" / \" $2 \" (\" $5 \")\"}'"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.homeDisk = text.trim()
        }
    }

    Process {
        id: lanaddressProc
        command: ["sh", "-c", "ip -4 addr show scope global | awk '/inet/ {print $2}' | head -n 1 | cut -d/ -f1"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.lanaddressVal = text.trim()
        }
    }

    Process {
        id: ipaddressProc
        command: ["curl", "-s", "ifconfig.me"]
        stdout: StdioCollector {
            onTextChanged: if (text.trim() !== "") root.ipaddressVal = text.trim()
        }
    }

    // --- Timers ---
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            uptimeProc.running = true
            cpuProc.running = true
            tempProc.running = true
            memProc.running = true
            rootDiskProc.running = true
            homeDiskProc.running = true
        }
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            distroProc.running = true
            kernelProc.running = true
            lanaddressProc.running = true
            ipaddressProc.running = true
        }
    }

    // --- UI Layout ---
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        opacity: 0.85
        radius: Style.radiusM

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                rowSpacing: 8

                // --- System Row ---
                NText {
                    text: pluginApi?.tr("widget.distribution")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.distroVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- Kernel Row ---
                NText {
                    text: pluginApi?.tr("widget.kernel")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.kernelVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- Uptime Row ---
                NText {
                    text: pluginApi?.tr("widget.uptime")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.uptimeVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- CPU Row ---
                NText {
                    text: pluginApi?.tr("widget.cpu")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.cpuUsage + " @ " + root.cpuTemp
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- Memory Row ---
                NText {
                    text: pluginApi?.tr("widget.memory")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.memUsage
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- Disk Root Row ---
                NText {
                    text: pluginApi?.tr("widget.disk_root")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.rootDisk
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- Disk Home Row ---
                NText {
                    text: pluginApi?.tr("widget.disk_home")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.homeDisk
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- Separator ---
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    height: 1
                    color: Color.mOnSurfaceVariant
                    opacity: 0.15
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // --- LAN Row ---
                NText {
                    text: pluginApi?.tr("widget.lanaddress")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.lanaddressVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }

                // --- IP Row ---
                NText {
                    text: pluginApi?.tr("widget.ipaddress")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeS * widgetScale
                }
                NText {
                    text: root.ipaddressVal
                    color: Color.mOnSurface
                    font.bold: true
                    font.pointSize: Style.fontSizeS * widgetScale
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
