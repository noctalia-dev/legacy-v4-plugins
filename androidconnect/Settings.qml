import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string iconColor: cfg.iconColor ?? defaults.iconColor ?? "none"

  spacing: Style.marginL

  NColorChoice {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.iconColor.label")
    description: pluginApi?.tr("settings.iconColor.desc")
    currentKey: iconColor
    onSelected: key => iconColor = key
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("KDEConnect", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.iconColor = iconColor;
    pluginApi.saveSettings();
  }
}
