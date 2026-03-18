pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

QtObject {
  id: root

  property list<var> devices: []
  property bool daemonAvailable: false
  property int pendingDeviceCount: 0
  property list<var> pendingDevices: []

  property var mainDevice: null
  property string mainDeviceId: ""

  property string qdbusCmd: ""
  readonly property var qdbusOptions: ["qdbus6", "qdbus", "qdbus-qt6"]
  property int qdbusOptionIndex: 0

  onDevicesChanged: {
    setMainDevice(root.mainDeviceId)
  }

  Component.onCompleted: {
    checkDaemon();
  }

  // Check if KDE Connect daemon is available
  function checkDaemon(): void {
    qdbusDetectQDbusProc.running = true;
  }

  // Refresh the list of devices
  function refreshDevices(): void {
    getDevicesProc.running = true;
  }

  function setMainDevice(deviceId: string): void {
    root.mainDeviceId = deviceId;
    updateMainDevice(false);
  }

  function updateMainDevice(checkReachable) {
    let newMain;
    if (checkReachable) {
      newMain = devices.find((device) => device.id === root.mainDeviceId && device.reachable);
      if (newMain === undefined)
        newMain = devices.find((device) => device.reachable);
      if (newMain === undefined)
        newMain = devices.length === 0 ? null : devices[0];
    } else {
      newMain = devices.find((device) => device.id === root.mainDeviceId);
      if (newMain === undefined)
        newMain = devices.length === 0 ? null : devices[0];
    }

    if (root.mainDevice !== newMain) {
      root.mainDevice = newMain;
    }
  }

  // Send a ping to a device
  function pingDevice(deviceId: string): void {
    const proc = pingComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  function triggerFindMyPhone(deviceId: string): void {
    const proc = findMyPhoneComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

    function browseFiles(deviceId: string): void {
    const proc = browseFilesComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  // Share a file with a device
  function shareFile(deviceId: string, filePath: string): void {
    var proc = shareComponent.createObject(root, {
      deviceId: deviceId,
      filePath: filePath
    });
    proc.running = true;
  }

  function requestPairing(deviceId: string): void {
    const proc = requestPairingComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  function unpairDevice(deviceId: string): void {
    const proc = unpairingComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  property Process qdbusDetectQDbusProc: Process {
    command: ["which", qdbusOptions[qdbusOptionIndex]]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.qdbusCmd !== "") {
          root.daemonCheckProc.running = true
          return
        }

        let location = text.trim()
        if (location !== "") {
          root.qdbusCmd = location
          root.daemonCheckProc.running = true
          Logger.i("KDEConnect", "Found qdbus command:", location)
        } else if (qdbusOptionIndex < qdbusOptions.length - 1) {
          qdbusOptionIndex++
          qdbusDetectQDbusProc.running = true
        }
      }
    }
  }

  // Check daemon
  property Process daemonCheckProc: Process {
    command: [qdbusCmd]
    stdout: StdioCollector {
      onStreamFinished: {
        root.daemonAvailable = text.trim().includes("org.kde.kdeconnect")
        if (root.daemonAvailable) {
          root.refreshDevices();
        } else {
          root.devices = []
          root.mainDevice = null
        }
      }
    }
  }

  // Get device list
  property Process getDevicesProc: Process {
    command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon.devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        const deviceIds = text.trim().split('\n').filter(id => id.length > 0);

        root.pendingDevices = [];
        root.pendingDeviceCount = deviceIds.length;

        deviceIds.forEach(deviceId => {
          const loader = deviceLoaderComponent.createObject(root, { deviceId: deviceId });
          loader.start();
        });
      }
    }
  }

  // Component that loads all info for a single device
  property Component deviceLoaderComponent: Component {
    QtObject {
      id: loader
      property string deviceId: ""
      property var deviceData: ({
        id: deviceId,
        name: "",
        reachable: false,
        paired: false,
        pairRequested: false,
        verificationKey: "",
        charging: false,
        battery: -1,
        cellularNetworkType: "",
        cellularNetworkStrength: -1,
        notificationIds: []
      })

      function start() {
        forceOnNetworkChange.running = true
      }

      property Process forceOnNetworkChange: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon.forceOnNetworkChange"]
        stdout: StdioCollector {
          onStreamFinished: {
            nameProc.running = true;
          }
        }
      }

      property Process nameProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.name"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.name = text.trim();

            reachableProc.running = true;
          }
        }
      }

      property Process reachableProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.isReachable"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.reachable = text.trim() === "true";

            pairingRequestedProc.running = true;
          }
        }
      }

      property Process pairingRequestedProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.isPairRequested"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.pairRequested = text.trim() === "true";

            verificationKeyProc.running = true;
          }
        }
      }

      property Process verificationKeyProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.verificationKey"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.verificationKey = text.trim();

            pairedProc.running = true;
          }
        }
      }

      property Process pairedProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.isPaired"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.paired = text.trim() === "true";

            if (loader.deviceData.paired)
              activeNotificationsProc.running = true;
            else
              finalize()
          }
        }
      }

      property Process activeNotificationsProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/notifications", "org.kde.kdeconnect.device.notifications.activeNotifications"]
        stdout: StdioCollector {
          onStreamFinished: {
            if (!text.trim().startsWith("Error:")) {
              let ids = text.trim().split("\n")
              loader.deviceData.notificationIds = ids.length === 1 && ids[0] === "" ? [] : ids
            }

            cellularNetworkTypeProc.running = true;
          }
        }
      }

      property Process cellularNetworkTypeProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkType"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.cellularNetworkType = text.trim();
            cellularNetworkStrengthProc.running = true;
          }
        }
      }

      property Process cellularNetworkStrengthProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength"]
        stdout: StdioCollector {
          onStreamFinished: {
            const strength = parseInt(text.trim());
            if (!isNaN(strength)) {
              loader.deviceData.cellularNetworkStrength = strength;
            }
            isChargingProc.running = true;
          }
        }
      }

      property Process isChargingProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.battery", "isCharging"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.charging = text.trim() === "true";
            batteryProc.running = true;
          }
        }
      }

      property Process batteryProc: Process {
        command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.battery", "charge"]
        stdout: StdioCollector {
          onStreamFinished: {
            const charge = parseInt(text.trim());
            if (!isNaN(charge)) {
              loader.deviceData.battery = charge;
            }

            finalize();
          }
        }
      }

      function finalize() {
        root.pendingDevices = root.pendingDevices.concat([loader.deviceData]);

        if (root.pendingDevices.length === root.pendingDeviceCount) {
          let newDevices = root.pendingDevices
          newDevices.sort((a, b) => a.name.localeCompare(b.name))

          let prevMainDevice = root.devices.find((device) => device.id === root.mainDeviceId);
          let newMainDevice = newDevices.find((device) => device.id === root.mainDeviceId);

          let deviceNotReachableAnymore =
            prevMainDevice === undefined ||
            (
              (prevMainDevice?.reachable ?? false) &&
              !(newMainDevice?.reachable ?? false)
            ) ||
            (
              (prevMainDevice?.paired ?? false) &&
              !(newMainDevice?.paired ?? false)
            )

          root.devices = newDevices
          root.pendingDevices = []
          updateMainDevice(deviceNotReachableAnymore);
        }

        loader.destroy();
      }
    }
  }

  // Ping component
  property Component pingComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device.sendPing"]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // FindMyPhone component
  property Component findMyPhoneComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId + "/findmyphone", "org.kde.kdeconnect.device.findmyphone.ring"]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // SFTP Browse component
  property Component browseFilesComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      property var mountArgs: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId + "/sftp", "org.kde.kdeconnect.device.sftp.mountAndWait"]
      property var getDirsArgs: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId + "/sftp", "org.kde.kdeconnect.device.sftp.getDirectories"]
      command: ["sh", "-c", mountArgs.join(" ") + " && xdg-open $(" + getDirsArgs.join(" ") + " | head -n1 | cut -d: -f1)"]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // Request Pairing Component
  property Component requestPairingComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device.requestPairing"]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // Unpairing Component
  property Component unpairingComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device.unpair"]
      stdout: StdioCollector {
        onStreamFinished: {
          KDEConnect.refreshDevices()
          proc.destroy()
        }
      }
    }
  }

  // Share file component
  property Component shareComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      property string filePath: ""
      command: [qdbusCmd, "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId + "/share", "org.kde.kdeconnect.device.share.shareUrl", "file://" + filePath]
      stdout: StdioCollector {
        onStreamFinished: {
          proc.destroy()
        }
      }
    }
  }

  // Periodic refresh timer
  property Timer refreshTimer: Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.checkDaemon()
  }
}