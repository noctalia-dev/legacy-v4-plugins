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

    readonly property bool barIsVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

    readonly property real contentWidth: {
        if ((mainInstance?.compactMode ?? false) || !(mainInstance?.netbirdRunning ?? false)) {
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

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginS
            layoutDirection: Qt.LeftToRight

            NetBirdIcon {
                pointSize: Style.fontSizeL
                applyUiScale: false
                crossed: !(mainInstance?.netbirdRunning ?? false)
                color: {
                    if (mainInstance?.netbirdRunning ?? false)
                        return Color.mPrimary;
                    return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface;
                }
                opacity: (mainInstance?.isRefreshing ?? false) ? 0.5 : 1.0
            }

            ColumnLayout {
                visible: !(mainInstance?.compactMode ?? false) && (mainInstance?.netbirdRunning ?? false) && ((mainInstance?.showIpAddress ?? false) || (mainInstance?.showPeerCount ?? false))
                spacing: 2
                Layout.leftMargin: Style.marginXS
                Layout.rightMargin: Style.marginS

                NText {
                    visible: (mainInstance?.showIpAddress ?? false) && (mainInstance?.netbirdIp ?? false)
                    text: mainInstance?.netbirdIp || ""
                    pointSize: Style.fontSizeXS
                    color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                    font.family: Settings.data.ui.fontFixed
                }
            }
        }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": (mainInstance?.netbirdRunning ?? false) ? (pluginApi?.tr("context.disconnect") || "Disconnect") : (pluginApi?.tr("context.connect") || "Connect"),
                "action": "toggle-netbird",
                "icon": (mainInstance?.netbirdRunning ?? false) ? "plug-x" : "plug",
                "enabled": mainInstance?.netbirdInstalled ?? false
            },
            {
                "label": pluginApi?.tr("actions.widget-settings") || "Widget Settings",
                "action": "widget-settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (action === "toggle-netbird") {
                if (mainInstance) {
                    mainInstance.toggleNetbird();
                }
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
