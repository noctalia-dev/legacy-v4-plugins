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

  Component.onCompleted: {
    if (!CompositorService.isMango) return
    refresh()
  }

  // ===== PUBLIC DATA =====
  property var monitorLayouts: ({})
  property var availableLayouts: []
  property var availableMonitors: []

  // ===== CONSTANTS =====

  // Layout Name Mapping
  // Codes based on 'mmsg -L' output
  readonly property var layoutNames: ({
    "S": "Scroller",
    "T": "Tile",
    "G": "Grid",
    "M": "Monocle",
    "K": "Deck",
    "CT": "Center Tile",
    "RT": "Right Tile",
    "VS": "Vertical Scroller",
    "VT": "Vertical Tile",
    "VG": "Vertical Grid",
    "VK": "Vertical Deck",
    "TG": "Tgmix"
  })

  // ===== HELPER FUNCTIONS =====

  function getLayoutName(code) {
    if (root.layoutNames[code]) return root.layoutNames[code]
    
    // Fallback formatter for unknown codes (snake_case -> Title Case)
    return code.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
  }

  // ===== INTERNAL LOGIC =====

  QtObject {
    id: internal
    function updateLayout(monitor, layout) {
      if (layout && monitor) {
        var cleanLayout = layout.trim()
        if (root.monitorLayouts[monitor] !== cleanLayout) {
          root.monitorLayouts[monitor] = cleanLayout
          // Emitting the built-in signal directly is cheaper than cloning the whole object
          root.monitorLayoutsChanged() 
        }
      }
    }
  }

  // ===== PROCESSES =====

  // 1. Event Watcher (mmsg -w) - Realtime Updates
  Process {
    id: eventWatcher
    command: ["mmsg", "-w"]
    running: true 
    
    stdout: SplitParser {
      onRead: line => {
        // Only parse layout-related outputs to save regex cycles
        if (line.includes(" layout ")) {
          var match = line.match(/^(\S+)\s+layout\s+(\S+)$/)
          if (match) {
            internal.updateLayout(match[1], match[2])
          }
        }
      }
    }
  }

  // 2. Load Available Layouts (mmsg -L) - Runs once
  Process {
    id: layoutsQuery
    command: ["mmsg", "-L"]
    running: false
    property var tempArray: []
    
    stdout: SplitParser {
      onRead: line => {
        const code = line.trim()
        if (code && !layoutsQuery.tempArray.some(l => l.code === code)) {
           layoutsQuery.tempArray.push({ code: code, name: root.getLayoutName(code) })
        }
      }
    }
    
    onExited: exitCode => { 
      if (exitCode === 0) root.availableLayouts = layoutsQuery.tempArray
      layoutsQuery.tempArray = [] 
    }
  }

  // 3. Load Monitors (mmsg -O) - Runs once
  Process {
    id: monitorsQuery
    command: ["mmsg", "-O"]
    running: false
    property var tempArray: []
    
    stdout: SplitParser {
      onRead: line => {
        const m = line.trim()
        if (m && !monitorsQuery.tempArray.includes(m)) {
          monitorsQuery.tempArray.push(m)
        }
      }
    }
    
    onExited: exitCode => {
      if (exitCode === 0) root.availableMonitors = monitorsQuery.tempArray
      monitorsQuery.tempArray = [] 
    }
  }

  // ===== PUBLIC API =====

  function refresh() {
    layoutsQuery.running = true
    monitorsQuery.running = true
    // Restart watcher if it died
    if (!eventWatcher.running) eventWatcher.running = true 
  }

  function setLayout(monitorName, layoutCode) {
    if (!monitorName || !layoutCode) return
    // Execute: mmsg -o <monitor> -s -l <code >
    Quickshell.execDetached(["mmsg", "-o", monitorName, "-s", "-l", layoutCode])
    // Optimistic Update
    internal.updateLayout(monitorName, layoutCode)
  }

  function setLayoutGlobally(layoutCode) {
    root.availableMonitors.forEach(m => setLayout(m, layoutCode))
    ToastService.showNotice("Global layout set: " + layoutCode)
  }
}
