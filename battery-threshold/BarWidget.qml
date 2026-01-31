import QtQuick
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

    readonly property real contentWidth: contentIcon.implicitWidth + Style.marginM * 2
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

        NIcon {
            id: contentIcon
            anchors.centerIn: parent
            icon: "charging-pile"
            applyUiScale: false
            color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("actions.widget-settings") || "Widget Settings",
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            BarService.openPluginSettings(screen, pluginApi.manifest);
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: button => {
            if (pluginApi) {
                if (button.button === Qt.LeftButton) {
                    pluginApi.openPanel(root.screen);
                } else if (button.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, root, screen);
                }
            }
        }
    }
}
