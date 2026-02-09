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

    readonly property bool isMuted:     pluginApi.pluginSettings.isMuted    || false
    readonly property bool isPlaying:   pluginApi.pluginSettings.isPlaying  || false

    property string currentWallpaper:   pluginApi.pluginSettings.currentWallpaper   || ""
    property int    fillMode:           pluginApi.pluginSettings.fillMode           || 0
    property int    orientation:        pluginApi.pluginSettings.orientation        || 0
    property double volume:             pluginApi.pluginSettings.volume             || 1.0
    property string wallpapersFolder:   pluginApi.pluginSettings.wallpapersFolder   || "~/Pictures/Wallpapers"


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

    // Fill Mode
    NComboBox {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.general.fill_mode.label") || "Fill Mode"
        description: root.pluginApi?.tr("settings.general.fill_mode.description") || "The mode that the wallpaper is fitted into the background."
        defaultValue: "0"
        model: [
            {
                "key": "0",
                "name": root.pluginApi?.tr("settings.general.fill_mode.stretch") || "Stretch"
            },
            {
                "key": "1",
                "name": root.pluginApi?.tr("settings.general.fill_mode.fit") || "Fit"
            },
            {
                "key": "2",
                "name": root.pluginApi?.tr("settings.general.fill_mode.crop") || "Crop"
            }
        ]
        currentKey: root.fillMode
        onSelected: key => root.fillMode = key
    }

    // Orientation
    NValueSlider {
        property real _value: root.orientation

        enabled: root.enabled
        from: -270
        to: 270
        value: root.orientation
        defaultValue: 0
        stepSize: 90
        text: _value
        label: root.pluginApi?.tr("settings.general.orientation.label") || "Orientation"
        description: root.pluginApi?.tr("settings.general.orientation.description") || "The orientation of the video playing, can be any multiple of 90."
        onMoved: value => _value = value
        onPressedChanged: (pressed, value) => {
            if(root.pluginApi == null) {
                Logger.e("video-wallpaper", "Plugin API is null.");
                return
            }

            if(!pressed) {
                root.pluginApi.pluginSettings.orientation = value;
                root.pluginApi.saveSettings();
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
            currentWallpaper =  pluginApi.pluginSettings.currentWallpaper   || ""
            fillMode =          pluginApi.pluginSettings.fillMode           || 0
            orientation =       pluginApi.pluginSettings.orientation        || 0
            volume =            pluginApi.pluginSettings.volume             || 1.0
            wallpapersFolder =  pluginApi.pluginSettings.wallpapersFolder   || "~/Pictures/Wallpapers"
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

        pluginApi.pluginSettings.currentWallpaper = currentWallpaper;
        pluginApi.pluginSettings.fillMode = fillMode;
        pluginApi.pluginSettings.orientation = orientation;
        pluginApi.pluginSettings.volume = volume;
        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;
    }
}
