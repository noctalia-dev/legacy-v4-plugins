import QtQuick
import QtQuick.Layouts

import Quickshell

import qs.Commons
import qs.Widgets

import "./common"
import "./settings"

ColumnLayout {
    id: root
    property var pluginApi: null

    spacing: Style.marginM


    /***************************
    * PROPERTIES
    ***************************/
    property string activeBackend:    pluginApi?.pluginSettings?.activeBackend    ?? pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend ?? ""
    property bool   enabled:          pluginApi?.pluginSettings?.enabled          ?? false
    property bool   monitorSpecific:  pluginApi?.pluginSettings?.monitorSpecific  ?? false
    property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder ?? pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""


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
            createMonitorSettings(monitorTabBar.selectedMonitor);
            pluginApi.pluginSettings[monitorTabBar.selectedMonitor][key] = value;
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
    // Active toggle
    NToggle {
        label:       root.pluginApi?.tr("settings.toggle.label")
        description: root.pluginApi?.tr("settings.toggle.description")
        checked: root.enabled
        onToggled: checked => root.enabled = checked
    }

    NToggle {
        visible: Quickshell.screens.length > 1
        label:       root.pluginApi?.tr("settings.monitor_specific.label")
        description: root.pluginApi?.tr("settings.monitor_specific.description")
        checked: root.monitorSpecific
        onToggled: checked => root.monitorSpecific = checked
    }

    NComboBox {
        enabled: root.enabled
        Layout.fillWidth: true
        label:       root.pluginApi?.tr("settings.backend.label")
        description: root.pluginApi?.tr("settings.backend.description")
        defaultValue: "qt6-multimedia"
        model: [
            {
                "key": "qt6-multimedia",
                "name": root.pluginApi?.tr("settings.backend.qt6_multimedia")
            },
            {
                "key": "mpvpaper",
                "name": root.pluginApi?.tr("settings.backend.mpvpaper")
            }
        ]
        currentKey: root.activeBackend
        onSelected: key => root.activeBackend = key
    }

    // Wallpapers Folder
    ColumnLayout {
        spacing: Style.marginS

        NLabel {
            enabled: root.enabled
            label:       root.pluginApi?.tr("settings.general.wallpapers_folder.title.label")
            description: root.pluginApi?.tr("settings.general.wallpapers_folder.title.description")
        }

        RowLayout {
            spacing: Style.marginS

            NTextInput {
                enabled: root.enabled
                placeholderText: root.pluginApi?.tr("settings.general.wallpapers_folder.text_input.placeholder")
                text: root.wallpapersFolder
                onTextChanged: root.wallpapersFolder = text
            }

            NIconButton {
                enabled: root.enabled
                icon: "wallpaper-selector"
                tooltipText: root.pluginApi?.tr("settings.general.wallpapers_folder.icon_button.tooltip")
                onClicked: wallpapersFolderPicker.openFilePicker()
            }

            NFilePicker {
                id: wallpapersFolderPicker
                title: root.pluginApi?.tr("settings.general.wallpapers_folder.file_picker.title")
                initialPath: root.wallpapersFolder
                selectionMode: "folders"

                onAccepted: paths => {
                    if (paths.length > 0) {
                        Logger.d("video-wallpaper", "Selected the following wallpaper folder:", paths[0]);
                        root.wallpapersFolder = paths[0];
                    }
                }
            }
        }
    }

    NDivider {}


    MonitorTabBar {
        id: monitorTabBar

        enabled: root.enabled
        monitorSpecific: root.monitorSpecific

        property string selectedMonitor: Quickshell.screens[0].name

        onCurrentIndexChanged: {
            selectedMonitor = Quickshell.screens[currentIndex].name
        }
    }

    // Tab bar with all the settings menus
    NTabBar {
        id: tabBar
        Layout.fillWidth: true
        distributeEvenly: true
        currentIndex: tabView.currentIndex

        NTabButton {
            enabled: root.enabled
            text: pluginApi?.tr("settings.tab_bar.general")
            tabIndex: 0
            checked: tabBar.currentIndex === 0
        }
        NTabButton {
            enabled: root.enabled
            text: pluginApi?.tr("settings.tab_bar.automation")
            tabIndex: 1
            checked: tabBar.currentIndex === 1
        }
        NTabButton {
            enabled: root.enabled
            text: pluginApi?.tr("settings.tab_bar.advanced")
            tabIndex: 2
            checked: tabBar.currentIndex === 2
        }
    }

    // The menu shown
    NTabView {
        id: tabView
        currentIndex: tabBar.currentIndex

        GeneralTab {
            id: general
            pluginApi: root.pluginApi
            enabled: root.enabled
            selectedMonitor: monitorTabBar.selectedMonitor

            onSaveMonitorProperty: (key, value) => root.saveMonitorProperty(key, value);
        }

        AutomationTab {
            id: automation
            pluginApi: root.pluginApi
            enabled: root.enabled
            selectedMonitor: monitorTabBar.selectedMonitor

            onSaveMonitorProperty: (key, value) => root.saveMonitorProperty(key, value);
        }

        AdvancedTab {
            id: advanced
            pluginApi: root.pluginApi
            activeBackend: root.activeBackend
            enabled: root.enabled
            selectedMonitor: monitorTabBar.selectedMonitor

            onSaveMonitorProperty: (key, value) => root.saveMonitorProperty(key, value);
        }
    }

    Connections {
        target: root.pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.activeBackend =    root.pluginApi?.pluginSettings?.activeBackend    ?? root.pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend ?? ""
            root.enabled =          root.pluginApi?.pluginSettings?.enabled          ?? false
            root.monitorSpecific =  root.pluginApi?.pluginSettings?.monitorSpecific  ?? false
            root.wallpapersFolder = root.pluginApi?.pluginSettings?.wallpapersFolder ?? root.pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""
        }
    }

    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("video-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.activeBackend = activeBackend;
        pluginApi.pluginSettings.enabled = enabled;
        pluginApi.pluginSettings.monitorSpecific = monitorSpecific;
        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;

        general.saveSettings();
        automation.saveSettings();
        advanced.saveSettings();

        pluginApi.saveSettings();
    }
}
