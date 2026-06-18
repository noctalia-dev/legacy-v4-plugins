import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.Hardware
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueDisplayMode: cfg.displayMode ?? defaults.displayMode ?? "graphic-clean"
  property string valueDeviceNativePath: cfg.deviceNativePath ?? defaults.deviceNativePath ?? "__default__"
  property bool valueShowPowerProfiles: cfg.showPowerProfiles ?? defaults.showPowerProfiles ?? false
  property bool valueShowNoctaliaPerformance: cfg.showNoctaliaPerformance ?? defaults.showNoctaliaPerformance ?? false
  property bool valueHideIfNotDetected: cfg.hideIfNotDetected ?? defaults.hideIfNotDetected ?? true
  property bool valueHideIfIdle: cfg.hideIfIdle ?? defaults.hideIfIdle ?? false
  property int valueRefreshIntervalSeconds: cfg.refreshIntervalSeconds ?? defaults.refreshIntervalSeconds ?? 5
  property bool valueShowPowerInBar: cfg.showPowerInBar ?? defaults.showPowerInBar ?? true
  property bool valueShowTimeInBar: cfg.showTimeInBar ?? defaults.showTimeInBar ?? true

  spacing: Style.marginM

  Component.onCompleted: {
    Logger.d("BatteryMonitorPlus", "Settings UI loaded");
  }

  NComboBox {
    id: deviceComboBox
    Layout.fillWidth: true
    label: I18n.tr("bar.battery.device-label")
    description: I18n.tr("bar.battery.device-description")
    minimumWidth: 240
    model: BatteryService.deviceModel
    currentKey: root.valueDeviceNativePath
    defaultValue: defaults.deviceNativePath ?? "__default__"
    onSelected: key => root.valueDeviceNativePath = key
  }

  NComboBox {
    Layout.fillWidth: true
    label: I18n.tr("common.display-mode")
    description: I18n.tr("bar.battery.display-mode-description")
    minimumWidth: 240
    model: [
      {
        "key": "graphic",
        "name": I18n.tr("bar.battery.display-mode-graphic")
      },
      {
        "key": "graphic-clean",
        "name": I18n.tr("bar.battery.display-mode-graphic-clean")
      },
      {
        "key": "icon-hover",
        "name": I18n.tr("bar.battery.display-mode-icon-hover")
      },
      {
        "key": "icon-always",
        "name": I18n.tr("bar.battery.display-mode-icon-always")
      },
      {
        "key": "icon-only",
        "name": I18n.tr("bar.battery.display-mode-icon-only")
      }
    ]
    currentKey: root.valueDisplayMode
    defaultValue: defaults.displayMode ?? "graphic-clean"
    onSelected: key => root.valueDisplayMode = key
  }

  NToggle {
    label: I18n.tr("bar.battery.hide-if-not-detected-label")
    description: I18n.tr("bar.battery.hide-if-not-detected-description")
    checked: root.valueHideIfNotDetected
    defaultValue: defaults.hideIfNotDetected ?? true
    onToggled: checked => root.valueHideIfNotDetected = checked
  }

  NToggle {
    label: I18n.tr("bar.battery.hide-if-idle-label")
    description: I18n.tr("bar.battery.hide-if-idle-description")
    checked: root.valueHideIfIdle
    defaultValue: defaults.hideIfIdle ?? false
    onToggled: checked => root.valueHideIfIdle = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: I18n.tr("bar.battery.show-power-profile-label")
    description: I18n.tr("bar.battery.show-power-profile-description")
    checked: root.valueShowPowerProfiles
    defaultValue: defaults.showPowerProfiles ?? false
    onToggled: checked => root.valueShowPowerProfiles = checked
  }

  NToggle {
    label: I18n.tr("bar.battery.show-noctalia-performance-label")
    description: I18n.tr("bar.battery.show-noctalia-performance-description")
    checked: root.valueShowNoctaliaPerformance
    defaultValue: defaults.showNoctaliaPerformance ?? false
    onToggled: checked => root.valueShowNoctaliaPerformance = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      label: pluginApi?.tr("settings.refreshInterval.label")
      description: pluginApi?.tr("settings.refreshInterval.desc")
    }

    NValueSlider {
      Layout.fillWidth: true
      from: 1
      to: 60
      stepSize: 1
      snapAlways: true
      value: root.valueRefreshIntervalSeconds
      text: `${root.valueRefreshIntervalSeconds}s`
      onMoved: value => root.valueRefreshIntervalSeconds = Math.round(value)
    }
  }

  NToggle {
    label: pluginApi?.tr("settings.showPowerInBar.label")
    description: pluginApi?.tr("settings.showPowerInBar.desc")
    checked: root.valueShowPowerInBar
    defaultValue: defaults.showPowerInBar ?? true
    onToggled: checked => root.valueShowPowerInBar = checked
  }

  NToggle {
    label: pluginApi?.tr("settings.showTimeInBar.label")
    description: pluginApi?.tr("settings.showTimeInBar.desc")
    checked: root.valueShowTimeInBar
    defaultValue: defaults.showTimeInBar ?? true
    onToggled: checked => root.valueShowTimeInBar = checked
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("BatteryMonitorPlus", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.displayMode = root.valueDisplayMode;
    pluginApi.pluginSettings.deviceNativePath = root.valueDeviceNativePath;
    pluginApi.pluginSettings.showPowerProfiles = root.valueShowPowerProfiles;
    pluginApi.pluginSettings.showNoctaliaPerformance = root.valueShowNoctaliaPerformance;
    pluginApi.pluginSettings.hideIfNotDetected = root.valueHideIfNotDetected;
    pluginApi.pluginSettings.hideIfIdle = root.valueHideIfIdle;
    pluginApi.pluginSettings.refreshIntervalSeconds = root.valueRefreshIntervalSeconds;
    pluginApi.pluginSettings.showPowerInBar = root.valueShowPowerInBar;
    pluginApi.pluginSettings.showTimeInBar = root.valueShowTimeInBar;
    pluginApi.saveSettings();

    Logger.d("BatteryMonitorPlus", "Settings saved successfully");
  }
}
