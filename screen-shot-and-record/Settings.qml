import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    // Plugin API (injected by the settings dialog system)
    property var pluginApi: null

    // Local state for editing
    property bool enableWindowsSelection: pluginApi?.pluginSettings?.enableWindowsSelection
                                          ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableWindowsSelection
                                          ?? true

    property bool enableCross: pluginApi?.pluginSettings?.enableCross
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableCross
                               ?? true

    property string screenshotEditor: pluginApi?.pluginSettings?.screenshotEditor
                                      ?? pluginApi?.manifest?.metadata?.defaultSettings?.screenshotEditor
                                      ?? "swappy"

    spacing: Style.marginM

    // Your settings controls here

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.enableWindowsSelection.label")
        description: pluginApi?.tr("settings.enableWindowsSelection.description")
        checked: root.enableWindowsSelection
        onToggled: (checked) => {
            root.enableWindowsSelection = checked
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.enableCross.label")
        description: pluginApi?.tr("settings.enableCross.description")
        checked: root.enableCross
        onToggled: (checked) => {
            root.enableCross = checked
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NLabel {
            label: pluginApi?.tr("settings.screenshotEditor.label")
            description: pluginApi?.tr("settings.screenshotEditor.description")
        }

        NComboBox {
            Layout.fillWidth: true
            model: ListModel {
                ListElement { name: "Swappy"; key: "swappy" }
                ListElement { name: "Satty"; key: "satty" }
            }
            currentKey: root.screenshotEditor
            onSelected: key => {
                Logger.d("ScreenShot", (key))
                root.screenshotEditor = key;
            }
        }
    }

    // Required: Save function called by the dialog
    function saveSettings() {
        pluginApi.pluginSettings.enableWindowsSelection = root.enableWindowsSelection
        pluginApi.pluginSettings.enableCross = root.enableCross
        pluginApi.pluginSettings.screenshotEditor = root.screenshotEditor
        pluginApi.saveSettings()
    }
}

