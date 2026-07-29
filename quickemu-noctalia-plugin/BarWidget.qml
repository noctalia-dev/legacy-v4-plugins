import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property bool pillDirection: BarService.getPillDirection(root)

    readonly property var mainInstance: pluginApi?.mainInstance

    readonly property real contentWidth: contentRow.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: Style.capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        radius: Style.radiusL

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginS
            layoutDirection: Qt.LeftToRight

            NIcon {
                icon: "server"
                pointSize: Style.fontSizeL
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            }

            NText {
                text: pluginApi?.tr("widget.title")
                pointSize: Style.fontSizeS
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                font.weight: Style.fontWeightMedium
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: mouse => {
            if (pluginApi) {
                pluginApi.openPanel(root.screen, root);
            }
        }
    }
}
