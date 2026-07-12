import QtQuick
import QtQuick.Layouts
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

    readonly property bool isAvailable: mainInstance?.isAvailable ?? false
    readonly property string currentProfile: mainInstance?.profileService?.activeProfile ?? ""
    readonly property int batteryLimit: mainInstance?.batteryService?.chargeLimit ?? -1

    readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)

    readonly property real contentWidth: contentRow.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: capsuleHeight

    implicitWidth: isVertical ? capsuleHeight : contentWidth
    implicitHeight: isVertical ? contentHeight : capsuleHeight

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // Profile-based icon
    function getProfileIcon() {
        if (!isAvailable) return "error";
        var p = currentProfile.toLowerCase();
        if (p === "performance") return "gauge";
        if (p === "quiet") return "leaf";
        return "scale"; // balanced
    }

    function getProfileLabel() {
        if (!isAvailable) return "N/A";
        return currentProfile;
    }

    // Profile-based color
    property color profileColor: {
        if (!isAvailable) return Color.mError;
        var p = currentProfile.toLowerCase();
        if (p === "performance") return Color.mError;
        if (p === "quiet") return Color.mSecondary;
        return Color.mPrimary;
    }

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

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            NIcon {
                icon: root.getProfileIcon()
                applyUiScale: false
                color: mouseArea.containsMouse ? Color.mOnHover : root.profileColor
            }

            NText {
                visible: root.isAvailable && root.currentProfile.length > 0
                text: root.getProfileLabel()
                pointSize: root.barFontSize
                font.weight: Font.DemiBold
                color: mouseArea.containsMouse ? Color.mOnHover : root.profileColor
            }

            NIcon {
                visible: root.batteryLimit > 0 && root.batteryLimit < 100
                icon: "charging-pile"
                applyUiScale: false
                color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurfaceVariant
            }
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.settings") || "Settings", "action": "settings", "icon": "settings" },
            { "label": pluginApi?.tr("menu.refresh") || "Refresh", "action": "refresh", "icon": "refresh" }
        ]
        onTriggered: function(action) {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (action === "refresh") {
                if (mainInstance) mainInstance.refreshAll();
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                if (pluginApi) pluginApi.openPanel(root.screen, root);
            } else if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen);
            }
        }
    }
}
