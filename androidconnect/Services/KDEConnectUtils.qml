pragma Singleton

import QtQuick

QtObject {
  function getConnectionStateIcon(device, daemonAvailable) {
    if (!daemonAvailable)
      return "exclamation-circle";

    if (device === null || !device.reachable)
      return "device-mobile-off";

    if (device.battery >= 0 && device.battery < 10)
      return "device-mobile-exclamation"

    if (device.notificationIds.length > 0)
      return "device-mobile-message";
    else if (device.charging)
      return "device-mobile-bolt";
    else
      return "device-mobile";
  }

  // Returns raw state keys for translation
  function getConnectionStateKey(device, daemonAvailable) {
    if (!daemonAvailable)
      return "control_center.state.unavailable";

    if (device === null)
      return "control_center.state.no-device";

    if (!device.reachable)
      return "control_center.state.disconnected";

    if (!device.paired)
      return "control_center.state.not-paired";

    return "control_center.state.connected";
  }
}
