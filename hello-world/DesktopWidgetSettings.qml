import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null
  property var widgetSettings: null

  readonly property var cfg: pluginApi?.pluginSettings ?? ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
  readonly property var widget: widgetSettings?.data ?? ({})

  property string valueMessage: widget.message ?? cfg.message ?? defaults.message

  spacing: Style.marginM

  Component.onCompleted: {
    Logger.d("HelloWorld", "Desktop Widget Settings UI loaded");
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.message.label")
      description: pluginApi?.tr("settings.message.desc")
      placeholderText: pluginApi?.tr("settings.message.placeholder")
      text: root.valueMessage
      onTextChanged: {
        root.valueMessage = text;
        root.saveSettings();
      }
    }
  }

  function saveSettings() {
    if (!widgetSettings) {
      Logger.e("HelloWorld", "Cannot save settings: widgetSettings is null");
      return;
    }

    widgetSettings.data.message = root.valueMessage;
    widgetSettings.save();

    Logger.d("HelloWorld", "Per-instance settings saved successfully");
  }
}
