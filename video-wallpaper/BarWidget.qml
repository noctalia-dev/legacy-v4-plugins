import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null

    property ShellScreen screen

    implicitWidth: pill.width
    implicitHeight: pill.height


    /***************************
    * PROPERTIES
    ***************************/
    readonly property bool enabled:     pluginApi.pluginSettings.enabled    || false
    readonly property bool isPlaying:   pluginApi.pluginSettings.isPlaying  || false
    readonly property bool isMuted:     pluginApi.pluginSettings.isMuted    || false


    /***************************
    * COMPONENTS
    ***************************/
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": root.pluginApi?.tr("barWidget.contextMenu.panel") || "Panel",
                "action": "panel",
                "icon": "rectangle"
            },
            {
                "label": root.enabled ?
                    root.pluginApi?.tr("barWidget.contextMenu.disable") || "Disable" :
                    root.pluginApi?.tr("barWidget.contextMenu.enable") || "Enable",
                "action": root.enabled ? "disable" : "enable",
                "icon": "power"
            },
            {
                "label": root.isPlaying ? 
                    root.pluginApi?.tr("barWidget.contextMenu.pause") || "Pause" : 
                    root.pluginApi?.tr("barWidget.contextMenu.play") || "Play",
                "action": root.isPlaying ? "pause" : "play",
                "icon": root.isPlaying ? "media-pause" : "media-play"
            },
            {
                "label": root.isMuted ? 
                    root.pluginApi?.tr("barWidget.contextMenu.unmute") || "Unmute" : 
                    root.pluginApi?.tr("barWidget.contextMenu.mute") || "Mute",
                "action": root.isMuted ? "unmute" : "mute",
                "icon": root.isMuted ? "volume-high" : "volume-mute"
            },
            {
                "label": I18n.tr("actions.widget-settings"),
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);

            switch(action) {
                case "panel":
                    root.pluginApi?.openPanel(root.screen, root);
                    break;
                case "enable":
                    root.pluginApi.pluginSettings.enabled = true;
                    root.pluginApi.saveSettings();
                    break;
                case "disable":
                    root.pluginApi.pluginSettings.enabled = false;
                    root.pluginApi.saveSettings();
                    break;
                case "play":
                    root.pluginApi.pluginSettings.isPlaying = true;
                    root.pluginApi.saveSettings();
                    break;
                case "pause":
                    root.pluginApi.pluginSettings.isPlaying = false;
                    root.pluginApi.saveSettings();
                    break;
                case "mute":
                    root.pluginApi.pluginSettings.isMuted = true;
                    root.pluginApi.saveSettings();
                    break;
                case "unmute":
                    root.pluginApi.pluginSettings.isMuted = false;
                    root.pluginApi.saveSettings();
                    break;
                    case "settings":
                    BarService.openPluginSettings(root.screen, pluginApi.manifest);
                    break;
                default:
                    Logger.e("video-wallpaper", "Error, action not found:", action);
            }
        }
    }

    BarPill {
        id: pill

        screen: root.screen
        tooltipText: root.pluginApi?.tr("barWidget.tooltip") || "Open the video wallpaper manager."

        icon: "wallpaper-selector"

        onClicked: {
            pluginApi?.openPanel(root.screen, root);
        }

        onRightClicked: {
            PanelService.showContextMenu(contextMenu, root, screen);
        }
    }
}
