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
    readonly property bool isRunning: mainInstance?.running ?? false
    readonly property bool isEnabled: mainInstance?.enabled ?? false
    readonly property int maxVisible: mainInstance?.maxVisible ?? 4

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real barHeight: Style.getBarHeightForScreen(screenName)
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    readonly property real contentWidth: {
        if (isVertical) return root.capsuleHeight;
        return columnIndicator.implicitWidth + Style.marginM * 2;
    }
    readonly property real contentHeight: root.capsuleHeight

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
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Row {
            id: columnIndicator
            anchors.centerIn: parent
            spacing: Style.marginXXS
            opacity: isEnabled ? 1.0 : 0.35

            Repeater {
                model: root.maxVisible

                Rectangle {
                    width: Math.round(4 * Style.uiScaleRatio)
                    height: root.capsuleHeight * 0.5
                    radius: Style.radiusXXXS
                    color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                }
            }
        }
    }

    // Status indicator dot
    Rectangle {
        anchors.bottom: visualCapsule.bottom
        anchors.horizontalCenter: visualCapsule.horizontalCenter
        anchors.bottomMargin: Style.marginXXXS
        width: Math.round(4 * Style.uiScaleRatio)
        height: Math.round(4 * Style.uiScaleRatio)
        radius: Math.round(2 * Style.uiScaleRatio)
        visible: isEnabled
        color: isRunning ? Color.mPrimary : Color.mSecondary
    }

    NPopupContextMenu {
        id: contextMenu

        model: {
            var items = [];
            items.push({
                "label": isEnabled
                    ? pluginApi?.tr("bar.disable")
                    : pluginApi?.tr("bar.enable"),
                "action": "toggle",
                "icon": isEnabled ? "player-pause" : "player-play"
            });
            items.push({
                "label": pluginApi?.tr("bar.settings"),
                "action": "widget-settings",
                "icon": "flask"
            });
            return items;
        }

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (action === "toggle" && mainInstance) {
                mainInstance.setMaxVisible(isEnabled ? 0 : 4);
                const newState = !isEnabled;
                if (pluginApi?.pluginSettings) {
                    pluginApi.pluginSettings.enabled = newState;
                    pluginApi.saveSettings();
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

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi) {
                    pluginApi.togglePanel(root.screen, root);
                }
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen);
            }
        }
    }
}
