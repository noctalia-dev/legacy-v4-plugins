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
    // Monitor specific properties
    readonly property bool isPlaying: pluginApi?.pluginSettings?.[screen.name]?.isPlaying ?? false
    readonly property bool isMuted:   pluginApi?.pluginSettings?.[screen.name]?.isMuted   ?? false

    // Global properties
    readonly property bool enabled:         pluginApi?.pluginSettings?.enabled         ?? false
    readonly property bool monitorSpecific: pluginApi?.pluginSettings?.monitorSpecific ?? false

    /***************************
    * FUNCTIONS
    ***************************/
    function saveMonitorProperty(key: string, value: var): void {
        function createMonitorSettings(monitor) {
            // Check if the monitor settings exist and create it if it doesn't exist
            if (pluginApi.pluginSettings[monitor] === undefined) {
                pluginApi.pluginSettings[monitor] = {};
            }
        }

        if(pluginApi == null) {
            Logger.e("video-wallpaper", "PluginAPI is null.");
            return;
        }

        if (monitorSpecific) {
            createMonitorSettings(screen.name);
            pluginApi.pluginSettings[screen.name][key] = value;
        } else {
            for (const screen of Quickshell.screens) {
                createMonitorSettings(screen.name);
                pluginApi.pluginSettings[screen.name][key] = value;
            }
        }
    }

    /***************************
    * COMPONENTS
    ***************************/
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": root.pluginApi?.tr("barWidget.contextMenu.panel"),
                "action": "panel",
                "icon": "rectangle"
            },
            {
                "label": root.enabled ?
                    root.pluginApi?.tr("barWidget.contextMenu.disable") :
                    root.pluginApi?.tr("barWidget.contextMenu.enable"),
                "action": root.enabled ? "disable" : "enable",
                "icon": "power"
            },
            {
                "label": root.isPlaying ? 
                    root.pluginApi?.tr("barWidget.contextMenu.pause") :
                    root.pluginApi?.tr("barWidget.contextMenu.play"),
                "action": root.isPlaying ? "pause" : "play",
                "icon": root.isPlaying ? "media-pause" : "media-play"
            },
            {
                "label": root.isMuted ? 
                    root.pluginApi?.tr("barWidget.contextMenu.unmute") :
                    root.pluginApi?.tr("barWidget.contextMenu.mute"),
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
                    root.saveMonitorProperty("isPlaying", true);
                    root.pluginApi.saveSettings();
                    break;
                case "pause":
                    root.saveMonitorProperty("isPlaying", false);
                    root.pluginApi.saveSettings();
                    break;
                case "mute":
                    root.saveMonitorProperty("isMuted", true);
                    root.pluginApi.saveSettings();
                    break;
                case "unmute":
                    root.saveMonitorProperty("isMuted", false);
                    root.pluginApi.saveSettings();
                    break;
                case "settings":
                    BarService.openPluginSettings(root.screen, root.pluginApi.manifest);
                    break;
                default:
                    Logger.e("video-wallpaper", "Error, action not found:", action);
            }
        }
    }

    BarPill {
        id: pill

        screen: root.screen
        tooltipText: root.pluginApi?.tr("barWidget.tooltip")

        icon: "wallpaper-selector"

        onClicked: {
            root.pluginApi?.openPanel(root.screen, root);
        }

        onRightClicked: {
            PanelService.showContextMenu(contextMenu, root, root.screen);
        }
    }
}
