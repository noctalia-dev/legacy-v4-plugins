import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: settingsRoot

    property var pluginApi: null
    property var widgetSettings: null

    spacing: Style.marginL

    property string localImageSource:   widgetSettings?.data?.imageSource   ?? pluginApi?.pluginSettings?.imageSource ?? ""
    property bool   localTransparentBg: widgetSettings?.data?.transparentBg ?? pluginApi?.pluginSettings?.transparentBg ?? false

    function commitSettings() {
        if (!widgetSettings)
            return

        widgetSettings.data.imageSource = localImageSource
        widgetSettings.data.transparentBg = localTransparentBg
        widgetSettings.save()
    }

    Component.onDestruction: commitSettings()

    function normalizeImagePath(path) {
        if (!path || path === "")
            return ""
        return path.startsWith("file://") ? path : ("file://" + path)
    }

    NHeader {
        label: pluginApi?.tr("desktopWidgetSettings.title")
        description: pluginApi?.tr("desktopWidgetSettings.description")
    }

    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("desktopWidgetSettings.imagePath.label")
        description: pluginApi?.tr("desktopWidgetSettings.imagePath.description")
        placeholderText: pluginApi?.tr("desktopWidgetSettings.imagePath.placeholder")
        text: settingsRoot.localImageSource
        onTextChanged: settingsRoot.localImageSource = text
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("desktopWidgetSettings.imagePicker.label")
            description: pluginApi?.tr("desktopWidgetSettings.imagePicker.description")
        }

        NIconButton {
            icon: "wallpaper-selector"
            tooltipText: pluginApi?.tr("desktopWidgetSettings.imagePicker.tooltip")
            onClicked: imagePicker.openFilePicker()
        }

        NButton {
            text: pluginApi?.tr("common.apply")
            onClicked: settingsRoot.commitSettings()
        }
    }

    NFilePicker {
        id: imagePicker
        title: pluginApi?.tr("desktopWidgetSettings.imagePicker.dialogTitle")
        initialPath: settingsRoot.localImageSource === "" ? "" : settingsRoot.localImageSource
        selectionMode: "files"

        onAccepted: paths => {
            if (paths.length > 0) {
                settingsRoot.localImageSource = settingsRoot.normalizeImagePath(paths[0])
                settingsRoot.commitSettings()
            }
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("desktopWidgetSettings.transparentBg.label")
        description: pluginApi?.tr("desktopWidgetSettings.transparentBg.description")
        checked: settingsRoot.localTransparentBg
        onToggled: checked => {
            settingsRoot.localTransparentBg = checked
            settingsRoot.commitSettings()
        }
    }

    NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("desktopWidgetSettings.note")
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        wrapMode: Text.WordWrap
    }
}
