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

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
    readonly property bool fortuneEnabled: cfg.fortuneEnabled ?? defaults.fortuneEnabled ?? false
    readonly property bool listEnabled: cfg.listEnabled ?? defaults.listEnabled ?? false
    property string displayText: fortuneEnabled
        ? (pluginApi?.mainInstance?.fortuneText ?? "")
        : listEnabled
            ? (pluginApi?.mainInstance?.listText ?? "")
            : (cfg.text ?? defaults.text ?? "")

    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    readonly property real contentWidth: isVertical ? capsuleHeight : label.implicitWidth + Style.marginL * 2
    readonly property real contentHeight: capsuleHeight

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

        Text {
            id: label
            anchors.centerIn: parent
            text: root.displayText
            color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
            font.pointSize: Style.barFontSize
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
        ]
        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
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
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen);
            }
        }
    }
}
