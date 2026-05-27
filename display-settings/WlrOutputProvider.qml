import QtQuick
import Quickshell.Io

Item {
  id: root

  property var outputs: []
  property bool loading: false

  signal refreshed()

  property var lines: []

  function refresh() {
    if (process.running) return
    if (outputs.length === 0) loading = true
    lines = []
    process.running = true
  }

  Process {
    id: process
    command: ["wlr-randr"]
    stdout: SplitParser { onRead: data => root.lines.push(data) }
    onExited: exitCode => {
      if (exitCode === 0) {
        root.outputs = root.parse(root.lines)
      }
      root.lines = []
      root.loading = false
      root.refreshed()
    }
  }

  readonly property var fieldPrefixes: ({
    "Make:": "make",
    "Model:": "model",
    "Physical size:": "physicalSize",
    "Enabled:": "enabled",
    "Position:": "position",
    "Transform:": "transform",
    "Scale:": "scale",
    "Adaptive Sync:": "adaptiveSync"
  })

  readonly property var nameRe: /^(\S+)/
  readonly property var modeLineRe: /^\d+x\d+/
  readonly property var currentModeRe: /(\d+x\d+)\s*px,\s*([\d.]+)\s*Hz/

  function parse(rawLines) {
    var outputs = []
    var current = null
    var inModes = false

    for (var i = 0; i < rawLines.length; i++) {
      var line = rawLines[i]

      if (isOutputHeader(line)) {
        if (current) outputs.push(current)
        current = newOutput(line)
        inModes = false
        continue
      }

      if (!current) continue
      var trimmed = line.trim()

      if (trimmed.startsWith("Modes:")) {
        inModes = true
        continue
      }

      var fieldHit = matchField(trimmed)
      if (fieldHit) {
        current[fieldHit.field] = trimmed.substring(fieldHit.prefix.length).trim()
        inModes = false
        continue
      }

      if (inModes && trimmed.match(modeLineRe) && trimmed.includes("current")) {
        applyCurrentMode(current, trimmed)
      }
    }

    if (current) outputs.push(current)
    return outputs
  }

  function isOutputHeader(line) {
    return line.length > 0 && line[0] !== ' ' && line[0] !== '\t'
  }

  function newOutput(line) {
    var m = line.match(nameRe)
    return {
      name: m ? m[1] : line.trim(),
      make: "", model: "", physicalSize: "",
      enabled: "", resolution: "", refreshRate: "",
      position: "", transform: "", scale: "", adaptiveSync: ""
    }
  }

  function matchField(trimmed) {
    for (var prefix in fieldPrefixes) {
      if (trimmed.startsWith(prefix)) {
        return { prefix: prefix, field: fieldPrefixes[prefix] }
      }
    }
    return null
  }

  function applyCurrentMode(out, trimmed) {
    var m = trimmed.match(currentModeRe)
    if (m) {
      out.resolution = m[1]
      out.refreshRate = parseFloat(m[2]).toFixed(1) + " Hz"
    }
  }
}
