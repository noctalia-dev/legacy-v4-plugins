pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell

import qs.Commons
import qs.Widgets

import "../common"

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true


    /***************************
    * PROPERTIES
    ***************************/
    // Required properties
    required property var    pluginApi
    required property bool   enabled
    required property string selectedMonitor

    // Monitor specific properties
    readonly property bool isMuted:   pluginApi?.pluginSettings?.[selectedMonitor]?.isMuted   ?? false
    readonly property bool isPlaying: pluginApi?.pluginSettings?.[selectedMonitor]?.isPlaying ?? false

    property string currentWallpaper: pluginApi?.pluginSettings?.[selectedMonitor]?.currentWallpaper ?? ""
    property bool   monitorSpecific:  pluginApi?.pluginSettings?.monitorSpecific                     ?? false
    property double volume:           pluginApi?.pluginSettings?.[selectedMonitor]?.volume           ?? pluginApi?.manifest?.metadata?.defaultSettings?.volume ?? 0

    // Global properties
    property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder ?? pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""

    // Signals
    signal saveMonitorProperty(key: string, value: var);


    /***************************
    * EVENTS
    ***************************/
    onSelectedMonitorChanged: {
        // Update the local variables
        currentWallpaper = pluginApi?.pluginSettings?.[selectedMonitor]?.currentWallpaper ?? ""
        volume =           pluginApi?.pluginSettings?.[selectedMonitor]?.volume           ?? pluginApi?.manifest?.metadata?.defaultSettings?.volume ?? 0
    }


    /***************************
    * COMPONENTS
    ***************************/
    // Select Wallpaper
    RowLayout {
        spacing: Style.marginS

        NLabel {
            enabled: root.enabled
            label:       root.pluginApi?.tr("settings.general.select_wallpaper.title.label")
            description: root.pluginApi?.tr("settings.general.select_wallpaper.title.description")
        }

        NIconButton {
            enabled: root.enabled
            icon: "wallpaper-selector"
            tooltipText: root.pluginApi?.tr("settings.general.select_wallpaper.icon_button.tooltip")
            onClicked: currentWallpaperPicker.openFilePicker()
        }

        NFilePicker {
            id: currentWallpaperPicker
            title: root.pluginApi?.tr("settings.general.select_wallpaper.file_picker.title")
            initialPath: root.wallpapersFolder
            selectionMode: "files"

            onAccepted: paths => {
                if (paths.length > 0) {
                    Logger.d("video-wallpaper", "Selected the following current wallpaper:", paths[0]);
                    root.currentWallpaper = paths[0];
                }
            }
        }
    }

    // Volume
    NValueSlider {
        property real _value: root.volume || 1.0

        enabled: root.enabled
        from: 0.0
        to: 1.0
        defaultValue: 1.0
        value: _value
        stepSize: (Settings.data.audio.volumeStep / 100.0)
        text: `${_value * 100.0}%`
        label:       root.pluginApi?.tr("settings.general.volume.label")
        description: root.pluginApi?.tr("settings.general.volume.description")
        onMoved: value => _value = value
        onPressedChanged: (pressed, value) => {
            if(root.pluginApi == null) {
                Logger.e("video-wallpaper", "Plugin API is null.");
                return;
            }

            // When slider is let go
            if (!pressed) {
                root.saveMonitorProperty("volume", value);
                root.pluginApi.saveSettings();
            }
        }
    }

    NDivider {}

    // Tool row
    ToolRow {
        pluginApi: root.pluginApi
        enabled: root.enabled
        monitorSpecific: root.monitorSpecific
        screenName: root.selectedMonitor
    }


    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.currentWallpaper = root.pluginApi?.pluginSettings?.[root.selectedMonitor]?.currentWallpaper ?? ""
            root.volume =           root.pluginApi?.pluginSettings?.[root.selectedMonitor]?.volume           ?? root.pluginApi?.manifest?.metadata?.defaultSettings?.volume ?? 0

            root.wallpapersFolder = root.pluginApi?.pluginSettings?.wallpapersFolde ?? root.pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""
        }
    }

    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(pluginApi == null) {
            Logger.e("video-wallpaper", "Cannot save, pluginApi is null");
            return;
        }

        saveMonitorProperty("currentWallpaper", currentWallpaper);
        saveMonitorProperty("volume", volume);
    }
}
