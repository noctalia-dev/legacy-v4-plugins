import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  // Plugin API (injected by the settings dialog system)
  property var pluginApi: null

  // Local state for editing
  property string editNvim: pluginApi?.pluginSettings?.nvim ||
      pluginApi?.manifest?.metadata?.defaultSettings?.nvim ||
      "nvim"
  property bool editRunInTerminal: pluginApi?.pluginSettings?.runInTerminal ??
      pluginApi?.manifest?.metadata?.defaultSettings?.runInTerminal ??
      true
  property string editSessionDir: pluginApi?.pluginSettings?.sessionDir ??
      pluginApi?.manifest?.metadata?.defaultSettings?.sessionDir ??
      "~/.local/share/nvim/sessions"
  property bool editIncludeInSearch: pluginApi?.pluginSettings?.includeInSearch ??
      pluginApi?.manifest?.metadata?.defaultSettings?.includeInSearch ??
      true


  spacing: Style.marginM

  ColumnLayout {
      spacing: Style.marginL

      NLabel {
          label: pluginApi.tr("settings.nvim.title")
          description: pluginApi.tr("settings.nvim.description")
      }

      NTextInput {
          Layout.fillWidth: true
          placeholderText: "nvim"
          text: root.editNvim
          onTextChanged: root.editNvim = text
      }

      NCheckbox {
          Layout.fillWidth: true
          label: pluginApi.tr("settings.runInTerminal.label")
          description: pluginApi.tr("settings.runInTerminal.description") 
          checked: root.editRunInTerminal
          onToggled: (checked) => root.editRunInTerminal = checked
      }

      NTextInputButton {
          label: pluginApi.tr("settings.sessionDir.label")
          description: pluginApi.tr("settings.sessionDir.description")
          placeholderText: "~/.local/share/nvim/sessions"
          text: root.editSessionDir
          buttonIcon: "folder"
          buttonTooltip: pluginApi.tr("settings.sessionDir.select")
          onInputEditingFinished: root.editSessionDir = text
          onButtonClicked: filePicker.openFilePicker()
      }

      NCheckbox {
          Layout.fillWidth: true
          label: pluginApi.tr("settings.includeInSearch.label")
          description: pluginApi.tr("settings.includeInSearch.description")
          checked: root.editIncludeInSearch
          onToggled: (checked) => root.editIncludeInSearch = checked
      }

  }

  NFilePicker {
      id: filePicker
      selectionMode: "folders"
      title: pluginApi.tr("settings.sessionDir.title")
      initialPath: root.editSessionDir
      onAccepted: paths => {
          if (paths.length > 0) {
              root.editSessionDir = paths[0]
          }
      }
  }


  // Required: Save function called by the dialog
  function saveSettings() {
      pluginApi.pluginSettings.nvim = root.editNvim;
      pluginApi.pluginSettings.runInTerminal = root.editRunInTerminal;
      pluginApi.pluginSettings.sessionDir = root.editSessionDir;
      pluginApi.pluginSettings.includeInSearch = root.editIncludeInSearch;
      pluginApi.saveSettings();
  }
}
