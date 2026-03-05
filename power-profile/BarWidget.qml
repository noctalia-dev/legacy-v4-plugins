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

    readonly property bool showLabel: true

    readonly property real contentWidth: {
        if (!showLabel || !mainInstance?.available) {
            return Style.capsuleHeight;
        }
        return contentRow.implicitWidth + Style.marginM * 2;
    }
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
        opacity: mainInstance?.available ? 1.0 : 0.5

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            NIcon {
                icon: mainInstance?.getProfileIcon(mainInstance?.currentProfile ?? "") ?? "cpu"
                pointSize: Style.fontSizeL
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
            }

            NText {
                visible: root.showLabel && (mainInstance?.available ?? false)
                text: mainInstance?.getProfileLabel(mainInstance?.currentProfile ?? "") ?? ""
                pointSize: Style.fontSizeS
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            }
        }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": mainInstance?.getProfileLabel(mainInstance?.currentProfile ?? "") ?? "",
                "action": "current",
                "icon": mainInstance?.getProfileIcon(mainInstance?.currentProfile ?? "") ?? "cpu",
                "enabled": false
            },
            {
                "label": pluginApi?.tr("context.refresh") || "Refresh",
                "action": "refresh",
                "icon": "refresh",
                "enabled": !(mainInstance?.busy ?? true)
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "refresh") {
                mainInstance?.refresh();
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi) {
                    pluginApi.openPanel(root.screen, root);
                }
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen);
            }
        }
    }
}
