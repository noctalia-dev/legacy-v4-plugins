import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property string configPath: "~/.config/niri/config.kdl"
  property var outputs: []
  property bool loading: false

  signal parsed()

  readonly property string homeDir: Quickshell.env("HOME") || ""

  property var filesToParse: []
  property var parsedFiles: ({})
  property var collectedLines: []
  property var currentFileLines: []
  property int parseDepth: 0

  readonly property int maxDepth: 20
  readonly property int maxGlobMatches: 100
  readonly property int maxLinesPerFile: 10000

  readonly property var includeRe: /(?:include|source)\s+"([^"]+)"/i
  readonly property var outputBlockRe: /^output\s+"([^"]+)"\s*\{/
  readonly property var openBraceRe: /\{/g
  readonly property var closeBraceRe: /\}/g
  readonly property var modeRe: /^mode\s+"([^"]+)"/
  readonly property var scaleRe: /^scale\s+([\d.]+)/
  readonly property var transformRe: /^transform\s+"([^"]+)"/
  readonly property var positionRe: /^position\s+x=(-?\d+)\s+y=(-?\d+)/

  function start() {
    var resolved = configPath.replace(/^~/, homeDir)
    filesToParse = [resolved]
    parsedFiles = {}
    collectedLines = []
    parseDepth = 0
    loading = true
    parseNextFile()
  }

  function parseNextFile() {
    if (parseDepth >= maxDepth || filesToParse.length === 0) {
      finalize()
      return
    }
    parseDepth++

    var nextFile = filesToParse.shift()

    if (isGlob(nextFile)) {
      expandGlob(nextFile)
      return
    }

    if (parsedFiles[nextFile]) {
      parseNextFile()
      return
    }

    parsedFiles[nextFile] = true
    currentFileLines = []
    readProcess.currentFilePath = nextFile
    readProcess.command = ["cat", nextFile]
    readProcess.running = true
  }

  function finalize() {
    outputs = parseOutputBlocks(collectedLines.join("\n"))
    collectedLines = []
    loading = false
    parsed()
  }

  function isGlob(path) {
    return path.indexOf('*') !== -1 || path.indexOf('?') !== -1
  }

  function expandGlob(path) {
    globProcess.expandedFiles = []
    globProcess.command = ["sh", "-c", "for f in " + path + "; do [ -f \"$f\" ] && echo \"$f\"; done"]
    globProcess.running = true
  }

  function getDirectoryFromPath(filePath) {
    var lastSlash = filePath.lastIndexOf('/')
    return lastSlash >= 0 ? filePath.substring(0, lastSlash) : "."
  }

  function resolveRelativePath(basePath, relativePath) {
    var resolved = relativePath.replace(/^~/, homeDir)
    if (resolved.startsWith('/')) return resolved
    return getDirectoryFromPath(basePath) + "/" + resolved
  }

  function queueIfNew(path) {
    if (!parsedFiles[path] && filesToParse.indexOf(path) === -1) {
      filesToParse.push(path)
    }
  }

  Process {
    id: globProcess
    property var expandedFiles: []

    stdout: SplitParser {
      onRead: data => {
        var trimmed = data.trim()
        if (trimmed.length > 0 && globProcess.expandedFiles.length < root.maxGlobMatches) {
          globProcess.expandedFiles.push(trimmed)
        }
      }
    }

    onExited: {
      for (var i = 0; i < expandedFiles.length; i++) {
        root.queueIfNew(expandedFiles[i])
      }
      expandedFiles = []
      root.parseNextFile()
    }
  }

  Process {
    id: readProcess
    property string currentFilePath: ""

    stdout: SplitParser {
      onRead: data => {
        if (root.currentFileLines.length < root.maxLinesPerFile) {
          root.currentFileLines.push(data)
        }
      }
    }

    onExited: exitCode => {
      if (exitCode === 0 && root.currentFileLines.length > 0) {
        root.absorbLines(currentFilePath)
      }
      root.currentFileLines = []
      root.parseNextFile()
    }
  }

  function absorbLines(filePath) {
    for (var i = 0; i < currentFileLines.length; i++) {
      var line = currentFileLines[i]
      collectedLines.push(line)

      var inc = line.match(includeRe)
      if (inc) {
        queueIfNew(resolveRelativePath(filePath, inc[1]))
      }
    }
  }

  function parseOutputBlocks(text) {
    var outputs = []
    var lines = text.split('\n')
    var inBlock = false
    var current = null
    var braceDepth = 0

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()

      if (!inBlock) {
        if (line.startsWith("//") || line.startsWith("/-")) continue
        var header = line.match(outputBlockRe)
        if (header) {
          inBlock = true
          braceDepth = 1
          current = newConfigOutput(header[1])
        }
        continue
      }

      if (line.startsWith("//")) continue
      braceDepth += countMatches(line, openBraceRe) - countMatches(line, closeBraceRe)

      if (braceDepth <= 0) {
        if (current) outputs.push(current)
        inBlock = false
        current = null
        continue
      }

      applyConfigLine(current, line)
    }
    return outputs
  }

  function newConfigOutput(name) {
    return { name: name, mode: "", scale: "", transform: "", position: "", enabled: true, vrr: "" }
  }

  function countMatches(line, re) {
    return (line.match(re) || []).length
  }

  function applyConfigLine(out, line) {
    if (line === "off") { out.enabled = false; return }

    var m
    if ((m = line.match(modeRe))) { out.mode = m[1]; return }
    if ((m = line.match(scaleRe))) { out.scale = m[1]; return }
    if ((m = line.match(transformRe))) { out.transform = m[1]; return }
    if ((m = line.match(positionRe))) { out.position = m[1] + "," + m[2]; return }
    if (line.startsWith("variable-refresh-rate")) {
      out.vrr = line.replace("variable-refresh-rate", "").trim() || "on"
    }
  }
}
