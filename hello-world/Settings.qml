import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueMessage: cfg.message ?? defaults.message
  property string valueIconColor: cfg.iconColor ?? defaults.iconColor

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.d("HelloWorld", "Settings UI loaded");
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NComboBox {
      label: pluginApi?.tr("settings.iconColor.label")
      description: pluginApi?.tr("settings.iconColor.desc")
      model: Color.colorKeyModel
      currentKey: root.valueIconColor
      onSelected: key => root.valueIconColor = key
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.message.label")
      description: pluginApi?.tr("settings.message.desc")
      placeholderText: pluginApi?.tr("settings.message.placeholder")
      text: root.valueMessage
      onTextChanged: root.valueMessage = text
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("HelloWorld", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.message = root.valueMessage;
    pluginApi.pluginSettings.iconColor = root.valueIconColor;
    pluginApi.saveSettings();

    Logger.d("HelloWorld", "Settings saved successfully");
  }
}
