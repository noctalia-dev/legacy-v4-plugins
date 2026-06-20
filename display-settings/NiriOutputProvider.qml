import QtQuick
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var outputs: []
  property bool loading: false
  property bool modifying: false

  signal refreshed()
  signal modifySucceeded()

  property var queryLines: []

  function refresh() {
    if (queryProcess.running) return
    if (outputs.length === 0) loading = true
    queryLines = []
    queryProcess.running = true
  }

  function setMode(name, mode) { runModify([name, "mode", mode]) }
  function setScale(name, scale) { runModify([name, "scale", String(scale)]) }
  function setTransform(name, t) { runModify([name, "transform", t]) }
  function setVrr(name, on) { runModify([name, "vrr", on ? "on" : "off"]) }
  function setPower(name, on) { runModify([name, on ? "on" : "off"]) }

  function runModify(args) {
    if (modifyProcess.running) return
    modifying = true
    modifyProcess.command = ["niri", "msg", "output"].concat(args)
    modifyProcess.running = true
  }

  Process {
    id: queryProcess
    command: ["niri", "msg", "--json", "outputs"]
    stdout: SplitParser { onRead: data => root.queryLines.push(data) }
    onExited: exitCode => {
      if (exitCode === 0 && root.queryLines.length > 0) {
        root.outputs = root.parseOutputs(root.queryLines.join("\n"))
      }
      root.queryLines = []
      root.loading = false
      root.refreshed()
    }
  }

  Process {
    id: modifyProcess
    onExited: exitCode => {
      root.modifying = false
      if (exitCode === 0) {
        root.modifySucceeded()
      } else {
        Logger.w("DisplaySettings", "niri msg output failed with exit code " + exitCode)
      }
    }
  }

  function parseOutputs(jsonStr) {
    var data
    try {
      data = JSON.parse(jsonStr)
    } catch (e) {
      Logger.e("DisplaySettings", "Failed to parse niri msg output: " + e)
      return []
    }
    var result = Object.keys(data).map(name => buildOutput(name, data[name]))
    result.sort((a, b) => a.name.localeCompare(b.name))
    return result
  }

  function buildOutput(name, raw) {
    var logical = raw.logical || null
    var modes = (raw.modes || []).map(buildMode)
    var currentModeIdx = (raw.current_mode != null) ? raw.current_mode : -1
    var currentMode = currentModeIdx >= 0 ? modes[currentModeIdx] : null

    return {
      name: raw.name || name,
      make: raw.make || "",
      model: raw.model || "",
      resolution: currentMode ? (currentMode.width + "x" + currentMode.height) : "",
      refreshRate: currentMode ? (parseFloat(currentMode.refreshRate).toFixed(1) + " Hz") : "",
      scale: logical ? String(logical.scale) : "",
      transform: logical ? normalizeTransform(logical.transform) : "normal",
      position: logical ? (logical.x + "," + logical.y) : "",
      vrrSupported: raw.vrr_supported || false,
      vrrEnabled: raw.vrr_enabled || false,
      enabled: logical !== null,
      modes: modes,
      currentModeIndex: currentModeIdx
    }
  }

  function buildMode(m) {
    var rateHz = m.refresh_rate / 1000
    return {
      width: m.width,
      height: m.height,
      refreshRate: rateHz.toFixed(3),
      isPreferred: m.is_preferred || false,
      label: m.width + "x" + m.height + "@" + rateHz.toFixed(3)
    }
  }

  function normalizeTransform(t) {
    return (t || "normal").toLowerCase().replace(/^flipped(\d)/, "flipped-$1")
  }
}
