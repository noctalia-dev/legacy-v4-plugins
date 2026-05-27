// Main.qml - niri-screensaver Noctalia plugin runtime
//
// Responsibilities:
//   1. Persist plugin settings to $XDG_CONFIG_HOME/niri-screensaver/config (or
//      ~/.config/niri-screensaver/config) in shell KEY="value" format so the
//      script-side driver picks them up.
//   2. Auto-register / deregister a screensaver entry in Noctalia's
//      Settings.data.idle.customCommands array based on plugin enable state.
//   3. Auto-write Noctalia's screenLock / screenUnlock hook slots (never
//      clobbering hooks the user authored manually).
//   4. Expose IPC: plugin:niri-screensaver { launch | kill | toggle }
//   5. Detect whether the bash CLI (niri-screensaver-launch) is on PATH so
//      Settings.qml can surface a banner if it's missing.
//
// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var pluginApi: null

  // Identifier used to find / remove our entry in Noctalia's idle.customCommands
  readonly property string entryName: "Niri Screensaver"

  // Centralized defaults (also mirrored in manifest.json defaultSettings)
  readonly property string defaultLauncherCommand: "niri-screensaver-launch launch"
  readonly property string defaultKillCommand: "niri-screensaver-launch kill"
  readonly property string cliBinary: "niri-screensaver-launch"

  // ----- File paths (XDG-aware) -----
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string configDir: configHome + "/niri-screensaver"
  readonly property string configFile: configDir + "/config"

  // ----- CLI presence (true|false|null=unknown), surfaced to Settings.qml -----
  property var cliAvailable: null

  // ----- Lifecycle -----
  Component.onCompleted: {
    if (pluginApi) {
      _syncAll()
      _detectCli()
    }
  }
  onPluginApiChanged: {
    if (pluginApi) {
      _syncAll()
      _detectCli()
    }
  }

  // Debounce: Noctalia's panel framework can fire pluginSettingsChanged
  // ~5× for a single Apply click (once per property + once for the explicit
  // save). Without this, every Apply spawns 5 concurrent writeConfigProcess
  // invocations writing identical content. Collapsing into one ~250ms
  // window cuts disk activity 5× and avoids the (currently-safe) race.
  Timer {
    id: syncDebounce
    interval: 250
    repeat: false
    onTriggered: root._syncAll()
  }

  Connections {
    target: pluginApi
    enabled: pluginApi !== null
    function onPluginSettingsChanged() { syncDebounce.restart() }
  }

  function _syncAll() {
    _writeShellConfig()
    _syncIdleEntry()
    _syncHooks()
  }

  // ----- Resolve a "command-or-default" setting into an exec array -----
  // For trusted defaults we use direct exec (no shell). For user overrides we
  // fall back to `sh -c` because the user may want shell semantics (env vars,
  // pipes, etc.) — they own the value.
  function _resolveCommand(value, fallbackString, directArgv) {
    if (!value || value === fallbackString) return directArgv
    return ["sh", "-c", String(value)]
  }
  function _launcherArgv() {
    return _resolveCommand(
      root.pluginApi?.pluginSettings?.launcherCommand,
      defaultLauncherCommand,
      ["niri-screensaver-launch", "launch"]
    )
  }
  function _killArgv() {
    return _resolveCommand(
      root.pluginApi?.pluginSettings?.killCommand,
      defaultKillCommand,
      ["niri-screensaver-launch", "kill"]
    )
  }

  // ----- Shell config writer -----
  function _renderShellConfig() {
    var s = pluginApi.pluginSettings
    var bool = function (b) { return b ? "true" : "false" }
    return [
      "# niri-screensaver config (managed by Noctalia plugin)",
      "BATTERY_MIN_PERCENT=\"" + _shEscape(s.batteryMinPercent || 0) + "\"",
      "FRAME_RATE=\"" + _shEscape(s.frameRate || 60) + "\"",
      "INCLUDE_EFFECTS=\"" + _shEscape(s.includeEffects) + "\"",
      "EXCLUDE_EFFECTS=\"" + _shEscape(s.excludeEffects) + "\"",
      "FADE_IN_EFFECT=\"" + _shEscape(s.fadeInEffect) + "\"",
      "FADE_OUT_EFFECT=\"" + _shEscape(s.fadeOutEffect) + "\"",
      "SHOW_CLOCK=\"" + bool(s.showClock) + "\"",
      "CLOCK_DURATION=\"" + _shEscape(s.clockDuration || 3) + "\"",
      "CLOCK_FORMAT=\"" + _shEscape(s.clockFormat) + "\"",
      "CLOCK_FONT=\"" + _shEscape(s.clockFont) + "\"",
      "SHOW_NOW_PLAYING=\"" + bool(s.showNowPlaying) + "\"",
      "NOW_PLAYING_DURATION=\"" + _shEscape(s.nowPlayingDuration || 3) + "\"",
      "LOGO_FILE=\"" + _shEscape(s.logoPath) + "\"",
      "CURSOR_HIDE=\"" + bool(s.cursorHide) + "\"",
      "DISMISS_ON_KEY=\"" + bool(s.dismissOnKey) + "\"",
      "RANDOM_LOGO=\"" + bool(s.randomLogo) + "\"",
      "LOGO_DIR=\"" + _shEscape(s.logoDir) + "\"",
      ""
    ].join("\n")
  }

  // Escape a value for inclusion inside a double-quoted shell string.
  // Backslash, dollar, backtick, double-quote all need escaping inside "...".
  function _shEscape(s) {
    if (s === undefined || s === null) return ""
    return String(s).replace(/\\/g, "\\\\").replace(/\$/g, "\\$").replace(/`/g, "\\`").replace(/"/g, '\\"')
  }

  Process {
    id: writeConfigProcess
    onExited: function (code) {
      if (code !== 0) {
        Logger.w("NiriScreensaver", "config write exited with code", code, "for", root.configFile)
      }
    }
  }

  // Write config via positional shell args + a random heredoc marker.
  // - Paths are passed via "$1" / "$2", so a malicious HOME / XDG_CONFIG_HOME
  //   value cannot escape into the script body.
  // - The heredoc marker is randomized and collision-checked against the
  //   content, so a user-supplied config value cannot terminate the heredoc.
  function _writeShellConfig() {
    if (!pluginApi) return
    var content = _renderShellConfig()
    var eof = "__NIRI_SS_EOF_" + Math.random().toString(36).slice(2)
    while (content.indexOf(eof) !== -1) {
      eof = "__NIRI_SS_EOF_" + Math.random().toString(36).slice(2)
    }
    var script = 'mkdir -p "$1" && cat > "$2" <<\'' + eof + "'\n" + content + eof + "\n"
    writeConfigProcess.command = ["sh", "-c", script, "sh", root.configDir, root.configFile]
    writeConfigProcess.running = true
  }

  // ----- Noctalia idle wiring -----
  function _syncIdleEntry() {
    if (!pluginApi) return
    var raw = ""
    try {
      raw = Settings.data.idle.customCommands || "[]"
    } catch (e) {
      Logger.w("NiriScreensaver", "Settings.data.idle.customCommands unreachable:", e)
      return
    }

    var arr = []
    try { arr = JSON.parse(raw) } catch (e) { arr = [] }

    // Remove any existing entry of ours
    arr = arr.filter(function (e) { return e && e.name !== root.entryName })

    if (pluginApi.pluginSettings.enabled) {
      arr.push({
        name: root.entryName,
        timeout: parseInt(pluginApi.pluginSettings.idleSeconds) || 300,
        command: pluginApi.pluginSettings.launcherCommand || root.defaultLauncherCommand,
        resumeCommand: pluginApi.pluginSettings.killCommand || root.defaultKillCommand
      })
    }
    Settings.data.idle.customCommands = JSON.stringify(arr)
  }

  // ----- Noctalia Hooks wiring (screenLock / screenUnlock) -----
  //
  // Only write to a hook slot if it's currently empty OR already holds our
  // command. That way we never clobber a hook the user authored manually.
  // On disable we mirror the same rule: only clear if the value is still ours.
  // Requires Settings.data.hooks.enabled = true to actually fire — the plugin
  // does not flip that master toggle for the user.
  function _hookKillCmd() {
    return pluginApi?.pluginSettings?.killCommand || root.defaultKillCommand
  }

  function _syncHooks() {
    if (!pluginApi) return
    if (!Settings.data.hooks) return  // Older Noctalia builds may lack hooks

    var killCmd = _hookKillCmd()
    var lockNow   = Settings.data.hooks.screenLock || ""
    var unlockNow = Settings.data.hooks.screenUnlock || ""

    if (pluginApi.pluginSettings.enabled) {
      if (lockNow === "" || lockNow === killCmd) {
        Settings.data.hooks.screenLock = killCmd
      }
      if (unlockNow === "" || unlockNow === killCmd) {
        Settings.data.hooks.screenUnlock = killCmd
      }
    } else {
      if (lockNow === killCmd)   Settings.data.hooks.screenLock = ""
      if (unlockNow === killCmd) Settings.data.hooks.screenUnlock = ""
    }

    if (typeof Settings.saveImmediate === "function") {
      Settings.saveImmediate()
    }
  }

  // ----- CLI presence detection -----
  // Runs once at startup. Settings.qml reads `cliAvailable` to decide whether
  // to render the "install niri-screensaver first" banner.
  Process {
    id: cliDetectProcess
    onExited: function (code) {
      root.cliAvailable = (code === 0)
      if (!root.cliAvailable) {
        Logger.w("NiriScreensaver", root.cliBinary, "not found on PATH")
      }
    }
  }
  function _detectCli() {
    cliDetectProcess.command = ["sh", "-c", "command -v " + root.cliBinary]
    cliDetectProcess.running = true
  }

  // ----- IPC handlers -----
  IpcHandler {
    target: "plugin:niri-screensaver"

    function launch() {
      ipcLaunchProcess.command = root._launcherArgv()
      ipcLaunchProcess.running = true
    }
    function kill() {
      ipcKillProcess.command = root._killArgv()
      ipcKillProcess.running = true
    }
    function toggle() {
      if (!root.pluginApi) return
      var enabled = root.pluginApi.pluginSettings.enabled === true
      root.pluginApi.pluginSettings.enabled = !enabled
      root.pluginApi.saveSettings()
    }
  }

  Process {
    id: ipcLaunchProcess
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "launch (IPC) exited with code", code)
    }
  }
  Process {
    id: ipcKillProcess
    onExited: function (code) {
      if (code !== 0) Logger.w("NiriScreensaver", "kill (IPC) exited with code", code)
    }
  }

  // ----- Cleanup on plugin disable / unload -----
  Component.onDestruction: {
    if (pluginApi) {
      // Best-effort: remove our customCommands entry so we don't leave a dangling hook
      try {
        var arr = JSON.parse(Settings.data.idle.customCommands || "[]")
        arr = arr.filter(function (e) { return e && e.name !== root.entryName })
        Settings.data.idle.customCommands = JSON.stringify(arr)
      } catch (e) { /* ignore */ }

      // Mirror cleanup for hook slots — only clear values we wrote
      try {
        var killCmd = _hookKillCmd()
        if (Settings.data.hooks) {
          if (Settings.data.hooks.screenLock === killCmd)   Settings.data.hooks.screenLock = ""
          if (Settings.data.hooks.screenUnlock === killCmd) Settings.data.hooks.screenUnlock = ""
        }
      } catch (e) { /* ignore */ }

      if (typeof Settings.saveImmediate === "function") {
        Settings.saveImmediate()
      }
    }
  }
}
