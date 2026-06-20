import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string editConfigPath: cfg.obsidianConfigPath ?? defaults.obsidianConfigPath ?? ""
    property bool editIncludeInSearch: cfg.includeInSearch ?? defaults.includeInSearch ?? true

    spacing: Style.marginL

    NTextInputButton {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.configPath.label")
        description: pluginApi?.tr("settings.configPath.desc")
        placeholderText: pluginApi?.tr("settings.configPath.placeholder")
        text: root.editConfigPath
        buttonIcon: "file"
        buttonTooltip: pluginApi?.tr("settings.configPath.buttonTooltip")
        onInputEditingFinished: root.editConfigPath = text
        onButtonClicked: filePicker.openFilePicker()
    }

    NCheckbox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.includeInSearch.label")
        description: pluginApi?.tr("settings.includeInSearch.desc")
        checked: root.editIncludeInSearch
        onToggled: (checked) => root.editIncludeInSearch = checked
    }

    NFilePicker {
        id: filePicker
        selectionMode: "files"
        title: pluginApi?.tr("settings.configPath.pickerTitle")
        initialPath: root.editConfigPath
        onAccepted: paths => {
            if (paths.length > 0) {
                root.editConfigPath = paths[0];
            }
        }
    }

    function saveSettings() {
        if (!pluginApi) return;
        pluginApi.pluginSettings.obsidianConfigPath = root.editConfigPath;
        pluginApi.pluginSettings.includeInSearch = root.editIncludeInSearch;
        pluginApi.saveSettings();
    }
}
