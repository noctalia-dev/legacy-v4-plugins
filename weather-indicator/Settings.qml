import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool showTempValue: cfg.showTempValue ?? defaults.showTempValue
  property bool showConditionIcon: cfg.showConditionIcon ?? defaults.showConditionIcon
  property bool showTempUnit: cfg.showTempUnit ?? defaults.showTempUnit
  property string tooltipOption: cfg.tooltipOption ?? defaults.tooltipOption
  property string customColor: cfg.customColor ?? defaults.customColor
  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("WeatherIndicator", "Settings UI loaded");
  }

    NComboBox {
      label: pluginApi?.tr("settings.customColor.label") || "customColor"
      description: pluginApi?.tr("settings.customColor.desc") || "Choose what color you would like the icon and text to be."
      model: Color.colorKeyModel
      currentKey: root.customColor
      onSelected: key => root.customColor = key
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
    pluginApi.pluginSettings.customColor = root.customColor;
    pluginApi.saveSettings();

    Logger.i("WeatherIndicator", "Settings saved successfully");
    pluginApi.closePanel(root.screen);
  }
}
