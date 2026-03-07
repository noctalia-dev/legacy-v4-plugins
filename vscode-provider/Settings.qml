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
  property string command: pluginApi?.pluginSettings?.command ||
      pluginApi?.manifest?.metadata?.defaultSettings?.command ||
      "code"
  property string configName: pluginApi?.pluginSettings?.configName ||
      pluginApi?.manifest?.metadata?.defaultSettings?.configName ||
      "Code"
  property bool includeInSearch: pluginApi?.pluginSettings?.includeInSearch ??
      pluginApi?.manifest?.metadata?.defaultSettings?.includeInSearch ??
      true
  property string forkKey: findCurrentFork()


  readonly property list<var> forks: [
    {
        key: "code",
        name: "Visual Studio Code",
        command: "code",
        configName: "Code"
    },
    {
        key: "code-oss",
        name: "Code - OSS",
        command: "code-oss",
        configName: "Code - OSS"
    },
    {
        key: "cursor",
        name: "Cursor",
        command: "cursor",
        configName: "Cursor"
    },
    {
        key: "other",
        name: "Other",
        command: "",
        configName: ""
    }
  ]

  spacing: Style.marginM

  function findCurrentFork(): string {
      Logger.i("VSCodeWorkspaceProvider", Array.isArray(forks));
      for(let f of forks) {
          if(f["command"] === command && f["configName"] === configName) {
              Logger.i("VSCodeWorkspaceProvider", "Current fork is", f["key"]);
              return f["key"];
          }
      }
      Logger.i("VSCodeWorkspaceProvider", "Current fork unknown, default to other");
      return "other";
  }

  ColumnLayout {
      spacing: Style.marginL

      NCheckbox {
          Layout.fillWidth: true
          label: pluginApi.tr("settings.includeInSearch.label")
          description: pluginApi.tr("settings.includeInSearch.description")
          checked: root.includeInSearch
          onToggled: (checked) => root.includeInSearch = checked
      }

      NComboBox {
          id: forkComboBox
          Layout.fillWidth: true

          label: pluginApi.tr("settings.fork.label")
          description: pluginApi.tr("settings.fork.description")

          model: Array.from(root.forks)
          currentKey: forkKey
          defaultValue: "code"
          onSelected: key => {
              root.forkKey = key;
              const fork = forks[forkComboBox.comboBox.currentIndex];
              root.configName = fork.configName;
              root.command = fork.command;
              otherSettings.visible = root.forkKey === "other"
          }
      }

      RowLayout {
          id: otherSettings
          visible: root.forkKey === "other"

          NTextInput {
              label: pluginApi.tr("settings.otherCommand.label")
              description: pluginApi.tr("settings.otherCommand.description")
              text: root.command
              onTextChanged: root.command = text
          }

          NTextInput {
              label: pluginApi.tr("settings.otherConfigName.label")
              description: pluginApi.tr("settings.otherConfigName.description")
              text: root.configName
              onTextChanged: root.configName = text
          }

      }
  }

  // Required: Save function called by the dialog
  function saveSettings() {
      pluginApi.pluginSettings.command = root.command;
      pluginApi.pluginSettings.configName = root.configName;
      pluginApi.pluginSettings.includeInSearch = root.includeInSearch;
      pluginApi.saveSettings();
  }
}
