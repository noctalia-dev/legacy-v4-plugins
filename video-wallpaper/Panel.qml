pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import Quickshell

import qs.Commons
import qs.Widgets
import qs.Services.UI

import "./common"
import "./panel"

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
    readonly property string activeBackend:    pluginApi?.pluginSettings?.activeBackend    ?? pluginApi?.manifest?.metadata?.defaultSettings?.activeBackend ?? ""
    readonly property bool   enabled:          pluginApi?.pluginSettings?.enabled          ?? false
    readonly property bool   monitorSpecific:  pluginApi?.pluginSettings?.monitorSpecific  ?? false
    readonly property bool   thumbCacheReady:  pluginApi?.pluginSettings?.thumbCacheReady  ?? false
    readonly property string wallpapersFolder: pluginApi?.pluginSettings?.wallpapersFolder ?? pluginApi?.manifest?.metadata?.defaultSettings?.wallpapersFolder ?? ""


    /***************************
    * EVENTS
    ***************************/
    onThumbCacheReadyChanged: {
        // When the thumbnail cache is ready, reload the folder model.
        if (thumbCacheReady) {
            folderModel.forceReload();
        }
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
                    text: root.pluginApi?.tr("panel.title")
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
                    text:        root.pluginApi?.tr("panel.tool_row.folder.text")
                    tooltipText: root.pluginApi?.tr("panel.tool_row.folder.tooltip")

                    onClicked: wallpapersFolderPicker.openFilePicker();
                }

                NButton {
                    icon: "refresh"
                    text:        root.pluginApi?.tr("panel.tool_row.refresh.text")
                    tooltipText: root.pluginApi?.tr("panel.tool_row.refresh.tooltip")

                    onClicked: { 
                        if(root.pluginApi.mainInstance == null) {
                            Logger.e("video-wallpaper", "Main instance is null, so can't call thumbRegenerate");
                        }
                        root.pluginApi.mainInstance.thumbRegenerate();
                    }
                }

                NIconButtonHot {
                    icon: "device-desktop"
                    tooltipText: root.pluginApi?.tr("panel.tool_row.monitor_specific.tooltip")

                    hot: root.monitorSpecific

                    visible: Quickshell.screens.length > 1

                    onClicked: {
                        if (root.pluginApi == null) return

                        root.pluginApi.pluginSettings.monitorSpecific = !root.monitorSpecific;
                        root.pluginApi.saveSettings();
                    }
                }

                NToggle {
                    label: root.pluginApi?.tr("panel.tool_row.enabled.label")

                    Layout.fillWidth: false

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

            MonitorTabBar {
                id: tabBar
                currentIndex: tabView.currentIndex
                monitorSpecific: root.monitorSpecific
            }

            MonitorTabView {
                id: tabView
                currentIndex: tabBar.currentIndex

                PerScreenPanel {
                    required property var modelData
                    pluginApi: root.pluginApi
                    thumbCacheReady: root.thumbCacheReady
                    screenName: modelData.name
                }
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
        title: root.pluginApi?.tr("panel.file_picker.title")
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
