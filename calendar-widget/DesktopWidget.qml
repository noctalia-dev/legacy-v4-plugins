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

    readonly property bool startOnMonday: pluginApi?.pluginSettings?.startOnMonday ?? true

    // --- Sizing ---
    readonly property real _width: Math.round(250 * widgetScale)
    readonly property real _height: Math.round(285 * widgetScale)
    implicitWidth: _width
    implicitHeight: _height

    // --- Date Logic ---
    property date currentDate: new Date()
    // We use these as "Primitive Anchors"
    property int liveDay: new Date().getDate()
    property int liveMonth: new Date().getMonth()
    property int liveYear: new Date().getFullYear()

    function refreshDate() {
        let now = new Date();
        currentDate = now;
        // Updating these primitives is the "hammer" that forces QML to redraw
        liveDay = now.getDate();
        liveMonth = now.getMonth();
        liveYear = now.getFullYear();
    }

    onVisibleChanged: if (visible) refreshDate()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refreshDate()
    }

    readonly property var days: startOnMonday
    ? ["M", "T", "W", "T", "F", "S", "S"]
    : ["S", "M", "T", "W", "T", "F", "S"]

    readonly property int firstDayOffset: {
        let firstDay = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).getDay();
        if (startOnMonday) {
            return (firstDay === 0) ? 6 : firstDay - 1;
        } else {
            return firstDay;
        }
    }

    readonly property int daysInMonth: new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate()

    // --- UI Layout ---
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        opacity: 0.85
        radius: Style.radiusM
        border.color: Color.mOutline
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            NText {
                text: currentDate.toLocaleDateString(Qt.locale(), "MMMM yyyy").toUpperCase()
                color: Color.mPrimary
                font.bold: true
                font.letterSpacing: 1.2
                font.pointSize: Style.fontSizeM
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Style.marginS
            }

            GridLayout {
                columns: 7
                rowSpacing: Style.marginS
                columnSpacing: Style.marginS
                Layout.fillWidth: true

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

                Repeater {
                    model: root.firstDayOffset
                    Item { Layout.preferredWidth: 20 * widgetScale; Layout.preferredHeight: 20 * widgetScale }
                }

                Repeater {
                    model: root.daysInMonth
                    Rectangle {
                        readonly property int dayNum: index + 1

                        readonly property bool isActuallyToday:
                        dayNum === root.liveDay &&
                        root.currentDate.getMonth() === root.liveMonth &&
                        root.currentDate.getFullYear() === root.liveYear

                        Layout.preferredWidth: 28 * widgetScale
                        Layout.preferredHeight: 28 * widgetScale

                        color: isActuallyToday ? Color.mPrimary
                        radius: Style.radiusS

                        NText {
                            anchors.centerIn: parent
                            text: dayNum
                            color: isActuallyToday ? Color.mOnPrimary : Color.mOnSurface
                            font.bold: isActuallyToday
                            font.pointSize: Style.fontSizeS
                        }
                    }
                }
            }
        }
    }
}
