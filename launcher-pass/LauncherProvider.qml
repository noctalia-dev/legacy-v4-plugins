import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var launcher: null
  property string name: "Launcher pass"
  property string supportedLayouts: "list"
  property bool handleSearch: false
  property bool supportsAutoPaste: false

  property var cachedEntries: []
  property bool loaded: false
  property string currentPath: ""
  property var entryStack: []
  property string searchQuery: ""

  property bool isDetailMode: false
  property var selectedEntry: null
  property string selectedAction: ""

  property bool pinentryActive: false
  property bool restoringFromPinentry: false

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string passwordStoreDir: cfg.storePath || defaults.storePath || (Quickshell.env("HOME") || "~") + "/.password-store"

  function shellEscape(str) {
    return str.replace(/'/g, "'\\''")
  }

  function resolveDir() {
    return currentPath === "" ? passwordStoreDir : passwordStoreDir + "/" + currentPath
  }

  function getSetting(key, fallback) {
    return (cfg[key] || defaults[key] || fallback)
  }

  function getClipTimeout() {
    var configured = cfg.clipTimeout ?? defaults.clipTimeout ?? ""
    if (configured !== "") {
      var num = parseInt(configured, 10)
      if (!isNaN(num) && num > 0) return num
    }
    var envValue = Quickshell.env("PASSWORD_STORE_CLIP_TIME") || ""
    if (envValue !== "") {
      var num = parseInt(envValue, 10)
      if (!isNaN(num) && num > 0) return num
    }
    return null
  }

  function getPassEnvironment() {
    var env = {
          "PASSWORD_STORE_DIR": passwordStoreDir,
    }
    var timeout = getClipTimeout()
    if (timeout != null) {
        env["PASSWORD_STORE_CLIP_TIME"] = String(timeout)
    }
    return env
  }

  Process {
    id: findProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        parseEntries(findProc.stdout.text, root.searchQuery !== "")
      }
      loaded = true
      if (launcher) launcher.updateResults()
    }
  }

  Process {
    id: showProc
    stdout: StdioCollector {}
    onStarted: {
      pinentryTimer.start()
    }
    onExited: function(exitCode, exitStatus) {
      pinentryTimer.stop()
      if (root.pinentryActive) {
        root.pinentryActive = false
        if (exitCode === 0) {
          var data = parsePassEntry(showProc.stdout.text)
          root.selectedEntry.data = data
          root.isDetailMode = true
          if (launcher) launcher.setSearchText(">pass ")
        }
        root.restoringFromPinentry = true
        pluginApi.withCurrentScreen(function(screen) {
          pluginApi.toggleLauncher(screen)
        })
        if (launcher) launcher.updateResults()
      } else if (exitCode === 0) {
        var data = parsePassEntry(showProc.stdout.text)
        root.selectedEntry.data = data
        root.isDetailMode = true
        if (launcher) {
          launcher.setSearchText(">pass ")
          launcher.updateResults()
        }
      }
    }
  }

  Process {
    id: otpProc
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) return
      if (root.selectedAction === "copy") {
        root.resetDetailMode()
        launcher.close()
        ToastService.showNotice(pluginApi?.tr("notification.copied"))
      } else if (root.selectedAction === "type") {
        var otp = otpProc.stdout.text.trim()
        var typeDelay = getSetting("typeDelay", 500)
        var wtypeDelay = getSetting("wtypeDelay", 12)
        var escValue = shellEscape(otp)
        root.resetDetailMode()
        launcher.close()
        actionProc.exec(["sh", "-c", "sleep " + (typeDelay / 1000) + " && printf '%s' '" + escValue + "' | wtype -d " + wtypeDelay + " -"])
      }
    }
  }

  Process {
    id: actionProc
    onExited: function(exitCode, exitStatus) {
      if (root.selectedAction === "copy" && exitCode === 0) {
        ToastService.showNotice(pluginApi?.tr("notification.copied"))
      }
    }
  }

  Timer {
    id: searchTimer
    interval: 200
    onTriggered: performSearch()
  }

  Timer {
    id: pinentryTimer
    interval: 300
    onTriggered: {
      if (showProc.running && showProc.stdout.text.trim() === "") {
        pinentryActive = true
        launcher.close()
      }
    }
  }

  function performSearch() {
    loaded = false
    var targetPath = resolveDir()
    var escapedPath = shellEscape(targetPath)
    if (searchQuery !== "") {
      findProc.exec(["find", escapedPath,
        "-mindepth", "1", "-type", "f", "-name", "*.gpg", "-printf", "%P\n"])
    } else {
      findProc.exec(["find", escapedPath,
        "-maxdepth", "1", "-mindepth", "1",
        "-type", "f", "-name", "*.gpg", "-printf", "%f\n",
        "-o", "-type", "d", "-not", "-name", ".*", "-printf", "%f/\n"])
    }
  }

  function parseEntries(text, isSearch) {
    var lines = text.split('\n').filter(function(l) { return l.trim() !== "" })
    var entries = []
    var seenDirs = {}
    var currentName = currentPath === "" ? "" : currentPath.split("/").pop()

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line === "") continue

      var isDir = line.endsWith('/')
      var name = isDir ? line.slice(0, -1) : line

      if (!isDir && name.endsWith('.gpg')) {
        name = name.slice(0, -4)
      }

      if (name === currentName && isDir) continue

      var fullPath = currentPath === "" ? name : currentPath + "/" + name

      if (isSearch) {
        var lastSlash = name.lastIndexOf('/')
        if (lastSlash !== -1) {
          var dirPath = name.substring(0, lastSlash)
          if (!seenDirs[dirPath]) {
            seenDirs[dirPath] = true
            entries.push({ name: dirPath, fullPath: dirPath, isDir: true, isPassword: false })
          }
        }
      }

      entries.push({ name: name, fullPath: fullPath, isDir: isDir, isPassword: !isDir })
    }

    entries.sort(function(a, b) {
      return a.name.localeCompare(b.name)
    })

    cachedEntries = entries
  }

  function parsePassEntry(output) {
    var lines = output.split('\n')
    var data = { password: "", fields: [], hasOtp: false }
    var passwordFound = false
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line === "") continue
      if (!passwordFound) {
        data.password = line
        passwordFound = true
        continue
      }
      if (line.indexOf("otpauth://") !== -1) data.hasOtp = true
      var colonIndex = line.indexOf(': ')
      if (colonIndex > 0) {
        var key = line.substring(0, colonIndex)
        var value = line.substring(colonIndex + 2)
        data.fields.push({ key: key, value: value })
      }
    }
    return data
  }

  function fuzzyMatch(query, target) {
    query = query.toLowerCase()
    target = target.toLowerCase()
    if (query.length === 0) return 1
    var queryParts = query.split(/\s+/).filter(function(p) { return p.length > 0 })
    if (queryParts.length === 0) return 1

    for (var p = 0; p < queryParts.length; p++) {
      var part = queryParts[p]
      var found = false
      for (var i = 0; i <= target.length - part.length; i++) {
        var match = true
        for (var j = 0; j < part.length; j++) {
          if (target[i + j] !== part[j]) { match = false; break }
        }
        if (match) { found = true; break }
      }
      if (!found) return 0
    }

    var parts = target.split('/')
    var score = 0
    for (var p = 0; p < parts.length; p++) {
      var segVal = 0
      for (var c = 0; c < parts[p].length; c++) {
        segVal = segVal * 27 + (122 - parts[p].charCodeAt(c))
      }
      score += segVal / Math.pow(1000, p)
    }
    return score
  }

  function handleCommand(searchText) {
    return searchText.startsWith(">pass")
  }

  function commands() {
    return [{
      name: ">pass",
      description: pluginApi?.tr("command.description"),
      icon: "lock",
      isTablerIcon: true,
      onActivate: function() {
        launcher.setSearchText(">pass ")
      }
    }]
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">pass")) return []

    if (root.isDetailMode && root.selectedEntry) {
      return getPasswordFieldResults()
    }

    var newQuery = searchText.slice(5).trim()
    if (newQuery !== searchQuery) {
      searchQuery = newQuery
      if (!root.isDetailMode) {
        selectedEntry = null
        searchTimer.restart()
      }
    }

    if (!loaded) {
      return [{
        name: "Loading...",
        description: pluginApi?.tr("result.loading"),
        icon: "refresh",
        isTablerIcon: true,
        onActivate: function() {}
      }]
    }

    var results = []
    if (currentPath !== "") {
      results.push({
        name: pluginApi?.tr("result.goBack"),
        description: currentPath,
        icon: "arrow-left",
        isTablerIcon: true,
        singleLine: true,
        onActivate: function() { root.goBack() }
      })
    }

    var scored = []
    for (var i = 0; i < cachedEntries.length; i++) {
      var entry = cachedEntries[i]
      var score = fuzzyMatch(searchQuery, entry.name)
      if (score > 0) {
        scored.push({ entry: entry, score: score })
      }
    }

    scored.sort(function(a, b) {
      var scoreDiff = b.score - a.score
      if (scoreDiff !== 0) return scoreDiff
      return a.entry.name.localeCompare(b.entry.name)
    })

    for (var j = 0; j < Math.min(scored.length, 50); j++) {
      var s = scored[j]
      ;(function(e) {
        results.push({
          name: e.name,
          description: e.isDir
            ? (pluginApi?.tr("result.folder"))
            : (pluginApi?.tr("result.password")),
          icon: e.isDir ? "folder" : "key",
          isTablerIcon: true,
          singleLine: true,
          onActivate: function() {
            if (e.isDir) {
              root.navigateToPath(e.fullPath)
            } else {
              root.showPasswordOptions(e.fullPath)
            }
          }
        })
      })(s.entry)
    }

    return results
  }

  function getPasswordFieldResults() {
    var results = []
    var data = root.selectedEntry.data
    var path = root.selectedEntry.path

    results.push({
      name: pluginApi?.tr("result.goBack"),
      description: path,
      icon: "arrow-left",
      isTablerIcon: true,
      singleLine: true,
      onActivate: function() { root.resetDetailMode(); if (launcher) launcher.updateResults() }
    })

    results.push({
      name: pluginApi?.tr("action.copyPassword"),
      description: pluginApi?.tr("action.copyPasswordDesc"),
      icon: "copy",
      isTablerIcon: true,
      singleLine: true,
      onActivate: function() { root.copyField(path, null) }
    })

    results.push({
      name: pluginApi?.tr("action.typePassword"),
      description: pluginApi?.tr("action.typePasswordDesc"),
      icon: "typography",
      isTablerIcon: true,
      singleLine: true,
      onActivate: function() { root.typeField(path, null) }
    })

    if (data.hasOtp) {
      results.push({
        name: pluginApi?.tr("action.copyOtp"),
        description: pluginApi?.tr("action.otpDesc"),
        icon: "copy",
        isTablerIcon: true,
        singleLine: true,
        onActivate: function() { root.copyOtp(path) }
      })

      results.push({
        name: pluginApi?.tr("action.typeOtp"),
        description: pluginApi?.tr("action.otpDesc"),
        icon: "typography",
        isTablerIcon: true,
        singleLine: true,
        onActivate: function() { root.typeOtp(path) }
      })
    }

    for (var i = 0; i < data.fields.length; i++) {
      ;(function(f) {
        results.push({
          name: pluginApi?.tr("action.copyField", { key: f.key }),
          description: f.value,
          icon: "copy",
          isTablerIcon: true,
          singleLine: true,
          onActivate: function() { root.copyField(path, f) }
        })
        results.push({
          name: pluginApi?.tr("action.typeField", { key: f.key }),
          description: f.value,
          icon: "typography",
          isTablerIcon: true,
          singleLine: true,
          onActivate: function() { root.typeField(path, f) }
        })
      })(data.fields[i])
    }

    return results
  }

  function showPasswordOptions(path) {
    root.selectedEntry = { path: path, data: null }
    pinentryActive = false
    restoringFromPinentry = false
    var escapedPath = shellEscape(path)
    showProc.environment = { "PASSWORD_STORE_DIR": passwordStoreDir }
    showProc.exec(["pass", "show", escapedPath])
  }

  function copyField(path, field) {
    root.selectedAction = "copy"
    if (field === null) {
      var escapedPath = shellEscape(path)
      root.resetDetailMode()
      launcher.close()
      actionProc.exec({
        command: ["pass", "-c", escapedPath],
        environment: getPassEnvironment(),
      })
    } else {
      var value = field.value
      var escapedValue = shellEscape(value)
      root.resetDetailMode()
      launcher.close()
      actionProc.exec(["sh", "-c", "printf '%s' '" + escapedValue + "' | wl-copy"])
    }
  }

  function typeField(path, field) {
    var value = field ? field.value : (root.selectedEntry ? root.selectedEntry.data.password : "")
    root.selectedAction = "type"
    var typeDelay = getSetting("typeDelay", 500)
    var wtypeDelay = getSetting("wtypeDelay", 12)
    var escapedValue = shellEscape(value)
    root.resetDetailMode()
    launcher.close()
    actionProc.exec(["sh", "-c", "sleep " + (typeDelay / 1000) + " && printf '%s' '" + escapedValue + "' | wtype -d " + wtypeDelay + " -"])
  }

  function doOtp(path, actionType) {
    root.selectedAction = actionType
    var escapedPath = shellEscape(path)
    if (actionType === "copy") {
      otpProc.exec({
        command: ["pass", "otp", "-c", escapedPath],
        environment: getPassEnvironment(),
      })
    } else {
      otpProc.environment = { "PASSWORD_STORE_DIR": passwordStoreDir }
      otpProc.exec(["pass", "otp", escapedPath])
    }
  }

  function copyOtp(path) {
    doOtp(path, "copy")
  }

  function typeOtp(path) {
    doOtp(path, "type")
  }

  function goBack() {
    if (entryStack.length === 0) return
    var prev = entryStack.pop()
    currentPath = prev.path
    searchQuery = prev.query
    if (launcher) {
      launcher.setSearchText(searchQuery !== "" ? ">pass " + searchQuery : ">pass ")
    }
    searchTimer.restart()
  }

  function navigateToPath(path) {
    entryStack.push({ path: currentPath, query: searchQuery })
    currentPath = path
    searchQuery = ""
    isDetailMode = false
    selectedEntry = null
    if (launcher) launcher.setSearchText(">pass ")
    searchTimer.restart()
  }

  function init() {
    searchTimer.restart()
  }

  function onOpened() {
    if (restoringFromPinentry) {
      restoringFromPinentry = false
      return
    }
    currentPath = ""
    entryStack = []
    searchQuery = ""
    cachedEntries = []
    loaded = false
    isDetailMode = false
    selectedEntry = null
    pinentryActive = false
    searchTimer.stop()
    performSearch()
  }

  function resetDetailMode() {
    isDetailMode = false
    selectedEntry = null
  }
}
