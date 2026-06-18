import QtQuick
import Quickshell.Io

Item {
  id: root

  property bool active: false
  property int debounceMs: 500

  signal triggered()

  function start() {
    if (active) return
    active = true
    process.running = true
  }

  function stop() {
    active = false
    process.running = false
    debounce.stop()
  }

  Component.onDestruction: stop()

  Process {
    id: process
    command: ["udevadm", "monitor", "--subsystem-match=drm"]
    stdout: SplitParser {
      onRead: () => { if (root.active) debounce.restart() }
    }
  }

  Timer {
    id: debounce
    interval: root.debounceMs
    repeat: false
    onTriggered: root.triggered()
  }
}
