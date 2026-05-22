import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property var mainInstance: pluginApi?.mainInstance

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
    readonly property real contentWidth: capsuleHeight
    readonly property real contentHeight: capsuleHeight

    anchors.centerIn: parent
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    NPopupContextMenu {
        id: contextMenu
        screen: root.screen

        model: [
            {
                "label": "Refresh",
                "action": "refresh",
                "icon": "refresh"
            }
        ]

        onTriggered: (action, item) => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);
            if (action === "refresh")
                mainInstance?.refresh();
        }
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        NIcon {
            anchors.centerIn: parent
            icon: "sparkles"
            pointSize: root.barFontSize * 1.05
            applyUiScale: false
            color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
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
                TooltipService.hide();
                pluginApi?.togglePanel(root.screen, root);
            } else if (mouse.button === Qt.RightButton) {
                TooltipService.hide();
                PanelService.showContextMenu(contextMenu, root, root.screen);
            }
        }

        onEntered: {
            TooltipService.show(root, mainInstance?.tooltipText() ?? "ModelBar", BarService.getTooltipDirection(root.screenName));
        }

        onExited: {
            TooltipService.hide();
        }
    }
}
