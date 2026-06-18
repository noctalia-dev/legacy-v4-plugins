import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueNiriConfigPath: cfg.niriConfigPath ?? defaults.niriConfigPath ?? "~/.config/niri/config.kdl"
  property string valueIconColor: cfg.iconColor ?? defaults.iconColor ?? "none"

  spacing: Style.marginL

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.niriConfigPath.label")
      description: pluginApi?.tr("settings.niriConfigPath.description")
      placeholderText: "~/.config/niri/config.kdl"
      text: root.valueNiriConfigPath
      onTextChanged: root.valueNiriConfigPath = text
    }

    NColorChoice {
      label: pluginApi?.tr("settings.iconColor.label")
      description: pluginApi?.tr("settings.iconColor.description")
      currentKey: root.valueIconColor
      onSelected: key => root.valueIconColor = key
    }
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.niriConfigPath = root.valueNiriConfigPath
    pluginApi.pluginSettings.iconColor = root.valueIconColor
    pluginApi.saveSettings()
  }
}
