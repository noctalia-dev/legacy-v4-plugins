pragma ComponentBehavior: Bound
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Widgets
import qs.Services.UI

import "./common"

Item {
    id: root
    
    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 1000 * Style.uiScaleRatio
    property real contentPreferredHeight: 700 * Style.uiScaleRatio

    readonly property bool thumbCacheReady: pluginApi?.mainInstance.thumbCacheReady || false

    readonly property bool active: 
        pluginApi.pluginSettings.active || 
        false

    readonly property string wallpapersFolder: 
        pluginApi.pluginSettings.wallpapersFolder || 
        pluginApi.manifest.metadata.defaultSettings.wallpapersFolder || 
        "~/Pictures/Wallpapers"

    readonly property string currentWallpaper: 
        pluginApi.pluginSettings.currentWallpaper || 
        ""


    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                    text: pluginApi?.tr("panel.title") || "Configure mpvpaper"
                    pointSize: Style.fontSizeXL
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "x"
                    onClicked: {
                        pluginApi.closePanel(pluginApi.panelOpenScreen);
                    }
                }
            }

            // Tool row
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    icon: "wallpaper-selector"
                    text: pluginApi?.tr("panel.buttons.folder.text") || "Folder"
                    tooltipText: pluginApi?.tr("panel.buttons.folder.tooltip") || "Choose another folder that contains your wallpapers."

                    onClicked: wallpapersFolderPicker.openFilePicker();
                }

                NButton {
                    icon: "refresh"
                    text: pluginApi?.tr("panel.buttons.refresh.text") || "Refresh"
                    tooltipText: pluginApi?.tr("panel.buttons.refresh.tooltip") || "Refresh thumbnails, remove old ones and create new ones."

                    onClicked: pluginApi?.mainInstance.thumbRegenerate();
                }
            }

            // Wallpapers folder content
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Color.mSurfaceVariant;
                radius: Style.iRadiusS;

                ColumnLayout {
                    anchors.fill: parent
                    visible: !root.thumbCacheReady
                    spacing: Style.marginS

                    NText {
                        text: pluginApi?.tr("panel.loading") || "Loading..."
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        pointSize: Style.fontSizeL
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    visible: root.thumbCacheReady
                    spacing: Style.marginS

                    NGridView {
                        id: gridView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: Style.marginXXS

                        property int columns: Math.max(1, Math.floor(availableWidth / 300));
                        property int itemSize: Math.floor(availableWidth / columns)

                        cellWidth: itemSize
                        // For now all wallpapers are shown in a 16:9 ratio
                        cellHeight: Math.floor(itemSize * (9/16))

                        model: wallpapersFolderModel.status == FolderListModel.Ready && root.thumbCacheReady ? wallpapersFolderModel : 0

                        // Wallpaper
                        delegate: Item {
                            id: wallpaper
                            required property int index
                            width: gridView.cellWidth
                            height: gridView.cellHeight

                            readonly property var path: wallpapersFolderModel.get(index, "filePath");

                            NImageRounded {
                                id: wallpaperImage
                                anchors {
                                    fill: parent
                                    margins: Style.marginXXS
                                }

                                radius: Style.iRadiusXS

                                borderWidth: root.thumbCacheReady && root.currentWallpaper == wallpapersFolderModel.get(index, "filePath") ? Style.borderM : 0
                                borderColor: Color.mPrimary;

                                imagePath: root.thumbCacheReady ? pluginApi.mainInstance.getThumbUrl(wallpaper.path) : "";
                                fallbackIcon: "alert-circle"

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent

                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true;

                                    onClicked: {
                                        if(!pluginApi?.mainInstance) {
                                            Logger.d("mpvpaper", "Can't change background because pluginApi or main instance doesn't exist!");
                                            return;
                                        }

                                        pluginApi.mainInstance.setWallpaper(wallpaper.path);
                                    }

                                    onEntered: TooltipService.show(wallpaperImage, wallpaper.path, "auto", 100);
                                    onExited: TooltipService.hideImmediately();
                                }
                            }
                        }
                    }

                    FolderListModel {
                        id: wallpapersFolderModel
                        folder: root.pluginApi == null ? "" : "file://" + root.wallpapersFolder
                        nameFilters: ["*.mp4", "*.avi", "*.mov"]
                        showDirs: false
                    }
                }
            }

            ToolRow {
                pluginApi: root.pluginApi
            }
        }
    }


    NFilePicker {
        id: wallpapersFolderPicker
        title: pluginApi?.tr("settings.wallpapers_folder.file_picker_title") || "Choose wallpapers folder"
        initialPath: root.wallpapersFolder
        selectionMode: "folders"

        onAccepted: paths => {
            if (paths.length > 0 && pluginApi != null) {
                Logger.d("mpvpaper", "Selected the following wallpaper folder:", paths[0]);

                pluginApi.pluginSettings.wallpapersFolder = paths[0];
                pluginApi.saveSettings();
            }
        }
    }
}
