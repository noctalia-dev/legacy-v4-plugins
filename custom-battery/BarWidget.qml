import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Commons
import qs.Services.Hardware
import qs.Services.Networking
import qs.Services.Power
import qs.Services.UI
import qs.Widgets
import "./"

Item {
  id: root

  property ShellScreen screen
  property var pluginApi: null

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetSettings: ({})

  readonly property string screenName: screen ? screen.name : ""
  readonly property var effectiveSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      try {
        var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
        if (widgets && sectionWidgetIndex < widgets.length) {
          return widgets[sectionWidgetIndex];
        }
      } catch (e) {}
    }
    return {};
  }

  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  
  readonly property string displayMode: effectiveSettings.displayMode !== undefined 
      ? effectiveSettings.displayMode 
      : (pluginApi?.pluginSettings?.displayMode || "icon-text")

  readonly property bool hideIfNotDetected: effectiveSettings.hideIfNotDetected !== undefined 
      ? effectiveSettings.hideIfNotDetected 
      : (pluginApi?.pluginSettings?.hideIfNotDetected !== undefined ? pluginApi.pluginSettings.hideIfNotDetected : true)

  readonly property bool hideIfIdle: effectiveSettings.hideIfIdle !== undefined 
      ? effectiveSettings.hideIfIdle 
      : (pluginApi?.pluginSettings?.hideIfIdle !== undefined ? pluginApi.pluginSettings.hideIfIdle : false)

  readonly property string deviceNativePath: effectiveSettings.deviceNativePath !== undefined 
      ? effectiveSettings.deviceNativePath 
      : (pluginApi?.pluginSettings?.deviceNativePath || "__default__")

  readonly property real warningThreshold: BatteryService.warningThreshold
  readonly property real criticalThreshold: BatteryService.criticalThreshold

  readonly property var selectedBattery: BatteryService.findDevice(deviceNativePath)
  readonly property var selectedDevice: BatteryService.isDevicePresent(selectedBattery) ? selectedBattery : BatteryService.primaryDevice

  readonly property bool isPresent: BatteryService.isDevicePresent(selectedDevice)
  readonly property bool isReady: BatteryService.isDeviceReady(selectedDevice)
  readonly property real percent: isReady ? BatteryService.getPercentage(selectedDevice) : -1
  readonly property bool isCharging: isReady ? BatteryService.isCharging(selectedDevice) : false
  readonly property bool isPluggedIn: isReady ? BatteryService.isPluggedIn(selectedDevice) : false
  readonly property bool isLowBattery: isReady ? BatteryService.isLowBattery(selectedDevice) : false
  readonly property bool isCriticalBattery: isReady ? BatteryService.isCriticalBattery(selectedDevice) : false
  readonly property bool isPowerSaver: PowerProfileService.profile === PowerProfile.PowerSaver

  readonly property bool shouldShow: true // Always show the widget if added

  visible: shouldShow
  opacity: shouldShow ? 1.0 : 0.0

  implicitWidth: pill.width
  implicitHeight: pill.height



  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    iconSource: root.getIcon(root.percent, root.isCharging, root.isPluggedIn, root.isReady)
    charging: root.isCharging || root.isPluggedIn
    icon: ""
    textInsideIcon: true
    
    transparentBackground: false
    text: root.isReady ? Math.round(root.percent) : "-"
    suffix: ""
    autoHide: false
    forceOpen: root.isReady && root.displayMode === "alwaysShow"
    forceClose: true
    isPowerSaver: root.isPowerSaver
    
    readonly property color defaultIconColor: Settings.data.colorSchemes.darkMode ? "#FFFFFF" : "#1C1C1E"
    
    customIconColor: {
      if (root.isPowerSaver) return "#F29900"; // Orange for battery saver
      if (root.isCharging || root.isPluggedIn) return "#34C759"; // Green
      if (root.percent < 20) return "#FF3B30"; // Red
      if (root.percent < 40) return "#FF9500"; // Orange
      if (root.percent === 100) return defaultIconColor;
      return defaultIconColor;
    }
    
    customBackgroundColor: "transparent"
    customTextIconColor: "transparent"

    tooltipText: {
        if (!root.isReady || !root.isPresent) {
            return I18n.tr("battery.no-battery-detected");
        }

        let rows = [];
        const isInternal = root.selectedDevice && root.selectedDevice.isLaptopBattery;
        
        if (isInternal) {
            rows.push([I18n.tr("battery.battery-level"), Math.round(root.percent) + "%"]);

            let timeText = "";
            try {
                timeText = BatteryService.getTimeRemainingText(root.selectedDevice);
            } catch (e) {}
            
            if (timeText) {
                const colonIdx = timeText.indexOf(":");
                if (colonIdx >= 0) {
                    rows.push([timeText.substring(0, colonIdx).trim(), timeText.substring(colonIdx + 1).trim()]);
                } else {
                    rows.push([timeText, ""]);
                }
            }

            let rateText = "";
            try {
                rateText = BatteryService.getRateText(root.selectedDevice);
            } catch (e) {}
            
            if (!root.isPluggedIn && rateText) {
                const colonIdx = rateText.indexOf(":");
                if (colonIdx >= 0) {
                    rows.push([rateText.substring(0, colonIdx).trim(), rateText.substring(colonIdx + 1).trim()]);
                } else {
                    rows.push([rateText, ""]);
                }
            }

            let healthDevice = (root.selectedDevice && root.selectedDevice.healthSupported) ? root.selectedDevice : (BatteryService.laptopBatteries && BatteryService.laptopBatteries.length > 0 ? BatteryService.laptopBatteries[0] : null);
            if (healthDevice && healthDevice.healthSupported) {
                rows.push([I18n.tr("battery.battery-health"), Math.round(healthDevice.healthPercentage) + "%"]);
            }
        } else if (root.selectedDevice) {
            // External / Peripheral Device
            let name = BatteryService.getDeviceName(root.selectedDevice);
            rows.push([name, Math.round(root.percent) + "%"]);
        }

        if (isInternal) {
            var external = [];
            try {
                external = BatteryService.bluetoothBatteries || [];
            } catch (e) {}
            
            if (external.length > 0) {
                if (rows.length > 0) {
                    rows.push(["---", "---"]); // Separator
                }
                for (var j = 0; j < external.length; j++) {
                    var dev = external[j];
                    if (dev) {
                        var dName = BatteryService.getDeviceName(dev);
                        var dPct = BatteryService.getPercentage(dev);
                        rows.push([dName, Math.round(dPct) + "%"]);
                    }
                }
            }
        }

        return rows;
    }

    onClicked: {
        var panel = PanelService.getPanel("batteryPanel", screen);
        if (panel) panel.toggle(root);
    }


  }

  // Local getIcon implementation using plugin assets
  function getIcon(percent, charging, pluggedIn, isReady) {
    const iconBasePath = Qt.resolvedUrl("Assets/Icons/Battery/");
    
    if (!isReady) {
      return iconBasePath + "battery-0.svg";
    }
    
    const roundedPercent = Math.round(percent / 10) * 10;
    
    if (roundedPercent >= 100) return iconBasePath + "battery-100.svg";
    if (roundedPercent >= 90) return iconBasePath + "battery-90.svg";
    if (roundedPercent >= 80) return iconBasePath + "battery-80.svg";
    if (roundedPercent >= 70) return iconBasePath + "battery-70.svg";
    if (roundedPercent >= 60) return iconBasePath + "battery-60.svg";
    if (roundedPercent >= 50) return iconBasePath + "battery-50.svg";
    if (roundedPercent >= 40) return iconBasePath + "battery-40.svg";
    if (roundedPercent >= 30) return iconBasePath + "battery-30.svg";
    if (roundedPercent >= 20) return iconBasePath + "battery-20.svg";
    if (roundedPercent >= 10) return iconBasePath + "battery-10.svg";
    return iconBasePath + "battery-0.svg";
  }
}
