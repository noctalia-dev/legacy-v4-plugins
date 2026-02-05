import QtQuick
import Quickshell.Io

// Start the BatteryThresholdService to restore a previously set charge
// threshold when the plugin is loaded. This is needed as FW may reset
// the charge threshold when the device is fully powered off.
Item {
    property var pluginApi: null

    BatteryThresholdService {
        id: service
        pluginApi: parent.pluginApi
    }

    IpcHandler {
        target: "plugin:battery-threshold"
        function togglePanel() { pluginApi?.withCurrentScreen(s => pluginApi.togglePanel(s)) }
        function set(value: string) { 
          var numValue = parseInt(value)
          if (numValue >= service.batteryMinThresh && numValue <= service.batteryMaxThresh) {
              service.setThreshold(numValue)
          }
        }
    }
}
