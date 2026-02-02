import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  IpcHandler {
    target: "plugin:mangowc-layout-switcher"
    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.openPanel(screen);
        });
      }
    }
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

    property var fetchQueue: []
    property bool busy: false

    function updateLayout(monitor, layout) {
      if (layout && monitor) {
        var cleanLayout = layout.trim()
        if (root.monitorLayouts[monitor] !== cleanLayout) {
          root.monitorLayouts[monitor] = cleanLayout
          root.monitorLayoutsChanged()
        }
      }
    }

    // Process the next monitor in the queue
    function processQueue() {
      if (internal.busy || internal.fetchQueue.length === 0) return
      
      internal.busy = true
      var nextMonitor = internal.fetchQueue.shift()
      layoutFetcher.targetMonitor = nextMonitor
      layoutFetcher.command = ["mmsg", "-o", nextMonitor, "-g", "-l"]
      layoutFetcher.running = true
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
        // Match: "OUTPUT layout CODE" (e.g., "eDP-1 layout T")
        var match = line.match(/^(\S+)\s+layout\s+(\S+)$/)
        if (match) {
          internal.updateLayout(match[1], match[2])
        }
      }
    }
  }

  // 2. Initial Layout Fetcher (Queue Worker)
  Process {
    id: layoutFetcher
    property string targetMonitor: ""
    running: false
    
    stdout: SplitParser {
      onRead: line => internal.updateLayout(layoutFetcher.targetMonitor, line)
    }
    
    onExited: exitCode => {
      internal.busy = false
      internal.processQueue()
    }
  }

  // 3. Load Available Layouts (mmsg -L)
  Process {
    id: layoutsQuery
    command: ["mmsg", "-L"]
    running: false
    
    stdout: SplitParser {
      onRead: line => {
        const code = line.trim()
        if (code && code.length > 0 && !root.availableLayouts.some(l => l.code === code)) {
           const name = root.getLayoutName(code)
           root.availableLayouts.push({ code: code, name: name })
        }
      }
    }
    
    onExited: exitCode => { 
      if (exitCode === 0) root.availableLayoutsChanged() 
    }
  }

  // 4. Load Monitors (mmsg -O)
  Process {
    id: monitorsQuery
    command: ["mmsg", "-O"]
    running: false
    
    stdout: SplitParser {
      onRead: line => {
        const m = line.trim()
        if (m && !root.availableMonitors.includes(m)) {
          root.availableMonitors.push(m)
        }
      }
    }
    
    onExited: exitCode => {
      if (exitCode === 0) {
        root.availableMonitorsChanged()
        // Queue a fetch for each detected monitor
        root.availableMonitors.forEach(m => internal.fetchQueue.push(m))
        internal.processQueue()
      }
    }
  }

  // ===== PUBLIC API =====

  function refresh() {
    root.availableLayouts = []
    root.availableMonitors = []
    layoutsQuery.running = true
    monitorsQuery.running = true
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

  Component.onCompleted: refresh()
}
