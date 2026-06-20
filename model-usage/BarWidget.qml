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
    property var activeProvider: mainInstance?.activeProvider

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    property string barMetric: mainInstance?.barMetric ?? "prompts"

    property string displayText: {
        if (!activeProvider)
            return "\u2014";
        if (barMetric === "usage") {
            const rl = activeProvider.rateLimitPercent ?? -1;
            const rl2 = activeProvider.secondaryRateLimitPercent ?? -1;
            if (!(rl >= 0)) {
                const status = String(activeProvider.usageStatusText ?? "");
                if (status !== "")
                    return status;
                return "\u2014";
            }
            let text = Math.round(rl * 100) + "%";
            if (rl2 >= 0) {
                text += "·" + Math.round(rl2 * 100) + "%";
            }
            return text;
        }
        if (barMetric === "tokens")
            return mainInstance?.formatTokenCount(activeProvider.todayTotalTokens) ?? "0";
        return String(activeProvider.todayPrompts);
    }

    property string tooltipText: {
        if (!activeProvider)
            return "Model Usage";
        const name = activeProvider.providerName;
        const prompts = activeProvider.todayPrompts;
        const sess = activeProvider.todaySessions;
        const tokens = mainInstance?.formatTokenCount(activeProvider.todayTotalTokens) ?? "0";
        let tip = name + " \u2014 Today: " + prompts + " prompts, " + sess + " sessions, " + tokens + " tokens";
        
        const rl = activeProvider.rateLimitPercent;
        const rl2 = activeProvider.secondaryRateLimitPercent;
        
        if (rl >= 0) {
            tip += " \u00b7 " + activeProvider.rateLimitLabel + ": " + Math.round(rl * 100) + "%";
            if (rl2 >= 0) {
                tip += " \u00b7 " + activeProvider.secondaryRateLimitLabel + ": " + Math.round(rl2 * 100) + "%";
            }
        } else if ((activeProvider.usageStatusText ?? "") !== "") {
            tip += " \u00b7 " + activeProvider.usageStatusText;
        }
        return tip;
    }

    readonly property real contentWidth: isBarVertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: isBarVertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight

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
            },
        ]

        onTriggered: (action, item) => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);
            if (action === "refresh") {
                mainInstance?.refresh();
            }
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

        Item {
            id: content
            anchors.centerIn: parent
            implicitWidth: rowLayout.visible ? rowLayout.implicitWidth : colLayout.implicitWidth
            implicitHeight: rowLayout.visible ? rowLayout.implicitHeight : colLayout.implicitHeight

            RowLayout {
                id: rowLayout
                visible: !root.isBarVertical
                spacing: Style.marginS

                NIcon {
                    icon: root.activeProvider?.providerIcon ?? "ai"
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: Color.mPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                NText {
                    text: root.displayText
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            ColumnLayout {
                id: colLayout
                visible: root.isBarVertical
                spacing: Style.marginXS

                NIcon {
                    icon: root.activeProvider?.providerIcon ?? "ai"
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: Color.mPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                NText {
                    text: root.displayText
                    pointSize: root.barFontSize
                    applyUiScale: false
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignHCenter
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
                TooltipService.hide();
                pluginApi?.togglePanel(root.screen, root);
            } else if (mouse.button === Qt.RightButton) {
                TooltipService.hide();
                PanelService.showContextMenu(contextMenu, root, root.screen);
            }
        }

        onEntered: {
            TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName));
        }

        onExited: {
            TooltipService.hide();
        }
    }
}
