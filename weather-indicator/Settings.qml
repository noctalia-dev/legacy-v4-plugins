import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property bool showTempValue: pluginApi?.pluginSettings?.showTempValue ?? true
  property bool showConditionIcon: pluginApi?.pluginSettings?.showConditionIcon ?? true
  property bool showTempUnit: pluginApi?.pluginSettings?.showTempUnit ?? true
  property string tooltipOption: pluginApi?.pluginSettings?.tooltipOption || pluginApi?.manifest?.defaultSettings?.tooltipOption || "everything"
  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("WeatherIndicator", "Settings UI loaded");
  }

  NToggle {
    id: toggleIcon
    label: pluginApi?.tr("settings.showConditionIcon.label") || "showConditionIcon"
    description: pluginApi?.tr("settings.showConditionIcon.desc") || "Show the condition icon"
    checked: root.showConditionIcon
    onToggled: checked => {
      root.showConditionIcon = checked;
      root.showTempValue = true;
    }
    defaultValue: true
  }

  NToggle {
    id: toggleTempText
    label: pluginApi?.tr("settings.showTempValue.label") || "showTempValue"
    description: pluginApi?.tr("settings.showTempValue.desc") || "Show the temperature"
    checked: root.showTempValue
    onToggled: checked => {
      root.showTempValue = checked;
      root.showConditionIcon = true;
    }
    defaultValue: true
  }

  NToggle {
    id: toggleTempLetter
    label: pluginApi?.tr("settings.showTempUnit.label") || "showTempUnit"
    description: pluginApi?.tr("settings.showTempUnit.desc") || "Show temperature letter (°F or °C)"
    checked: root.showTempUnit
    visible: root.showTempValue
    onToggled: checked => {
      root.showTempUnit = checked;
    }
    defaultValue: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.tooltipOption.label") || "Tooltip options"
    description: pluginApi?.tr("settings.tooltipOption.desc") || "Choose what you would like the tooltip to display."
    model: [
      {
        "key": "disable",
        "name": pluginApi?.tr("settings.mode.disable") || "Disable the Tooltip"
      },
      {
        "key": "highlow",
        "name": pluginApi?.tr("settings.mode.highlow") || "High/Low tempuratures"
      },
      {
        "key": "sunrise",
        "name": pluginApi?.tr("settings.mode.sunrise") || "Sunrise and Sunset times"
      },
      {
        "key": "everything",
        "name": pluginApi?.tr("settings.mode.everything") || "Show all weather information"
      }
    ]
    currentKey: root.tooltipOption
    onSelected: function (key) {
      root.tooltipOption = key;
    }
    defaultValue: "everything"
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("WeatherIndicator", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.showTempValue = root.showTempValue;
    pluginApi.pluginSettings.showConditionIcon = root.showConditionIcon;
    pluginApi.pluginSettings.showTempUnit = root.showTempUnit;
    pluginApi.pluginSettings.tooltipOption = root.tooltipOption;

    pluginApi.saveSettings();

    Logger.i("WeatherIndicator", "Settings saved successfully");
    pluginApi.closePanel(root.screen);
  }
}
