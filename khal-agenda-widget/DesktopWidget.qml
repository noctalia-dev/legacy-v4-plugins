import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
    id: root
    property var pluginApi: null

    // Updated dimensions
    readonly property real _width: Math.round(320 * widgetScale)
    readonly property real _height: Math.round(200 * widgetScale)

    implicitWidth:  _width
    implicitHeight: _height

    property string calendarVal: ""

    // Main data process
    Process {
        id: calProc
        command: ["sh", "-c", "khal list --notstarted now 7d --format '{start-time} {title}' --day-format '{name}, {date}'"]
        // command: ["sh", "-c", "khal list today 7d --format '{start-end-time-style} {title}' --day-format '{name}, {date}'"]
        running: root.pluginApi !== null
        stdout: StdioCollector {
            onTextChanged: root.calendarVal = text.trim().replace(/\n\s*\n/g, '\n')
        }
    }

    // Universal terminal launcher (Handles -e and -- syntax) but has the class for kitty alone
    Process {
        id: openIkhal
        command: [
            "sh", "-c",
            "for term in xdg-terminal-exec kitty alacritty foot gnome-terminal konsole st xterm; do " +
            "if command -v $term >/dev/null 2>&1; then " +
            "if [ \"$term\" = \"kitty\" ]; then " +
            "exec kitty --class khal -e ikhal; " +
            "else " +
            "exec $term -e ikhal 2>/dev/null || exec $term -- ikhal; " +
            "fi; break; fi; done"
        ]
    }

    // Refresh every minute
    Timer {
        interval: 60000
        running: root.pluginApi !== null
        repeat: true
        onTriggered: {
            calProc.running = false
            calProc.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        opacity: 0.85
        radius: Style.radiusM

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL

            // Render only when API is ready to ensure translations work correctly
            visible: root.pluginApi !== null

            RowLayout {
                Layout.fillWidth: true

                NText {
                    text: root.pluginApi.tr("widget.heading")
                    color: Color.mOnSurfaceVariant
                    font.pointSize: Style.fontSizeL * widgetScale
                    Layout.fillWidth: true
                }

                NIconButton {
                    // Strict translation: no fallback string used here
                    icon: root.pluginApi.tr("widget.button")

                    Layout.preferredWidth: 32 * widgetScale
                    Layout.preferredHeight: 32 * widgetScale

                    onClicked: {
                        openIkhal.running = false
                        openIkhal.running = true
                    }
                }
            }

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Force horizontal scrollbar off
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                NText {
                    // Force the text width to match the ScrollView's width
                    width: parent.width
                    text: root.calendarVal !== "" ? root.calendarVal : root.pluginApi.tr("widget.loading")

                    color: Color.mOnSurface
                    font.pointSize: Style.fontSizeL * widgetScale
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    font.family: "Monospace"
                }
            }
        }
    }
}
