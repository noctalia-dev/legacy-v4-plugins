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

    readonly property var mainInst: pluginApi?.mainInstance ?? null
    readonly property bool isPanelOpen: pluginApi?.isPanelOpen ?? false
    readonly property bool isSelected: isPanelOpen

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    readonly property string badge: mainInst?.badgeText ?? ""
    readonly property color capsuleBgColor: {
        if (isSelected) {
            return mouseArea.containsMouse ? Qt.darker(Color.mPrimary, 1.08) : Color.mPrimary;
        }
        return mouseArea.containsMouse ? Color.mHover : Style.capsuleColor;
    }
    readonly property color contentColor: isSelected
        ? Color.mOnPrimary
        : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)
    implicitWidth: visualCapsule.width
    implicitHeight: visualCapsule.height

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": pluginApi?.tr("bar.clear") ?? "Clear",
                "action": "clear",
                "icon": "trash"
            },
            {
                "label": pluginApi?.tr("bar.settings") ?? "Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);

            if (action === "clear") {
                mainInst?.clearAll();
            } else if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest);
            }
        }
    }

    Rectangle {
        id: visualCapsule
        anchors.centerIn: parent
        width: Math.max(root.capsuleHeight, iconRow.implicitWidth + Style.marginM * 2)
        height: root.capsuleHeight
        radius: Style.radiusL
        color: root.capsuleBgColor
        border.color: root.isSelected ? Color.mPrimary : Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Row {
            id: iconRow
            anchors.centerIn: parent
            spacing: badge !== "" ? Style.marginS : 0

            NIcon {
                icon: "calculator"
                color: root.contentColor
            }

            NText {
                text: badge
                visible: text !== ""
                font.bold: true
                pointSize: Style.fontSizeS
                color: root.contentColor
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            TooltipService.hide();
            if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, root.screen);
            } else if (pluginApi) {
                pluginApi.togglePanel(root.screen, root);
            }
        }

        onEntered: {
            TooltipService.show(
                root,
                pluginApi?.tr("bar.tooltip-title") ?? "Calculator",
                BarService.getTooltipDirection(root)
            );
        }

        onExited: TooltipService.hide()
    }
}
