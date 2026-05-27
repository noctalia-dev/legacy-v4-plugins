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
    id: eventWatcher
    command: ["mmsg", "watch", "all-monitors"]
    running: true

    stdout: SplitParser {
      onRead: line => {
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
      }
    }
  }

  Process {
    id: monitorsQuery
    command: ["mmsg", "get", "all-monitors"]
    running: false
    property var tempArray: []

    stdout: SplitParser {
      onRead: line => {
        try {
          var json = JSON.parse(line)
          if (json.monitors)
            monitorsQuery.tempArray = json.monitors.map(m => m.name)
        } catch (e) {}
      }
    }

    onExited: exitCode => {
      if (exitCode === 0) root.availableMonitors = monitorsQuery.tempArray
      monitorsQuery.tempArray = []
    }
  }

  Component.onCompleted: {
    monitorsQuery.running = true
  }

  // ===== PUBLIC API =====

  function refresh() {
    monitorsQuery.running = true
    if (!eventWatcher.running) eventWatcher.running = true
  }

  function setLayout(monitorName, layoutCode) {
    if (!monitorName || !layoutCode) return
    var dispatchName = root.layoutDispatchMap[layoutCode] || layoutCode
    Quickshell.execDetached(["mmsg", "dispatch", "focusmon," + monitorName])
    Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + dispatchName])
    internal.updateLayout(monitorName, layoutCode)
  }

  function setLayoutGlobally(layoutCode) {
    var dispatchName = root.layoutDispatchMap[layoutCode] || layoutCode
    root.availableMonitors.forEach(m => {
      Quickshell.execDetached(["mmsg", "dispatch", "focusmon," + m])
      Quickshell.execDetached(["mmsg", "dispatch", "setlayout," + dispatchName])
    })
    ToastService.showNotice("Global layout set: " + layoutCode)
  }
}
