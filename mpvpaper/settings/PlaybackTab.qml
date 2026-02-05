import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true

    required property var pluginApi
    required property bool active

    readonly property bool isPlaying: 
        pluginApi.pluginSettings.isPlaying ||
        false


    property string wallpapersFolder: 
        pluginApi?.pluginSettings?.wallpapersFolder ||
        pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ||
        "~/Pictures/Wallpapers"

    property string currentWallpaper: 
        pluginApi?.pluginSettings?.currentWallpaper || 
        ""


    // Wallpaper Folder
    ColumnLayout {
        spacing: Style.marginS

        NLabel {
            enabled: root.active
            label: pluginApi?.tr("settings.wallpapers_folder.title_label") || "Wallpapers Folder"
            description: pluginApi?.tr("settings.wallpapers_folder.title_description") || "The folder that contains all the wallpapers, useful when using random wallpaper"
        }

        RowLayout {
            spacing: Style.marginS

            NTextInput {
                enabled: root.active
                Layout.fillWidth: true
                placeholderText: pluginApi?.tr("settings.wallpapers_folder.input_placeholder") || "/path/to/folder/with/wallpapers"
                text: root.wallpapersFolder
                onTextChanged: root.wallpapersFolder = text
            }

            NIconButton {
                enabled: root.active
                icon: "wallpaper-selector"
                tooltipText: pluginApi?.tr("settings.wallpapers_folder.icon_tooltip") || "Select wallpapers folder"
                onClicked: wallpapersFolderPicker.openFilePicker()
            }

            NFilePicker {
                id: wallpapersFolderPicker
                title: pluginApi?.tr("settings.wallpapers_folder.file_picker_title") || "Choose wallpapers folder"
                initialPath: root.wallpapersFolder
                selectionMode: "folders"

                onAccepted: paths => {
                    if (paths.length > 0) {
                        Logger.d("mpvpaper", "Selected the following wallpaper folder:", paths[0]);
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
            enabled: root.active
            label: pluginApi?.tr("settings.select_wallpaper.title_label") || "Select Wallpaper"
            description: pluginApi?.tr("settings.select_wallpaper.title_description") || "Choose the current video wallpaper playing."
        }

        NIconButton {
            enabled: root.active
            icon: "wallpaper-selector"
            tooltipText: pluginApi?.tr("settings.select_wallpaper.icon_tooltip") || "Select current wallpaper"
            onClicked: currentWallpaperPicker.openFilePicker()
        }

        NFilePicker {
            id: currentWallpaperPicker
            title: pluginApi?.tr("settings.select_wallpaper.file_picker_title") || "Choose current wallpaper"
            initialPath: root.wallpapersFolder
            selectionMode: "files"

            onAccepted: paths => {
                if (paths.length > 0) {
                    Logger.d("mpvpaper", "Selected the following current wallpaper:", paths[0]);
                    root.currentWallpaper = paths[0];
                }
            }
        }
    }

    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.wallpapersFolder = root.pluginApi.pluginSettings.wallpapersFolder || "~/Pictures/Wallpapers";
            root.currentWallpaper = root.pluginApi.pluginSettings.currentWallpaper || "";
        }
    }

    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("mpvpaper", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.wallpapersFolder = wallpapersFolder;
        pluginApi.pluginSettings.currentWallpaper = currentWallpaper;
    }
}
