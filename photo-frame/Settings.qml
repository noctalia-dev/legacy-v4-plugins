import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    spacing: Style.marginL

    property var cfg: pluginApi?.pluginSettings ?? ({})
    property string localImageSource:   cfg.imageSource ?? ""
    property bool   localTransparentBg: cfg.transparentBg ?? false

    function saveSettings() {
        if (!pluginApi)
            return

        pluginApi.pluginSettings.imageSource = localImageSource
        pluginApi.pluginSettings.transparentBg = localTransparentBg
        pluginApi.saveSettings()
    }

    Component.onDestruction: saveSettings()

    function normalizeImagePath(path) {
        if (!path || path === "")
            return ""
        return path.startsWith("file://") ? path : ("file://" + path)
    }

    NHeader {
        label: pluginApi?.tr("settings.title") || "Photo Frame"
        description: pluginApi?.tr("settings.description") || "Configure the default image for the widget"
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.imagePath.label") || "Image path"
        description: pluginApi?.tr("settings.imagePath.description") || "Paste a manual path or choose one using the picker"
        placeholderText: pluginApi?.tr("settings.imagePath.placeholder") || "file:///path/to/image.jpg"
        text: root.localImageSource
        onTextChanged: root.localImageSource = text
    }

    RowLayout {
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.imagePicker.label") || "Select image"
            description: pluginApi?.tr("settings.imagePicker.description") || "Open the file selection menu"
        }

        NIconButton {
            icon: "wallpaper-selector"
            tooltipText: pluginApi?.tr("settings.imagePicker.tooltip") || "Choose image"
            onClicked: imagePicker.openFilePicker()
        }
    }

    NFilePicker {
        id: imagePicker
        title: pluginApi?.tr("settings.imagePicker.dialogTitle") || "Select image"
        initialPath: root.localImageSource === "" ? "" : root.localImageSource
        selectionMode: "files"

        onAccepted: paths => {
            if (paths.length > 0) {
                root.localImageSource = root.normalizeImagePath(paths[0])
                root.saveSettings()
            }
        }
    }

    NButton {
        text: pluginApi?.tr("common.save") || "Save"
        onClicked: root.saveSettings()
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.transparentBg.label") || "Transparent background"
        description: pluginApi?.tr("settings.transparentBg.description") || "Default value for new widget instances"
        checked: root.localTransparentBg
        onToggled: checked => {
            root.localTransparentBg = checked
        }
    }

    NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.note") || "The frame uses this image as default for new instances."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        wrapMode: Text.WordWrap
    }
}
