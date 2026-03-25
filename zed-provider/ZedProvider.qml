import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var pluginApi: null
  property var launcher: null
  property string name: "Zed Provider"
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property var openCounts: cfg.openCounts || defaults.openCounts || {}
  property string supportedLayouts: "both"
  property real preferredGridColumns: 6
  property real preferredGridCellRatio: 1.0
  property var projects: []
  property var tempProjects: []
  property var folders: []
  property var tempFolders: []
  property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "")
  property bool zedInstalled: false
  property string zedBin: "zed"

  Process {
    id: whichZed
    command: ["sh", "-c", "command -v zeditor >/dev/null 2>&1 && echo zeditor || command -v zed >/dev/null 2>&1 && echo zed || echo notfound"]
    stdout: SplitParser {
      onRead: data => {
        var bin = data.trim()
        if (bin !== "notfound" && bin !== "") {
          root.zedBin = bin
          root.zedInstalled = true
        }
      }
    }
  }

  Process {
    id: dbQuery
    command: [
      "sqlite3",
      root.homeDir + "/.local/share/zed/db/0-stable/db.sqlite",
      "SELECT paths, timestamp FROM workspaces WHERE paths != '' AND paths IS NOT NULL ORDER BY timestamp DESC;"
    ]
    stdout: SplitParser {
      onRead: data => {
        if (data.trim() !== "") {
          var parts = data.trim().split("|")
          var path = parts[0]
          var timestamp = parts[1]
          var name = path.trim().split("/").pop()
          root.tempProjects.push({
            "path": path,
            "name": name,
            "timestamp": timestamp
          })
        }
      }
    }
    onExited: {
      root.projects = root.tempProjects
      root.tempProjects = []
      if (root.launcher) root.launcher.updateResults()
    }
  }

  Process {
    id: lsQuery
    property string currentPath: ""
    command: ["sh", "-c", "ls -Ap " + lsQuery.currentPath + " 2>/dev/null | grep '/$'"]
    stdout: SplitParser {
      onRead: data => {
        if (data.trim() !== "") {
          root.tempFolders.push(data.trim().replace("/", ""))
        }
      }
    }
    onExited: {
      root.folders = root.tempFolders
      root.tempFolders = []
      if (root.launcher) root.launcher.updateResults()
    }
  }

  function init() {
    dbQuery.running = true
    whichZed.running = true
  }

  function onOpened() {
    root.tempProjects = []
    dbQuery.running = true
  }

  function handleCommand(searchText) {
    return searchText.startsWith(">zed")
  }

  function commands() {
    return [{
      "name": ">zed",
      "description": pluginApi?.tr("launcher.command_description"),
      "icon": "code",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        launcher.setSearchText(">zed ")
      }
    }]
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">zed")) {
      return []
    }

    if (!root.zedInstalled) {
      return [{
        "name": pluginApi?.tr("launcher.not_installed"),
        "description": pluginApi?.tr("launcher.not_installed_desc"),
        "icon": "alert-circle",
        "isTablerIcon": true,
        "onActivate": function() { launcher.close() }
      }]
    }

    var query = searchText.slice(4).trim()

    // folder browsing mode
    if (query.startsWith("/") || query.startsWith("~")) {
      var resolvedQuery = query.replace(/^~/, root.homeDir)
      var hasTrailingSlash = resolvedQuery.endsWith("/")

      if (hasTrailingSlash) {
        if (lsQuery.currentPath !== resolvedQuery) {
          root.folders = []
          root.tempFolders = []
          lsQuery.currentPath = resolvedQuery
          lsQuery.running = true
        }

        var results = root.folders.map(function(f) {
          var fullPath = resolvedQuery + f
          return {
            "name": f,
            "description": fullPath,
            "icon": "folder",
            "isTablerIcon": true,
            "isImage": false,
            "onActivate": function() {
              launcher.setSearchText(">zed " + fullPath + "/")
            }
          }
        })

        results.unshift({
          "name": pluginApi?.tr("launcher.open_folder", { path: resolvedQuery.split("/").pop() }),
          "description": resolvedQuery,
          "icon": "folder-plus",
          "isTablerIcon": true,
          "isImage": false,
          "onActivate": function() {
            Quickshell.execDetached(["bash", "-l", "-c", `${root.zedBin} '${resolvedQuery}'`])
            launcher.close()
          }
        })

        return results
      }

      var lastSlashIndex = resolvedQuery.lastIndexOf("/")
      var searchBase = resolvedQuery.substring(0, lastSlashIndex + 1)
      var searchTerm = resolvedQuery.substring(lastSlashIndex + 1)

      if (lsQuery.currentPath !== searchBase) {
        root.folders = []
        root.tempFolders = []
        lsQuery.currentPath = searchBase
        lsQuery.running = true
      }

      var filteredFolders = root.folders.filter(function(f) {
        return f.toLowerCase().indexOf(searchTerm.toLowerCase()) !== -1
      })

      var searchResults = filteredFolders.map(function(f) {
        var fullPath = searchBase + f
        return {
          "name": f,
          "description": fullPath,
          "icon": "folder",
          "isTablerIcon": true,
          "isImage": false,
          "onActivate": function() {
            launcher.setSearchText(">zed " + fullPath + "/")
          }
        }
      })

      if (searchTerm.length > 0) {
        searchResults.unshift({
          "name": pluginApi?.tr("launcher.search_folder", { path: resolvedQuery }),
          "description": searchBase,
          "icon": "search",
          "isTablerIcon": true,
          "isImage": false,
          "onActivate": function() {
            launcher.setSearchText(">zed " + resolvedQuery + "/")
          }
        })
      }

      return searchResults
    }

    // recent projects mode
    var filtered = query === "" ? root.projects : root.projects.filter(function(p) {
      return p.name.toLowerCase().indexOf(query.toLowerCase()) !== -1
          || p.path.toLowerCase().indexOf(query.toLowerCase()) !== -1
    })

    if (filtered.length === 0) return []

    var recent = filtered[0]
    var rest = filtered.slice(1).sort(function(a, b) {
      return (root.openCounts[b.path] || 0) - (root.openCounts[a.path] || 0)
    })

    var sorted = [recent].concat(rest)

    return sorted.map(function(p) {
      return {
        "name": p.name,
        "description": p.path,
        "icon": pluginApi ? pluginApi.pluginDir + "/zed-logo.png" : "",
        "isTablerIcon": false,
        "isImage": true,
        "singleLine": true,
        "provider": root,
        "onActivate": function() {
          var counts = root.openCounts
          counts[p.path] = (counts[p.path] || 0) + 1
          root.openCounts = counts
          if (pluginApi) {
            pluginApi.pluginSettings.openCounts = counts
            pluginApi.saveSettings()
          }
          Quickshell.execDetached(["bash", "-l", "-c", `${root.zedBin} '${p.path}'`])
          launcher.close()
        }
      }
    })
  }

  function getImageUrl(modelData) {
    if (modelData.isImage) {
      return modelData.icon
    }
    return null
  }
}
