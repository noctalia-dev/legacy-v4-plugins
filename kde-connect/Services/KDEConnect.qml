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
  property string busctlCmd: ""

  property bool anyDevicesConnected: false;

  onDevicesChanged: {
    setMainDevice(root.mainDeviceId)
  }

  Component.onCompleted: {
    checkDaemon();
  }

  // Check if KDE Connect daemon is available
  function checkDaemon(): void {
    detectBusctlProc.running = true;
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

    anyDevicesConnected = devices.find((device) => device.reachable) !== undefined;
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

  function wakeUpDevice(deviceId: string): void {
    const proc = wakeUpDeviceComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  function busctlCall(obj, itf, method, params = []) {
    let result = [ root.busctlCmd, "--user", "call", "--json=short", "org.kde.kdeconnect", obj, itf, method ];
    return result.concat(params);
  }

  function busctlGet(obj, itf, prop) {
    return [ root.busctlCmd, "--user", "get-property", "--json=short", "org.kde.kdeconnect", obj, itf, prop ];
  }

  function busctlData(text) {
    if (text === "")
      return "";

    try {
      let result = JSON.parse(text)?.data;
      if (Array.isArray(result) && Array.isArray(result[0]))
        return result[0]
      else
        return result;
    } catch (e) {
      Logger.e("KDEConnect", "Failed to parse busctl response: ", text)
      return null;
    }
  }

  property Process detectBusctlProc: Process {
    command: ["which", "busctl"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.busctlCmd !== "") {
          root.daemonCheckProc.running = true
          return
        }

        let location = text.trim()
        if (location !== "") {
          root.busctlCmd = location
          root.daemonCheckProc.running = true
          Logger.i("KDEConnect", "Found busctl command:", location)
        }
      }
    }
  }

  // Check daemon
  property Process daemonCheckProc: Process {
    command: [root.busctlCmd, "--user", "status", "org.kde.kdeconnect"]
    onExited: (exitCode, exitStatus) => {
      root.daemonAvailable = exitCode == 0;
      if (root.daemonAvailable) {
        forceOnNetworkChange.running = true;
      } else {
        root.devices = []
        root.mainDevice = null
      }
    }
  }

  property Process forceOnNetworkChange: Process {
  command: busctlCall("/modules/kdeconnect", "org.kde.kdeconnect.daemon", "forceOnNetworkChange")
  stdout: StdioCollector {
    onStreamFinished: {
      getDevicesProc.running = true;
    }
  }
}

  // Get device list
  property Process getDevicesProc: Process {
    command: busctlCall("/modules/kdeconnect", "org.kde.kdeconnect.daemon", "devices")
    stdout: StdioCollector {
      onStreamFinished: {
        const deviceIds = busctlData(text);

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
        nameProc.running = true
      }

      property Process nameProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "name")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.name = busctlData(text);

            reachableProc.running = true;
          }
        }
      }

      property Process reachableProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isReachable")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.reachable = busctlData(text);

            pairingRequestedProc.running = true;
          }
        }
      }

      property Process pairingRequestedProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isPairRequested")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.pairRequested = busctlData(text);

            verificationKeyProc.running = true;
          }
        }
      }

      property Process verificationKeyProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "verificationKey")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.verificationKey = busctlData(text);

            pairedProc.running = true;
          }
        }
      }

      property Process pairedProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device", "isPaired")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.paired = busctlData(text);

            if (loader.deviceData.paired)
              activeNotificationsProc.running = true;
            else
              finalize()
          }
        }
      }

      property Process activeNotificationsProc: Process {
        command: busctlCall("/modules/kdeconnect/devices/" + loader.deviceId + "/notifications", "org.kde.kdeconnect.device.notifications", "activeNotifications");
        stdout: StdioCollector {
          onStreamFinished: {
            let ids = busctlData(text);
            loader.deviceData.notificationIds = ids

            cellularNetworkTypeProc.running = true;
          }
        }
      }

      property Process cellularNetworkTypeProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkType")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.cellularNetworkType = busctlData(text);
            cellularNetworkStrengthProc.running = true;
          }
        }
      }

      property Process cellularNetworkStrengthProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength")
        stdout: StdioCollector {
          onStreamFinished: {
            const strength = busctlData(text);
            loader.deviceData.cellularNetworkStrength = strength;
            isChargingProc.running = true;
          }
        }
      }

      property Process isChargingProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "isCharging")
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.charging = busctlData(text);
            batteryProc.running = true;
          }
        }
      }

      property Process batteryProc: Process {
        command: busctlGet("/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.kde.kdeconnect.device.battery", "charge")
        stdout: StdioCollector {
          onStreamFinished: {
            const charge = busctlData(text);
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

  // FindMyPhone component
  property Component findMyPhoneComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/findmyphone", "org.kde.kdeconnect.device.findmyphone", "ring")
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // SFTP Browse component
  property Component browseFilesComponent: Component {
    Process {
      id: mountProc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/sftp", "org.kde.kdeconnect.device.sftp", "mountAndWait")
      stdout: StdioCollector {
        onStreamFinished: rootDirProc.running = true
      }

      property Process rootDirProc: Process {
        command: busctlCall("/modules/kdeconnect/devices/" + mountProc.deviceId + "/sftp", "org.kde.kdeconnect.device.sftp", "getDirectories")
        stdout: StdioCollector {
          onStreamFinished: {
            const dirs = busctlData(text);
            const path = Object.keys(dirs[0])[0];
            if (!Qt.openUrlExternally("file://" + path)) {
              Logger.e("KDEConnect", "Failed to open file manager for path:", path);
            }

            mountProc.destroy();
          }
        }
      }
    }
  }

  // Request Pairing Component
  property Component requestPairingComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device", "requestPairing")
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
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device", "unpair")
      stdout: StdioCollector {
        onStreamFinished: {
          KDEConnect.refreshDevices()
          proc.destroy()
        }
      }
    }
  }

  // Wake up Device Component
  property Component wakeUpDeviceComponent: Component {
    Process {
      id: proc
      property string deviceId: ""
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/remotecontrol", "org.kde.kdeconnect.device.remotecontrol", "sendCommand", [ "a{sv}", "1", "singleclick", "b", "true" ])
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
      command: busctlCall("/modules/kdeconnect/devices/" + deviceId + "/share", "org.kde.kdeconnect.device.share", "shareUrl", [ "file://" + filePath ])
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