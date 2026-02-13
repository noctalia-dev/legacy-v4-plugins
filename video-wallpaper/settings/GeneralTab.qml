import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true


    /***************************
    * PROPERTIES
    ***************************/
    required property var pluginApi
    required property bool enabled

    readonly property bool  isMuted:   pluginApi?.pluginSettings?.isMuted   || false
    readonly property bool  isPlaying: pluginApi?.pluginSettings?.isPlaying || false

    property string currentWallpaper:   pluginApi?.pluginSettings?.currentWallpaper   || ""
    property double volume:             pluginApi?.pluginSettings?.volume             || pluginApi?.manifest?.metadata?.defaultSettings?.volume           || 0
    property string wallpapersFolder:   pluginApi?.pluginSettings?.wallpapersFolder   || pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""


    /***************************
    * COMPONENTS
    ***************************/
    // Wallpaper Folder
    ColumnLayout {
        spacing: Style.marginS

        NLabel {
            enabled: root.enabled
            label: root.pluginApi?.tr("settings.general.wallpapers_folder.title.label") || "Wallpapers Folder"
            description: root.pluginApi?.tr("settings.general.wallpapers_folder.title.description") || "The folder that contains all the wallpapers, useful when using random wallpaper"
        }

        RowLayout {
            spacing: Style.marginS

            NTextInput {
                enabled: root.enabled
                Layout.fillWidth: true
                placeholderText: root.pluginApi?.tr("settings.general.wallpapers_folder.text_input.placeholder") || "/path/to/folder/with/wallpapers"
                text: root.wallpapersFolder
                onTextChanged: root.wallpapersFolder = text
            }

            NIconButton {
                enabled: root.enabled
                icon: "wallpaper-selector"
                tooltipText: root.pluginApi?.tr("settings.general.wallpapers_folder.icon_button.tooltip") || "Select wallpapers folder"
                onClicked: wallpapersFolderPicker.openFilePicker()
            }

            NFilePicker {
                id: wallpapersFolderPicker
                title: root.pluginApi?.tr("settings.general.wallpapers_folder.file_picker.title") || "Choose wallpapers folder"
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

    // Select Wallpaper
    RowLayout {
        spacing: Style.marginS

        NLabel {
            enabled: root.enabled
            label: root.pluginApi?.tr("settings.general.select_wallpaper.title.label") || "Select Wallpaper"
            description: root.pluginApi?.tr("settings.general.select_wallpaper.title.description") || "Choose the current video wallpaper playing."
        }

        NIconButton {
            enabled: root.enabled
            icon: "wallpaper-selector"
            tooltipText: root.pluginApi?.tr("settings.general.select_wallpaper.icon_button.tooltip") || "Select current wallpaper"
            onClicked: currentWallpaperPicker.openFilePicker()
        }

        NFilePicker {
            id: currentWallpaperPicker
            title: root.pluginApi?.tr("settings.general.select_wallpaper.file_picker.title") || "Choose current wallpaper"
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

    NDivider {}

    // Volume
    NValueSlider {
        property real _value: root.volume

        enabled: root.enabled
        from: 0.0
        to: 1.0
        defaultValue: 1.0
        value: root.volume
        stepSize: (Settings.data.audio.volumeStep / 100.0)
        text: `${_value * 100.0}%`
        label: root.pluginApi?.tr("settings.general.volume.label") || "Volume"
        description: root.pluginApi?.tr("settings.general.volume.description") || "The current volume of the video playing."
        onMoved: value => _value = value
        onPressedChanged: (pressed, value) => {
            if(root.pluginApi == null) {
                Logger.e("video-wallpaper", "Plugin API is null.");
                return;
            }

            // When slider is let go
            if (!pressed) {
                root.pluginApi.pluginSettings.volume = value;
                root.pluginApi.saveSettings();
            }
        }
    }

    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.currentWallpaper = root.pluginApi?.pluginSettings?.currentWallpaper   || ""
            root.volume =           root.pluginApi?.pluginSettings?.volume             || root.pluginApi?.manifest?.metadata?.defaultSettings?.volume           || 0
            root.wallpapersFolder = root.pluginApi?.pluginSettings?.wallpapersFolder   || root.pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder || ""
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

        pluginApi.pluginSettings.currentWallpaper = currentWallpaper;
        pluginApi.pluginSettings.volume = volume;
        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;
    }
}
