import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  property int fanState: -1

  property string statePath: Qt.resolvedUrl(Quickshell.env("XDG_RUNTIME_DIR") + "/fan_state")

  property Process getFanState: Process {
    id: getFanStateProcess
    command: ["fan_state", "get", "--int"]
    running: false

    stdout: StdioCollector {
      id: stdoutCollector
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode === 0) {
        const output = parseInt(stdoutCollector.text.trim());
        if (!isNaN(output)) {
          root.fanState = output;
        } else {
          Logger.e("ASUS Fan State", "Failed to parse output as integer");
        }
      } else {
        Logger.e("ASUS Fan State", "Failed to get fan state");
      }
    }
  }

  property FileView fanStateFile: FileView {
    id: fanFile
    path: root.statePath
    watchChanges: true
    printErrors: false

    onFileChanged: {
      Logger.i("ASUS Fan State", "Reloading fan state");
      root.refreshFanState();
    }
  }

  Component.onCompleted: {
    getFanStateProcess.running = true;
  }

  function setFanState(value) {
    Quickshell.execDetached(["fan_state", "set", value]);
  }

  function refreshFanState() {
    getFanStateProcess.running = true;
  }
}
