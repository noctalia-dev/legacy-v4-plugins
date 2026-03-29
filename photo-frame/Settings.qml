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
        label: pluginApi?.tr("settings.title")
        description: pluginApi?.tr("settings.description")
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.imagePath.label")
        description: pluginApi?.tr("settings.imagePath.description")
        placeholderText: pluginApi?.tr("settings.imagePath.placeholder")
        text: root.localImageSource
        onTextChanged: root.localImageSource = text
    }

    RowLayout {
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.imagePicker.label")
            description: pluginApi?.tr("settings.imagePicker.description")
        }

        NIconButton {
            icon: "wallpaper-selector"
            tooltipText: pluginApi?.tr("settings.imagePicker.tooltip")
            onClicked: imagePicker.openFilePicker()
        }
    }

    NFilePicker {
        id: imagePicker
        title: pluginApi?.tr("settings.imagePicker.dialogTitle")
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
        text: pluginApi?.tr("common.save")
        onClicked: root.saveSettings()
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.transparentBg.label")
        description: pluginApi?.tr("settings.transparentBg.description")
        checked: root.localTransparentBg
        onToggled: checked => {
            root.localTransparentBg = checked
        }
    }

    NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.note")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        wrapMode: Text.WordWrap
    }
}
