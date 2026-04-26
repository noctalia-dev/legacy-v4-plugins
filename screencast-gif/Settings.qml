import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string valueOutputDir: cfg.outputDir ?? defaults.outputDir
    property int valueFps: cfg.fps ?? defaults.fps
    property int valueMaxRecordingSeconds: cfg.maxRecordingSeconds ?? defaults.maxRecordingSeconds

    spacing: Style.marginL

    NTextInput {
        Layout.fillWidth: true
        label: "Output directory"
        description: "Where to save the .gif files. Leading ~ is expanded to $HOME."
        text: root.valueOutputDir
        onTextChanged: root.valueOutputDir = text
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Frame rate"
        description: "GIF frame rate. 15-25 is a good balance between smoothness and file size."
        text: String(root.valueFps)
        onTextChanged: root.valueFps = parseInt(text) || 20
    }

    NTextInput {
        Layout.fillWidth: true
        label: "Auto-stop after (seconds)"
        description: "Maximum recording duration before auto-stopping. Use 0 to disable."
        text: String(root.valueMaxRecordingSeconds)
        onTextChanged: root.valueMaxRecordingSeconds = parseInt(text) || 0
    }

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.outputDir = root.valueOutputDir
        pluginApi.pluginSettings.fps = root.valueFps
        pluginApi.pluginSettings.maxRecordingSeconds = root.valueMaxRecordingSeconds
        pluginApi.saveSettings()
    }
}
