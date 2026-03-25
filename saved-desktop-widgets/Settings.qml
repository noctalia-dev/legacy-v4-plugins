import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  property bool saveWidgets: cfg.saveWidgets ?? defaults.saveWidgets ?? true
  property bool loadWidgets: cfg.loadWidgets ?? defaults.loadWidgets ?? true

  readonly property var wallpaperMonitorWidgets: cfg.monitorWidgets ?? ({})

  NToggle {
    label: pluginApi?.tr("settings.save_widgets.label")
    description: pluginApi?.tr("settings.save_widgets.description")
    checked: root.saveWidgets
    onCheckedChanged: root.saveWidgets = checked
    defaultValue: true
  }

  NToggle {
    label: pluginApi?.tr("settings.load_widgets.label")
    description: pluginApi?.tr("settings.load_widgets.description")
    checked: root.saveWidgets
    onCheckedChanged: root.saveWidgets = checked
    defaultValue: true
  }


  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: listView.implicitHeight

    NListView {
      id: listView
      anchors.fill: parent
      anchors.margins: Style.marginS
      model: Object.keys(root.wallpaperMonitorWidgets)

      spacing: Style.marginL

      delegate: RowLayout {
        id: wallpaperField
        required property var modelData

        width: listView.availableWidth

        // Remove the whole path first and also remove the extension.
        property string fileName: modelData.split('/').pop().split('.').slice(0, -1).join('.')

        NText {
          text: wallpaperField.fileName
        }

        Item { Layout.fillWidth: true; Layout.fillHeight: true; }

        NIconButton {
          icon: "x"
          tooltipText: root.pluginApi?.tr("settings.list.remove")

          onClicked: {
            if (!root.pluginApi) {
              Logger.e("SavedDesktopWidgets", "Could not save, pluginApi is null");
              return;
            }

            let monitorWidgets = JSON.parse(JSON.stringify(root.wallpaperMonitorWidgets));

            delete monitorWidgets[wallpaperField.modelData];

            root.pluginApi.pluginSettings.monitorWidgets = monitorWidgets;
            root.pluginApi.saveSettings();
          }
        }
      }
    }
  }

  NButton {
    text: pluginApi?.tr("settings.tool_row.nuke.text")
    icon: "x"
    tooltipText: pluginApi?.tr("settings.tool_row.nuke.tooltip")
    backgroundColor: Color.mError

    onClicked: {
      if (!root.pluginApi) {
        Logger.e("SavedDesktopWidgets", "Could not save, pluginApi is null");
        return;
      }

      root.pluginApi.pluginSettings.monitorWidgets = {};
      root.pluginApi.saveSettings();
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("SavedDesktopWidgets", "Cannot save: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.saveWidgets = saveWidgets;
    pluginApi.pluginSettings.loadWidgets = loadWidgets;

    pluginApi.saveSettings();
  }
}
