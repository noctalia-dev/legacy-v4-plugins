import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null
    property var cfg:      pluginApi?.pluginSettings                      || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string valueAnimationsFolder: cfg.animationsFolder ?? defaults.animationsFolder ?? "~/.config/niri/animations"
    property string valueTargetFile:       cfg.targetFile       ?? defaults.targetFile       ?? "~/.config/niri/animations.kdl"
    property string valueIconColor:        cfg.iconColor        ?? defaults.iconColor        ?? "none"

    spacing: Style.marginL

    ColumnLayout {
        spacing: Style.marginM
        Layout.fillWidth: true

        // Animations folder — use file picker to select a folder
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NLabel {
                label: pluginApi?.tr("settings.animationsFolder.label")
                description: pluginApi?.tr("settings.animationsFolder.description")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: root.valueAnimationsFolder
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                    elide: Text.ElideLeft
                    Layout.fillWidth: true
                }

                NButton {
                    text: pluginApi?.tr("settings.browse")
                    onClicked: animFolderPicker.openFilePicker()
                }
            }

            NFilePicker {
                id: animFolderPicker
                title: pluginApi?.tr("settings.animationsFolder.pickerTitle")
                initialPath: root.valueAnimationsFolder
                selectionMode: "folders"
                onAccepted: paths => {
                    if (paths.length > 0) {
                        root.valueAnimationsFolder = paths[0]
                    }
                }
            }
        }

        // Target KDL file — plain text input since the file may not exist yet
        NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.targetFile.label")
            description: pluginApi?.tr("settings.targetFile.description")
            placeholderText: "~/.config/niri/animations.kdl"
            text: root.valueTargetFile
            onTextChanged: root.valueTargetFile = text
        }

        // Icon color
        NColorChoice {
            label: pluginApi?.tr("settings.iconColor.label")
            description: pluginApi?.tr("settings.iconColor.description")
            currentKey: root.valueIconColor
            onSelected: key => root.valueIconColor = key
        }
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("NiriAnimationPicker", "Cannot save settings: pluginApi is null")
            return
        }
        pluginApi.pluginSettings.animationsFolder = root.valueAnimationsFolder
        pluginApi.pluginSettings.targetFile       = root.valueTargetFile
        pluginApi.pluginSettings.iconColor        = root.valueIconColor
        pluginApi.saveSettings()
        Logger.d("NiriAnimationPicker", "Settings saved")
    }
}
