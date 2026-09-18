import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    // Injected properties
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // Settings
    readonly property var cfg: pluginApi?.pluginSettings || ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string displayMode: cfg.displayMode ?? defaults.displayMode ?? "compact"
    readonly property color offPeakColor: cfg.offPeakColor ?? defaults.offPeakColor ?? "#4ade80"
    readonly property color peakColor: cfg.peakColor ?? defaults.peakColor ?? "#f87171"
    readonly property color driftColor: cfg.driftColor ?? defaults.driftColor ?? "#fbbf24"
    readonly property bool showTooltip: cfg.showTooltip ?? defaults.showTooltip ?? true

    // Shared state (owned by Main.qml)
    readonly property var main: pluginApi?.mainInstance
    readonly property bool isPeak: main ? main.isPeak : false
    readonly property bool drift: main ? main.drift : false
    readonly property string countdownText: main ? main.countdownHMS : "--:--:--"

    readonly property color stateColor: drift ? driftColor : (isPeak ? peakColor : offPeakColor)
    readonly property string stateText: isPeak ? pluginApi?.tr("bar.peak") : pluginApi?.tr("bar.offPeak")
    readonly property string tooltipFormat: (isPeak ? pluginApi?.tr("bar.tooltipPeak") : pluginApi?.tr("bar.tooltipOffPeak")) + " — " + pluginApi?.tr("bar.nextFlip") + " " + countdownText + (drift ? " — " + pluginApi?.tr("bar.driftSuffix") : "")

    // Per-screen bar properties (multi-monitor and vertical bar support)
    readonly property string screenName: screen?.name ?? ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    // Content dimensions follow the bar capsule: the loader extends the
    // click area to full bar height, the visual stays at content size.
    readonly property real contentWidth: contentRow.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: capsuleHeight

    implicitWidth: isBarVertical ? capsuleHeight : contentWidth
    implicitHeight: isBarVertical ? contentWidth : contentHeight

    // Visual capsule - centered within the full click area
    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color: mouseArea.containsMouse ? Qt.lighter(Style.capsuleColor, 1.12) : Style.capsuleColor
        border.color: mouseArea.containsMouse ? root.stateColor : Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginS

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: "circle-filled"
                color: root.stateColor
            }
            NText {
                Layout.alignment: Qt.AlignVCenter
                visible: root.displayMode !== "icon"
                text: root.displayMode === "full" ? root.stateText + " " + root.countdownText : root.countdownText
                pointSize: root.barFontSize
                color: Color.mOnSurface
            }
        }
    }

    // Right-click menu
    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": pluginApi?.tr("menu.settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]
        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);
            if (action === "settings" && pluginApi)
                BarService.openPluginSettings(screen, pluginApi.manifest);
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (root.showTooltip && root.tooltipFormat !== "")
                TooltipService.show(root, root.tooltipFormat, "auto");
        }
        onExited: TooltipService.hide(root)
        onClicked: function (mouse) {
            TooltipService.hide(root);
            if (!pluginApi)
                return;
            if (mouse.button === Qt.LeftButton)
                pluginApi.togglePanel(root.screen, root);
            else if (mouse.button === Qt.RightButton)
                PanelService.showContextMenu(contextMenu, root, screen);
        }
    }
}
