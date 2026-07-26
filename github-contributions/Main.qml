import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var pluginApi: null

  // Settings access
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Shared state — consumed by DesktopWidget
  property var days: []
  property int totalContributions: 0
  property int currentStreak: 0
  property bool loading: false
  property bool hasData: false
  property string errorMessage: ""

  readonly property string username: (cfg.username ?? defaults.username ?? "").trim()
  readonly property string token: (cfg.token ?? defaults.token ?? "").trim()

  Component.onCompleted: {
    Logger.i("GithubContributions", "Plugin loaded, starting initial fetch...")
    refresh()
  }

  // Refresh timer
  Timer {
    interval: (root.cfg.refreshInterval ?? root.defaults.refreshInterval ?? 60) * 60000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // IPC handler
  IpcHandler {
    target: "plugin:github-contributions"

    function refresh() {
      Logger.d("GithubContributions", "Refreshing through IPC...")
      root.refresh()
    }
  }

  // Tokenless fetch — public contributions page
  Process {
    id: htmlProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        Logger.w("GithubContributions", "curl exited with code " + exitCode)
        root.errorMessage = root.hasData ? "" : pluginApi?.tr("errors.fetchFailed")
        root.loading = false
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.handleHtmlResponse(this.text)
      }
    }
  }

  // Token fetch — GraphQL API
  Process {
    id: graphqlProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        Logger.w("GithubContributions", "GraphQL curl exited with code " + exitCode)
        root.errorMessage = root.hasData ? "" : pluginApi?.tr("errors.fetchFailed")
        root.loading = false
      }
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.handleGraphqlResponse(this.text)
      }
    }
  }

  function refresh() {
    if (loading) return
    if (!username) {
      root.errorMessage = pluginApi?.tr("errors.noUsername")
      return
    }
    root.errorMessage = ""
    root.loading = true

    if (token) {
      var query = "query($login: String!) { user(login: $login) { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount contributionLevel } } } } } }"
      var payload = JSON.stringify({ "query": query, "variables": { "login": username } })
      graphqlProcess.command = ["curl", "-s", "--max-time", "30", "-X", "POST", "https://api.github.com/graphql", "-H", "Authorization: Bearer " + token, "-H", "Content-Type: application/json", "-d", payload]
      graphqlProcess.running = true
    } else {
      htmlProcess.command = ["curl", "-s", "--max-time", "30", "https://github.com/users/" + username + "/contributions"]
      htmlProcess.running = true
    }
  }

  function handleHtmlResponse(html) {
    if (!html || html.indexOf("data-date") === -1) {
      Logger.w("GithubContributions", "Contributions page empty or user not found")
      root.errorMessage = root.hasData ? "" : pluginApi?.tr("errors.userNotFound")
      root.loading = false
      return
    }

    // Per-day counts live in <tool-tip> elements keyed by the cell id
    var counts = {}
    var tipRe = /<tool-tip[^>]*for="([^"]+)"[^>]*>([^<]*)<\/tool-tip>/g
    var m
    while ((m = tipRe.exec(html)) !== null) {
      var countMatch = m[2].match(/^([\d,]+)\s/)
      counts[m[1]] = countMatch ? parseInt(countMatch[1].replace(/,/g, "")) : 0
    }

    var parsed = []
    var cellRe = /<td[^>]*?data-date="(\d{4}-\d{2}-\d{2})"[^>]*?id="([^"]+)"[^>]*?data-level="(\d)"/g
    while ((m = cellRe.exec(html)) !== null) {
      parsed.push({ "date": m[1], "count": counts[m[2]] ?? -1, "level": parseInt(m[3]) })
    }

    if (parsed.length === 0) {
      Logger.w("GithubContributions", "No contribution cells found in page")
      root.errorMessage = root.hasData ? "" : pluginApi?.tr("errors.fetchFailed")
      root.loading = false
      return
    }

    // Cells appear in row-major (weekday) order, so restore chronological order
    parsed.sort((a, b) => a.date < b.date ? -1 : 1)

    var totalMatch = html.match(/([\d,]+)\s+contributions?\s+in the last year/)
    root.totalContributions = totalMatch ? parseInt(totalMatch[1].replace(/,/g, "")) : sumCounts(parsed)
    finishUpdate(parsed)
  }

  function handleGraphqlResponse(text) {
    var levelMap = { "NONE": 0, "FIRST_QUARTILE": 1, "SECOND_QUARTILE": 2, "THIRD_QUARTILE": 3, "FOURTH_QUARTILE": 4 }
    try {
      var data = JSON.parse(text)
      if (data.errors) {
        Logger.w("GithubContributions", "GraphQL error: " + data.errors[0].message)
        root.errorMessage = root.hasData ? "" : pluginApi?.tr("errors.apiError")
        root.loading = false
        return
      }
      var calendar = data.data.user.contributionsCollection.contributionCalendar
      var parsed = []
      for (var i = 0; i < calendar.weeks.length; i++) {
        var week = calendar.weeks[i].contributionDays
        for (var j = 0; j < week.length; j++) {
          parsed.push({ "date": week[j].date, "count": week[j].contributionCount, "level": levelMap[week[j].contributionLevel] ?? 0 })
        }
      }
      root.totalContributions = calendar.totalContributions
      finishUpdate(parsed)
    } catch (e) {
      Logger.e("GithubContributions", "Failed to parse GraphQL response: " + e.message)
      root.errorMessage = root.hasData ? "" : pluginApi?.tr("errors.apiError")
      root.loading = false
    }
  }

  function finishUpdate(parsed) {
    root.days = parsed
    root.currentStreak = computeStreak(parsed)
    root.hasData = true
    root.errorMessage = ""
    root.loading = false
    Logger.i("GithubContributions", "Updated: " + parsed.length + " days, " + root.totalContributions + " contributions, streak " + root.currentStreak)
  }

  function sumCounts(parsed) {
    var total = 0
    for (var i = 0; i < parsed.length; i++)
      total += Math.max(0, parsed[i].count)
    return total
  }

  function computeStreak(parsed) {
    var streak = 0
    for (var i = parsed.length - 1; i >= 0; i--) {
      var contributed = parsed[i].level > 0 || parsed[i].count > 0
      // An empty today doesn't break the streak yet
      if (i === parsed.length - 1 && !contributed) continue
      if (!contributed) break
      streak++
    }
    return streak
  }
}
