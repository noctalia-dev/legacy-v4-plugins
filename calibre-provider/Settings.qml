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
  property string editLauncher: pluginApi?.pluginSettings?.launcher || "xdg-open"
  property bool editForceGrid: !!(pluginApi?.pluginSettings?.forceGrid)

  spacing: Style.marginM

  // Calibre db
  ColumnLayout {
      NLabel {
          label: pluginApi?.tr("settings.launcher.title") || "Launcher"
          description: pluginApi?.tr("settings.launcher.description") || "The program used to open book files"
      }

      NTextInput {
          Layout.fillWidth: true
          placeholderText: "xdg-open"
          text: root.editLauncher
          onTextChanged: root.editLauncher = text
      }

      NCheckbox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.forcegrid.label") || "Force grid view"
        description: pluginApi?.tr("settings.forcegrid.description") || "Always use grid view to display results. If disabled, use current launcher configuration"
        checked: root.editForceGrid
        onToggled: (checked) => root.editForceGrid = checked
      }
  }


  // Required: Save function called by the dialog
  function saveSettings() {
    pluginApi.pluginSettings.launcher = root.editLauncher;
    pluginApi.pluginSettings.forceGrid = root.editForceGrid;
    pluginApi.saveSettings();
  }
}
