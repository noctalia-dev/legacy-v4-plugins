import QtQuick
import Quickshell
import qs.Commons
import qs.Services.Keyboard
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen

    baseSize: (typeof Style !== "undefined" && screen) ? Style.getCapsuleHeightForScreen(screen.name) : 31
    applyUiScale: false
    icon: "clipboard"
    tooltipText: "Clipboard History" // TODO: I18n
    tooltipDirection: BarService.getTooltipDirection()
    
    colorBg: (typeof Style !== "undefined") ? Style.capsuleColor : "#262130"
    colorFg: (typeof Color !== "undefined" && Color.mOnSurface) ? Color.mOnSurface : "#e9e4f0"
    colorBorder: "transparent"
    colorBorderHover: "transparent"

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": I18n.tr("context-menu.clear-history"),
                "action": "clear-history",
                "icon": "trash"
            },
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "clear-history") {
                ClipboardService.wipeAll();
            }
        }
    }

    onClicked: {
        if (pluginApi) {
            pluginApi.openPanel(screen);
        }
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen);
    }
}