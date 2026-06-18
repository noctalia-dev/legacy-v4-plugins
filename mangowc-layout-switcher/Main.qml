import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Compositor
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  visible: CompositorService.isMango

  IpcHandler {
    target: "plugin:mangowc-layout-switcher"
    function toggle() {
      if (!CompositorService.isMango) return
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.openPanel(screen)
        })
      }
    }
  }

  property bool useNewIpc: false

  readonly property var availableLayouts: [
    { code: "T",  name: "Tile" },
    { code: "S",  name: "Scroller" },
    { code: "G",  name: "Grid" },
    { code: "M",  name: "Monocle" },
    { code: "K",  name: "Deck" },
    { code: "CT", name: "Center Tile" },
    { code: "RT", name: "Right Tile" },
    { code: "VS", name: "Vertical Scroller" },
    { code: "VT", name: "Vertical Tile" },
    { code: "VG", name: "Vertical Grid" },
    { code: "VK", name: "Vertical Deck" },
    { code: "DW", name: "Dwindle" },
    { code: "F",  name: "Fair" },
    { code: "VF", name: "Vertical Fair" },
  ]

  readonly property var layoutDispatchMap: ({
    "T": "tile", "S": "scroller", "G": "grid", "M": "monocle",
    "K": "deck", "CT": "center_tile", "RT": "right_tile",
    "VS": "vertical_scroller", "VT": "vertical_tile",
    "VG": "vertical_grid", "VK": "vertical_deck",
    "DW": "dwindle", "F": "fair", "VF": "vertical_fair",
  })

  // ===== PUBLIC DATA =====
  property var monitorLayouts: ({})
  property var availableMonitors: []

  // ===== UTILITY =====
  function getLayoutName(code) {
    for (var i = 0; i < root.availableLayouts.length; i++)
      if (root.availableLayouts[i].code === code) return root.availableLayouts[i].name
    return code
  }

  // ===== INTERNAL =====
  QtObject {
    id: internal
    function updateLayout(monitor, layout) {
      if (layout && monitor && root.monitorLayouts[monitor] !== layout) {
        root.monitorLayouts[monitor] = layout
        root.monitorLayoutsChanged()
      }
    }
  }

  // ===== PROCESSES =====

  Process {
    id: ipcProbe
    command: ["mmsg", "get", "all-monitors"]
    running: true

    stdout: SplitParser {
      onRead: line => {
        try {
          var json = JSON.parse(line)
          if (json.monitors) {
            root.useNewIpc = true
          }
        } catch (e) {}
        ipcProbe.running = false
      }
    }

    onExited: exitCode => {
      eventWatcher.start()
      monitorsQuery.start()
    }
  }

  Process {
    id: eventWatcher
    command: []
    running: false

    stdout: SplitParser {
      onRead: line => {
        if (root.useNewIpc) {
          try {
            var json = JSON.parse(line)
            if (json.monitors) {
              for (var i = 0; i < json.monitors.length; i++) {
                var m = json.monitors[i]
                internal.updateLayout(m.name, m.layout_symbol)
              }
            }
          } catch (e) {
            Logger.w("mangowc-layout-switcher: parse error: " + e)
          }
        } else {
          if (line.includes(" layout ")) {
            var match = line.match(/^(\S+)\s+layout\s+(\S+)$/)
            if (match) {
              internal.updateLayout(match[1], match[2])
            }
          }
        }
      }
    }

    function start() {
      command = root.useNewIpc ? ["mmsg", "watch", "all-monitors"] : ["mmsg", "-w"]
      running = true
    }
  }

  Process {
    id: monitorsQuery
    command: []
    running: false
    property var tempArray: []

    stdout: SplitParser {
      onRead: line => {
        if (root.useNewIpc) {
          try {
            var json = JSON.parse(line)
            if (json.monitors)
              monitorsQuery.tempArray = json.monitors.map(m => m.name)
          } catch (e) {}
        } else {
          const m = line.trim()
          if (m && !monitorsQuery.tempArray.includes(m)) {
            monitorsQuery.tempArray.push(m)
          }
        }
      }
    }

    onExited: exitCode => {
      if (exitCode === 0) root.availableMonitors = monitorsQuery.tempArray
      monitorsQuery.tempArray = []
    }

    function start() {
      command = root.useNewIpc ? ["mmsg", "get", "all-monitors"] : ["mmsg", "-O"]
      running = true
    }
  }

  // ===== PUBLIC API =====

  function refresh() {
    monitorsQuery.start()
    if (!eventWatcher.running) eventWatcher.start()
  }

  function setLayout(monitorName, layoutCode) {
    if (!monitorName || !layoutCode) return

    if (root.useNewIpc) {
      var dispatchName = root.layoutDispatchMap[layoutCode] || layoutCode
      Quickshell.execDetached(["mmsg", "dispatch", "focusmon," + monitorName])
      Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + dispatchName])
    } else {
      Quickshell.execDetached(["mmsg", "-o", monitorName, "-s", "-l", layoutCode])
    }

    internal.updateLayout(monitorName, layoutCode)
  }

  function setLayoutGlobally(layoutCode) {
    if (root.useNewIpc) {
      var dispatchName = root.layoutDispatchMap[layoutCode] || layoutCode
      root.availableMonitors.forEach(m => {
        Quickshell.execDetached(["mmsg", "dispatch", "focusmon," + m])
        Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + dispatchName])
      })
    } else {
      root.availableMonitors.forEach(m => setLayout(m, layoutCode))
    }
    ToastService.showNotice("Global layout set: " + layoutCode)
  }
}
