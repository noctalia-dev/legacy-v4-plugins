import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io // Required for Process/Stdio logic
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets // Essential for NText, Color, and Style

DraggableDesktopWidget {
    id: root
    property var pluginApi: null

    // --- Sizing ---
    readonly property real _width: Math.round(250 * widgetScale)
    readonly property real _height: Math.round(285 * widgetScale)
    implicitWidth: _width
    implicitHeight: _height

    // --- Date Logic ---
    readonly property date currentDate: new Date()
    readonly property var days: ["M", "T", "W", "T", "F", "S", "S"]
    
    readonly property int firstDayOffset: {
        let firstDay = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).getDay();
        return (firstDay === 0) ? 6 : firstDay - 1;
    }
    readonly property int daysInMonth: new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate()
    readonly property int today: currentDate.getDate()

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

            // Month and Year Header
            NText {
                text: currentDate.toLocaleDateString(Qt.locale(), "MMMM yyyy").toUpperCase()
                color: Color.mPrimary 
                font.bold: true
                font.letterSpacing: 1.2
                font.pointSize: Style.fontSizeM
                Layout.alignment: Qt.AlignHCenter
            }

            // Calendar Grid
            GridLayout {
                columns: 7
                rowSpacing: Style.marginS
                columnSpacing: Style.marginS
                Layout.fillWidth: true

                // 1. Day Headers
                Repeater {
                    model: root.days
                    NText {
                        text: modelData
                        color: Color.mOnSurfaceVariant
                        font.bold: true
                        font.pointSize: Style.fontSizeS
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // 2. Padding
                Repeater {
                    model: root.firstDayOffset
                    Item { Layout.preferredWidth: 20 * widgetScale; Layout.preferredHeight: 20 * widgetScale }
                }

                // 3. The Days
                Repeater {
                    model: root.daysInMonth
                    Rectangle {
                        readonly property int dayNum: index + 1
                        Layout.preferredWidth: 28 * widgetScale
                        Layout.preferredHeight: 28 * widgetScale
                        
                        // Today's highlight uses theme Primary color
                        color: dayNum === root.today ? Color.mPrimary : "transparent"
                        radius: Style.radiusS

                        NText {
                            anchors.centerIn: parent
                            text: dayNum
                            // Contrast logic: use surface color on primary background
                            color: dayNum === root.today ? Color.mOnPrimary : Color.mOnSurface
                            font.bold: dayNum === root.today
                            font.pointSize: Style.fontSizeS
                        }
                    }
                }
            }
        }
    }
}
