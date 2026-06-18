import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  readonly property string apiBaseUrl: "https://habitica.com/api/v3"
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string userId: cfg.habiticaUserId ?? defaults.habiticaUserId ?? ""
  readonly property string apiToken: cfg.habiticaApiToken ?? defaults.habiticaApiToken ?? ""
  readonly property bool isConfigured: userId.trim() !== "" && apiToken.trim() !== ""
  readonly property int refreshInterval: Math.max(60, cfg.refreshInterval ?? defaults.refreshInterval ?? 300)
  readonly property int maxDailies: cfg.maxDailies ?? defaults.maxDailies ?? 8
  readonly property int maxTodos: cfg.maxTodos ?? defaults.maxTodos ?? 8
  readonly property int maxHabits: cfg.maxHabits ?? defaults.maxHabits ?? 8
  readonly property bool showHabits: cfg.showHabits ?? defaults.showHabits ?? false
  readonly property bool showChecklistItems: cfg.showChecklistItems ?? defaults.showChecklistItems ?? false
  readonly property bool enableTagFilter: cfg.enableTagFilter ?? defaults.enableTagFilter ?? false
  readonly property string selectedTagId: cfg.selectedTagId ?? defaults.selectedTagId ?? ""

  property var user: ({})
  property var stats: ({})
  property var dailies: []
  property var todos: []
  property var habits: []
  property var tags: []
  property bool isLoading: false
  property bool isScoring: false
  property bool hasError: false
  property string errorMessage: ""
  property int lastFetchTimestamp: 0
  property string _currentRequest: ""
  property var _currentCommand: ["true"]
  property string _nextKind: ""
  property string _nextMethod: "GET"
  property string _nextPath: ""
  property var _nextBody: null
  property string _scoringTaskId: ""

  readonly property var visibleDailies: limitTasks(filterTasks(dailies, "daily"), maxDailies)
  readonly property var visibleTodos: limitTasks(filterTasks(todos, "todo"), maxTodos)
  readonly property var visibleHabits: showHabits ? limitTasks(filterTasks(habits, "habit"), maxHabits) : []
  readonly property int dueDailiesCount: filterTasks(dailies, "daily").length
  readonly property int dueTodosCount: filterTasks(todos, "todo").length
  readonly property int pendingCount: dueDailiesCount + dueTodosCount
  readonly property string userFieldsBase: "stats,profile,preferences,notifications"
  readonly property string userFieldsWithAvatar: "stats,profile,preferences,items,notifications"
  readonly property int avatarRefreshInterval: 3600
  property int avatarLastFetchTimestamp: 0


  function nowSeconds() {
    return Math.floor(Date.now() / 1000)
  }

  function isDueDaily(task) {
    if (!task || task.type !== "daily" || task.completed) return false
    if (!task.nextDue || task.nextDue.length === 0) return true

    var today = new Date()
    today.setHours(0, 0, 0, 0)
    for (var i = 0; i < task.nextDue.length; i++) {
      var due = new Date(task.nextDue[i])
      due.setHours(0, 0, 0, 0)
      if (due <= today) return true
    }
    return false
  }

  function filterTasks(list, type) {
    if (!list || list.length === 0) return []

    var tagId = enableTagFilter ? selectedTagId : ""
    return list.filter(function(task) {
      if (!task) return false
      if (tagId && (!task.tags || task.tags.indexOf(tagId) === -1)) return false
      if (type === "daily") return isDueDaily(task)
      if (type === "todo") return task.type === "todo" && !task.completed
      if (type === "habit") return task.type === "habit"
      return true
    })
  }

  function limitTasks(list, limit) {
    if (!list) return []
    return list.slice(0, Math.max(1, limit))
  }

  function displayName() {
    return user?.profile?.name || user?.auth?.local?.username || "Habitica"
  }

  function levelText() {
    var lvl = stats?.lvl || 0
    return lvl > 0 ? "Level " + lvl : "Level --"
  }

  function hpText() {
    var hp = Math.max(0, Math.round(stats?.hp || 0))
    return hp + " HP"
  }

  function goldText() {
    var gp = Math.floor(stats?.gp || 0)
    return gp + " gold"
  }

  function xpText() {
    var exp = Math.floor(stats?.exp || 0)
    var next = Math.floor(stats?.toNextLevel || 0)
    return next > 0 ? exp + " / " + next + " XP" : exp + " XP"
  }

  function taskSummary(task) {
    if (!task) return ""
    var parts = []
    if (task.priority) parts.push("difficulty " + task.priority)
    if (task.streak) parts.push("streak " + task.streak)
    if (task.value !== undefined) parts.push("value " + Math.round(task.value * 10) / 10)
    return parts.join(" - ")
  }

  function sanitizeResponse(text) {
    if (!text || text.trim() === "") return ({ success: false, message: "Empty response" })
    try {
      return JSON.parse(text)
    } catch (e) {
      return ({ success: false, message: "Invalid JSON response" })
    }
  }

  function authHeaders() {
    var clientId = userId.trim() || "unknown-user"
    return [
      "-H", "x-api-user: " + userId.trim(),
      "-H", "x-api-key: " + apiToken.trim(),
      "-H", "x-client: " + clientId + "-noctalia-habitica",
      "-H", "Accept: application/json"
    ]
  }

  function requestCommand(method, path, body) {
    var args = [
      "curl", "-sS", "--max-time", "30",
      "-X", method
    ].concat(authHeaders())

    if (body !== undefined && body !== null) {
      args = args.concat(["-H", "Content-Type: application/json", "--data", JSON.stringify(body)])
    }

    args.push(apiBaseUrl + path)
    return args
  }

  function shouldFetchAvatarData() {
    return !user?.items || avatarLastFetchTimestamp <= 0 || nowSeconds() - avatarLastFetchTimestamp > avatarRefreshInterval
  }

  function userRequestPath() {
    var fields = shouldFetchAvatarData() ? userFieldsWithAvatar : userFieldsBase
    return "/user?userFields=" + fields
  }

  function runRequest(kind, method, path, body) {
    if (!isConfigured) {
      root.isLoading = false
      root.hasError = true
      root.errorMessage = pluginApi?.tr("error.configure")
      return
    }

    if (apiProcess.running) return
    _currentRequest = kind
    _currentCommand = requestCommand(method, path, body)
    apiProcess.running = true
  }

  function scheduleRequest(kind, method, path, body) {
    _nextKind = kind
    _nextMethod = method
    _nextPath = path
    _nextBody = body === undefined ? null : body
    nextRequestTimer.restart()
  }

  function fetchAll(force) {
    if (!isConfigured) {
      root.hasError = false
      root.errorMessage = ""
      return
    }

    if (!force && lastFetchTimestamp > 0 && nowSeconds() - lastFetchTimestamp < refreshInterval) {
      Logger.d("Habitica", "Skipping refresh; cache is fresh")
      return
    }

    if (apiProcess.running || isLoading || isScoring) return

    root.isLoading = true
    root.hasError = false
    root.errorMessage = ""
    runRequest("user", "GET", userRequestPath())
  }

  function refresh() {
    fetchAll(true)
  }

  function continueFetch() {
    if (_currentRequest === "user") {
      scheduleRequest("dailies", "GET", "/tasks/user?type=dailys")
    } else if (_currentRequest === "dailies") {
      scheduleRequest("todos", "GET", "/tasks/user?type=todos")
    } else if (_currentRequest === "todos" && showHabits) {
      scheduleRequest("habits", "GET", "/tasks/user?type=habits")
    } else if ((_currentRequest === "todos" || _currentRequest === "habits") && enableTagFilter) {
      scheduleRequest("tags", "GET", "/tags")
    } else {
      finishFetch()
    }
  }

  function finishFetch() {
    root.lastFetchTimestamp = nowSeconds()
    root.isLoading = false
    saveToCache()
  }

  function handleApiResponse(kind, text, exitCode) {
    if (exitCode !== 0) {
      root.isLoading = false
      root.isScoring = false
      root.hasError = true
      root.errorMessage = pluginApi?.tr("error.network")
      return
    }

    var response = sanitizeResponse(text)
    if (!response.success) {
      root.isLoading = false
      root.isScoring = false
      root.hasError = true
      root.errorMessage = response.message || response.error || pluginApi?.tr("error.request")
      return
    }

    if (kind === "user") {
      var previousUser = root.user || ({})
      var nextUser = response.data || ({})
      if (!nextUser.items && previousUser.items) nextUser.items = previousUser.items
      root.user = nextUser
      root.stats = root.user.stats || ({})
      if (response.data?.items) root.avatarLastFetchTimestamp = nowSeconds()
      continueFetch()
      return
    }

    if (kind === "dailies") {
      root.dailies = response.data || []
      continueFetch()
      return
    }

    if (kind === "todos") {
      root.todos = response.data || []
      continueFetch()
      return
    }

    if (kind === "habits") {
      root.habits = response.data || []
      continueFetch()
      return
    }

    if (kind === "tags") {
      root.tags = response.data || []
      finishFetch()
      return
    }

    if (kind === "score") {
      root.isScoring = false
      root._scoringTaskId = ""
      if (response.data) {
        root.stats = response.data
      }
      ToastService.showNotice(pluginApi?.tr("toast.taskScored"))
      root.isLoading = true
      root.hasError = false
      root.errorMessage = ""
      scheduleRequest("user", "GET", userRequestPath())
    }
  }

  function scoreTask(taskId, direction) {
    if (!taskId || isScoring || apiProcess.running) return
    root.isScoring = true
    root._scoringTaskId = taskId
    runRequest("score", "POST", "/tasks/" + encodeURIComponent(taskId) + "/score/" + direction)
  }

  function completeTask(task) {
    if (!task) return
    scoreTask(task.id || task._id, "up")
  }

  function scoreHabit(task, direction) {
    if (!task) return
    scoreTask(task.id || task._id, direction)
  }

  function scoreChecklistItem(task, item) {
    if (!task || !item || isScoring || apiProcess.running) return
    root.isScoring = true
    root._scoringTaskId = task.id || task._id
    runRequest("score", "POST", "/tasks/" + encodeURIComponent(task.id || task._id) + "/checklist/" + encodeURIComponent(item.id) + "/score")
  }

  function loadFromCache() {
    try {
      var content = cfg._habiticaCache || ""
      if (!content) return
      var cached = typeof content === "string" ? JSON.parse(content) : content
      root.user = cached.user || ({})
      root.stats = cached.stats || root.user.stats || ({})
      root.dailies = cached.dailies || []
      root.todos = cached.todos || []
      root.habits = cached.habits || []
      root.tags = cached.tags || []
      root.lastFetchTimestamp = cached.timestamp || 0
      root.avatarLastFetchTimestamp = cached.avatarTimestamp || 0
      Logger.d("Habitica", "Loaded Habitica cache")
    } catch (e) {
      Logger.w("Habitica", "Failed to load cache: " + e)
    }
  }

  function saveToCache() {
    if (!pluginApi?.pluginSettings) return
    try {
      pluginApi.pluginSettings._habiticaCache = JSON.stringify({
        user: root.user,
        stats: root.stats,
        dailies: root.dailies,
        todos: root.todos,
        habits: root.habits,
        tags: root.tags,
        timestamp: root.lastFetchTimestamp,
        avatarTimestamp: root.avatarLastFetchTimestamp
      })
      pluginApi.saveSettings()
    } catch (e) {
      Logger.w("Habitica", "Failed to save cache: " + e)
    }
  }


  Process {
    id: apiProcess
    command: root._currentCommand
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      var stdout = String(apiProcess.stdout.text || "")
      var stderr = String(apiProcess.stderr.text || "").trim()
      if (stderr.length > 0) Logger.d("Habitica", stderr)
      root.handleApiResponse(root._currentRequest, stdout, exitCode)
    }
  }

  Timer {
    id: nextRequestTimer
    interval: 1
    repeat: false
    onTriggered: {
      if (apiProcess.running) {
        nextRequestTimer.restart()
        return
      }
      root.runRequest(root._nextKind, root._nextMethod, root._nextPath, root._nextBody)
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshInterval * 1000
    repeat: true
    running: root.isConfigured
    onTriggered: root.fetchAll(false)
  }

  onIsConfiguredChanged: {
    if (isConfigured) fetchAll(false)
  }

  Component.onCompleted: {
    loadFromCache()
    fetchAll(false)
  }

  IpcHandler {
    target: "plugin:habitica"

    function refresh() {
      root.refresh()
    }

    function toggle() {
      if (!root.pluginApi) return
      root.pluginApi.withCurrentScreen(screen => {
        root.pluginApi.togglePanel(screen)
      })
    }
  }
}
