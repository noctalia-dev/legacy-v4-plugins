import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.Compositor

ColumnLayout {
    id: root

    // Plugin API (injected by the settings dialog system)
    property var pluginApi: null

    // Local state for editing
    property bool enableCross: pluginApi?.pluginSettings?.enableCross
                               ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableCross
                               ?? true

    property bool enableWindowsSelection: pluginApi?.pluginSettings?.enableWindowsSelection
                                          ?? pluginApi?.manifest?.metadata?.defaultSettings?.enableWindowsSelection
                                          ?? true

    property string screenshotEditor: pluginApi?.pluginSettings?.screenshotEditor
                                      ?? pluginApi?.manifest?.metadata?.defaultSettings?.screenshotEditor
                                      ?? "swappy"

    property bool keepSourceScreenshot: pluginApi?.pluginSettings?.keepSourceScreenshot
                                        ?? pluginApi?.manifest?.metadata?.defaultSettings?.keepSourceScreenshot
                                        ?? false

    property string savePath: pluginApi?.pluginSettings?.savePath
                              ?? pluginApi?.manifest?.metadata?.defaultSettings?.savePath
                              ?? (Quickshell.env("HOME") + "/Pictures/Screenshots")

    property string recordingSavePath: pluginApi?.pluginSettings?.recordingSavePath
                                       ?? pluginApi?.manifest?.metadata?.defaultSettings?.recordingSavePath
                                       ?? (Quickshell.env("HOME") + "/Videos")

    property int pngCompressionLevel: pluginApi?.pluginSettings?.pngCompressionLevel
                                       ?? pluginApi?.manifest?.metadata?.defaultSettings?.pngCompressionLevel
                                       ?? 1

    property bool notificationsEnabled: pluginApi?.pluginSettings?.notificationsEnabled
                                         ?? pluginApi?.manifest?.metadata?.defaultSettings?.notificationsEnabled
                                         ?? true

    property bool recordingNotifications: pluginApi?.pluginSettings?.recordingNotifications
                                          ?? pluginApi?.manifest?.metadata?.defaultSettings?.recordingNotifications
                                          ?? true

    spacing: Style.marginM

    // Your settings controls here

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.enableCross.label")
        description: pluginApi?.tr("settings.enableCross.description")
        checked: root.enableCross
        onToggled: (checked) => {
            root.enableCross = checked
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.enableWindowsSelection.label")
        description: pluginApi?.tr("settings.enableWindowsSelection.description")
        checked: root.enableWindowsSelection
        onToggled: (checked) => {
            root.enableWindowsSelection = checked
        }
    }

    NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.enableWindowsSelection.niriWarning")
        color: "#ff4444"
        visible: CompositorService.isNiri
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

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.keepSourceScreenshot.label")
        description: pluginApi?.tr("settings.keepSourceScreenshot.description")
        checked: root.keepSourceScreenshot
        onToggled: (checked) => {
            root.keepSourceScreenshot = checked
        }
    }

    NTextInputButton {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.savePath.label")
        description: pluginApi?.tr("settings.savePath.description")
        placeholderText: Quickshell.env("HOME") + "/Pictures/Screenshots"
        text: root.savePath
        buttonIcon: "folder-open"
        buttonTooltip: pluginApi?.tr("settings.savePath.label")
        onInputEditingFinished: root.savePath = text
        onButtonClicked: screenshotFolderPicker.openFilePicker()
    }

    NTextInputButton {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.recordingSavePath.label")
        description: pluginApi?.tr("settings.recordingSavePath.description")
        placeholderText: Quickshell.env("HOME") + "/Videos"
        text: root.recordingSavePath
        buttonIcon: "folder-open"
        buttonTooltip: pluginApi?.tr("settings.recordingSavePath.label")
        onInputEditingFinished: root.recordingSavePath = text
        onButtonClicked: recordingFolderPicker.openFilePicker()
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.notificationsEnabled.label")
        description: pluginApi?.tr("settings.notificationsEnabled.description")
        checked: root.notificationsEnabled
        onToggled: (checked) => {
            root.notificationsEnabled = checked
        }
    }

    NValueSlider {
        Layout.fillWidth: true
        from: 0
        to: 9
        stepSize: 1
        value: root.pngCompressionLevel
        label: pluginApi?.tr("settings.pngCompressionLevel.label")
        description: pluginApi?.tr("settings.pngCompressionLevel.description")
        onMoved: value => {
            root.pngCompressionLevel = value
        }
        text: String(root.pngCompressionLevel)
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.recordingNotifications.label")
        description: pluginApi?.tr("settings.recordingNotifications.description")
        checked: root.recordingNotifications
        onToggled: (checked) => {
            root.recordingNotifications = checked
        }
    }

    NFilePicker {
        id: screenshotFolderPicker
        selectionMode: "folders"
        title: pluginApi?.tr("settings.savePath.label")
        initialPath: root.savePath || Quickshell.env("HOME") + "/Pictures/Screenshots"
        onAccepted: paths => {
            if (paths.length > 0) {
                root.savePath = paths[0]
            }
        }
    }

    NFilePicker {
        id: recordingFolderPicker
        selectionMode: "folders"
        title: pluginApi?.tr("settings.recordingSavePath.label")
        initialPath: root.recordingSavePath || Quickshell.env("HOME") + "/Videos"
        onAccepted: paths => {
            if (paths.length > 0) {
                root.recordingSavePath = paths[0]
            }
        }
    }

    // Required: Save function called by the dialog
    function saveSettings() {
        pluginApi.pluginSettings.enableCross = root.enableCross
        pluginApi.pluginSettings.enableWindowsSelection = root.enableWindowsSelection
        pluginApi.pluginSettings.screenshotEditor = root.screenshotEditor
        pluginApi.pluginSettings.keepSourceScreenshot = root.keepSourceScreenshot
        pluginApi.pluginSettings.savePath = root.savePath
        pluginApi.pluginSettings.recordingSavePath = root.recordingSavePath
        pluginApi.pluginSettings.pngCompressionLevel = root.pngCompressionLevel
        pluginApi.pluginSettings.notificationsEnabled = root.notificationsEnabled
        pluginApi.pluginSettings.recordingNotifications = root.recordingNotifications
        pluginApi.saveSettings()
    }
}

