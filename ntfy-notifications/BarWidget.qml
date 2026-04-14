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

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    readonly property var main: pluginApi?.mainInstance
    readonly property int unreadCount: main ? main.unreadCount : 0

    // Track previous count for pulse animation
    property int previousUnreadCount: 0

    implicitWidth: isVertical ? capsuleHeight : contentRow.implicitWidth + Style.marginM * 2
    implicitHeight: isVertical ? capsuleHeight * 1.5 : capsuleHeight

    // Context menu
    NPopupContextMenu {
        id: contextMenu
        model: [
            { "label": pluginApi?.tr("menu.refresh"), "action": "refresh", "icon": "refresh" },
            { "label": pluginApi?.tr("menu.markAllRead"), "action": "markAllRead", "icon": "circle-check" },
            { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
        ]
        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings") {
                BarService.openPluginSettings(root.screen, pluginApi.manifest);
            } else if (action === "refresh" && main) {
                main.pollMessages();
            } else if (action === "markAllRead" && main) {
                main.markAllAsRead();
            }
        }
    }

    Rectangle {
        id: capsule
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        radius: Style.radiusM
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    if (pluginApi) pluginApi.togglePanel(root.screen, root);
                } else if (mouse.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, root, screen);
                }
            }

            onEntered: {
                var text = unreadCount > 0
                    ? pluginApi?.tr("widget.tooltipWithCount", { count: unreadCount })
                    : pluginApi?.tr("widget.tooltip");
                TooltipService.show(root, text, BarService.getTooltipDirection());
            }

            onExited: {
                TooltipService.hide();
            }
        }

        // Horizontal layout
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginXS
            visible: !isVertical

            NIcon {
                icon: "bell"
                width: root.barFontSize * 1.4
                height: width
                color: unreadCount > 0 ? Color.mPrimary : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)
            }

            // Badge
            Rectangle {
                visible: unreadCount > 0
                width: Math.max(badgeText.implicitWidth + Style.marginS * 2, height)
                height: root.barFontSize * 1.3
                radius: height / 2
                color: Color.mPrimary

                NText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: unreadCount > 99 ? "99+" : unreadCount.toString()
                    pointSize: root.barFontSize * 0.7
                    applyUiScale: false
                    color: Color.mOnPrimary
                    font.weight: Style.fontWeightBold
                }

                // Pulse animation on new messages
                SequentialAnimation {
                    id: pulseAnimation
                    loops: 2
                    PropertyAnimation {
                        target: capsule
                        property: "scale"
                        from: 1.0; to: 1.1
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                    PropertyAnimation {
                        target: capsule
                        property: "scale"
                        from: 1.1; to: 1.0
                        duration: 150
                        easing.type: Easing.InQuad
                    }
                }
            }
        }

        // Vertical layout
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Style.marginXXS
            visible: isVertical

            NIcon {
                icon: "bell"
                width: root.barFontSize * 1.4
                height: width
                color: unreadCount > 0 ? Color.mPrimary : (mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface)
                Layout.alignment: Qt.AlignHCenter
            }

            NText {
                visible: unreadCount > 0
                text: unreadCount > 99 ? "99+" : unreadCount.toString()
                pointSize: root.barFontSize * 0.6
                applyUiScale: false
                color: Color.mPrimary
                font.weight: Style.fontWeightBold
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Watch for unread count changes to trigger pulse
    onUnreadCountChanged: {
        if (unreadCount > previousUnreadCount && previousUnreadCount >= 0) {
            pulseAnimation.start();
        }
        previousUnreadCount = unreadCount;
    }
}
