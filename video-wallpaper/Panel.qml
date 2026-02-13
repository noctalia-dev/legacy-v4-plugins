pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell

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


    /***************************
    * PROPERTIES
    ***************************/
    readonly property string activeBackend:    pluginApi?.pluginSettings?.activeBackend    || pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend    || ""
    readonly property string currentWallpaper: pluginApi?.pluginSettings?.currentWallpaper || ""
    readonly property bool   enabled:          pluginApi?.pluginSettings?.enabled          || false
    readonly property bool   thumbCacheReady:  pluginApi?.pluginSettings?.thumbCacheReady  || false
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder || pluginApi?.manifest?.metadata?.defaultSettings.wallpapersFolder || ""


    /***************************
    * EVENTS
    ***************************/
    onThumbCacheReadyChanged: {
        // When the thumbnail cache is ready, reload the folder model.
        folderModel.forceReload();
    }


    /***************************
    * COMPONENTS
    ***************************/
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
                    text: root.pluginApi?.tr("panel.title") || "Video wallpaper manager"
                    pointSize: Style.fontSizeXL
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "x"
                    onClicked: root.pluginApi?.closePanel(root.pluginApi.panelOpenScreen);
                }
            }

            // Tool row
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NButton {
                    icon: "wallpaper-selector"
                    text: root.pluginApi?.tr("panel.tool_row.folder.text") || "Folder"
                    tooltipText: root.pluginApi?.tr("panel.tool_row.folder.tooltip") || "Choose another folder that contains your wallpapers."

                    onClicked: wallpapersFolderPicker.openFilePicker();
                }

                NButton {
                    icon: "refresh"
                    text: root.pluginApi?.tr("panel.tool_row.refresh.text") || "Refresh"
                    tooltipText: root.pluginApi?.tr("panel.tool_row.refresh.tooltip") || "Refresh thumbnails, remove old ones and create new ones."

                    onClicked: { 
                        if(root.pluginApi.mainInstance == null) {
                            Logger.e("video-wallpaper", "Main instance is null, so can't call thumbRegenerate");
                        }
                        root.pluginApi.mainInstance.thumbRegenerate();
                    }
                }

                NToggle {
                    label: "Enabled"

                    checked: root.enabled
                    onToggled: checked => {
                        if(root.pluginApi == null) return;

                        root.pluginApi.pluginSettings.enabled = checked;
                        root.pluginApi.saveSettings();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                NLabel {
                    label: `Using: ${root.activeBackend}`
                }
            }

            // Wallpapers folder content
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Color.mSurfaceVariant;
                radius: Style.radiusS;

                ColumnLayout {
                    anchors.fill: parent
                    visible: !root.thumbCacheReady
                    spacing: Style.marginS

                    NText {
                        text: root.pluginApi?.tr("panel.loading") || "Loading..."
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

                        model: folderModel.ready && root.thumbCacheReady ? folderModel.files : 0

                        // Wallpaper
                        delegate: Item {
                            id: wallpaper
                            required property string modelData
                            width: gridView.cellWidth
                            height: gridView.cellHeight

                            NImageRounded {
                                id: wallpaperImage
                                anchors {
                                    fill: parent
                                    margins: Style.marginXXS
                                }

                                radius: Style.radiusXS

                                borderWidth: {
                                    if (root.thumbCacheReady && root.currentWallpaper == wallpaper.modelData) return Style.borderM;
                                    else return 0;
                                }
                                borderColor: Color.mPrimary;

                                imagePath: {
                                    if (root.thumbCacheReady && root.pluginApi.mainInstance != null) return root.pluginApi.mainInstance.getThumbPath(wallpaper.modelData);
                                    else return "";
                                }
                                fallbackIcon: "alert-circle"

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent

                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true;

                                    onClicked: {
                                        if(root.pluginApi.mainInstance == null) {
                                            Logger.d("video-wallpaper", "Can't change background because pluginApi or main instance doesn't exist!");
                                            return;
                                        }

                                        root.pluginApi.pluginSettings.currentWallpaper = wallpaper.modelData;
                                        root.pluginApi.saveSettings();
                                    }

                                    onEntered: TooltipService.show(wallpaperImage, wallpaper.modelData, "auto", 100);
                                    onExited: TooltipService.hideImmediately();
                                }
                            }
                        }
                    }

                }
            }

            ToolRow {
                pluginApi: root.pluginApi
            }
        }
    }

    FolderModel {
        id: folderModel
        folder: root.wallpapersFolder
        filters: ["*.mp4", "*.avi", "*.mov"]
    }

    NFilePicker {
        id: wallpapersFolderPicker
        title: root.pluginApi?.tr("panel.file_picker.title") || "Choose wallpapers folder"
        initialPath: root.wallpapersFolder
        selectionMode: "folders"

        onAccepted: paths => {
            if (paths.length > 0 && root.pluginApi != null) {
                Logger.d("video-wallpaper", "Selected the following wallpaper folder:", paths[0]);

                root.pluginApi.pluginSettings.wallpapersFolder = paths[0];
                root.pluginApi.saveSettings();
            }
        }
    }
}
