pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var pluginApi: null
  property string host: ""
  property int port: 22
  property string user: ""
  property string password: ""
  property string status: "idle"
  property string statusText: ""
  property string lastError: ""
  property string terminalBuffer: ""

  readonly property bool connecting: status === "connecting"
  readonly property bool connected: status === "connected"
  readonly property bool sessionActive: connecting || connected
  readonly property string targetLabel: user && host ? user + "@" + host : "Hermes"

  property var _pendingConnect: null
  property var _pendingResize: null
  property bool _autoConnectAttempted: false

  signal terminalOutput(string text)
  signal terminalReset()

  function tr(key, args) {
    return root.pluginApi ? root.pluginApi.tr(key, args || ({})) : key;
  }

  function resetTerminal() {
    root.terminalBuffer = "";
    root.terminalReset();
  }

  function setPluginApi(api) {
    if (!api) return;
    root.pluginApi = api;
    root.host = api.pluginSettings.host || "";
    root.port = api.pluginSettings.port || 22;
    root.user = api.pluginSettings.user || "";
    if (root.status === "idle" && root.statusText.length === 0)
      root.statusText = tr("status.disconnected");
    root.maybeAutoConnect();
  }

  function setting(key, fallback) {
    if (!root.pluginApi || !root.pluginApi.pluginSettings) return fallback;
    var value = root.pluginApi.pluginSettings[key];
    return value === undefined ? fallback : value;
  }

  function helperPath() {
    var url = String(Qt.resolvedUrl("helpers/hermes_ssh_bridge.py"));
    return decodeURIComponent(url.replace(/^file:\/\//, ""));
  }

  function maybeAutoConnect() {
    if (root._autoConnectAttempted || !setting("autoConnectOnStartup", false))
      return;

    root._autoConnectAttempted = true;

    if (!root.host || !root.user || root.sessionActive)
      return;

    Qt.callLater(function() {
      if (!root.sessionActive)
        root.connect(root.host, root.port, root.user, "", setting("terminalRows", 32), setting("terminalCols", 180));
    });
  }

  function connect(targetHost, targetPort, targetUser, targetPassword, rows, cols) {
    root.host = String(targetHost || "").trim();
    root.port = Math.max(1, Math.min(65535, Number(targetPort || 22)));
    root.user = String(targetUser || "").trim();
    root.password = String(targetPassword || "");
    root.lastError = "";

    if (!root.host || !root.user) {
      root.status = "idle";
      root.statusText = tr("status.missingTarget");
      root.lastError = root.statusText;
      return;
    }

    if (root.pluginApi && setting("rememberLastTarget", true)) {
      root.pluginApi.pluginSettings.host = root.host;
      root.pluginApi.pluginSettings.port = root.port;
      root.pluginApi.pluginSettings.user = root.user;
      root.pluginApi.saveSettings();
    }

    root.resetTerminal();
    root.status = "connecting";
    root.statusText = tr("status.connecting", { "target": root.targetLabel });

    root._pendingConnect = JSON.stringify({
      "type": "connect",
      "host": root.host,
      "port": root.port,
      "user": root.user,
      "password": root.password,
      "rows": Math.max(1, Number(rows || setting("terminalRows", 32))),
      "cols": Math.max(1, Number(cols || setting("terminalCols", 180)))
    }) + "\n";

    bridge.command = ["python3", root.helperPath()];
    if (bridge.running) {
      bridge.running = false;
      return;
    }
    bridge.running = true;
  }

  function send(text) {
    if (!bridge.running || !root.sessionActive) return;
    bridge.write(JSON.stringify({"type": "input", "text": String(text || "")}) + "\n");
  }

  function resize(rows, cols) {
    var payload = JSON.stringify({
      "type": "resize",
      "rows": Math.max(1, Number(rows || setting("terminalRows", 32))),
      "cols": Math.max(1, Number(cols || setting("terminalCols", 180)))
    }) + "\n";

    if (bridge.running && root.sessionActive) {
      bridge.write(payload);
    } else {
      root._pendingResize = payload;
    }
  }

  function disconnect() {
    root._pendingConnect = null;
    root._pendingResize = null;
    if (bridge.running) {
      bridge.write(JSON.stringify({"type": "disconnect"}) + "\n");
    }
    root.status = "idle";
    root.statusText = tr("status.disconnected");
    root.lastError = "";
    root.password = "";
    root.resetTerminal();
  }

  function handleMessage(line) {
    var trimmed = String(line || "").trim();
    if (!trimmed) return;

    var msg = null;
    try {
      msg = JSON.parse(trimmed);
    } catch (e) {
      return;
    }

    if (msg.type === "output") {
      var text = String(msg.text || "");
      root.terminalBuffer += text;
      root.terminalOutput(text);
      return;
    }

    if (msg.type === "status") {
      if (msg.status === "idle" && root.status === "connecting")
        return;
      root.status = String(msg.status || root.status);
      root.statusText = String(msg.message || root.statusText);
      return;
    }

    if (msg.type === "error") {
      root.lastError = String(msg.message || tr("status.error"));
      root.statusText = root.lastError;
      return;
    }

    if (msg.type === "exit") {
      root.status = "idle";
      root.statusText = tr("status.disconnected");
      root.password = "";
      root.resetTerminal();
    }
  }

  function flushPending() {
    if (root._pendingConnect) {
      bridge.write(root._pendingConnect);
      root._pendingConnect = null;
    }
    if (root._pendingResize) {
      bridge.write(root._pendingResize);
      root._pendingResize = null;
    }
  }

  Process {
    id: bridge
    running: false
    stdinEnabled: true

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.handleMessage(data); }
    }

    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        var text = String(data || "").trim();
        if (text.length > 0) {
          root.lastError = text;
          root.statusText = text;
        }
      }
    }

    onStarted: root.flushPending()

    onExited: function(exitCode, exitStatus) {
      if (root._pendingConnect) {
        bridge.running = true;
        return;
      }
      if (root.sessionActive) {
        root.status = "idle";
        root.statusText = tr("status.bridgeExited");
        root.password = "";
        root.resetTerminal();
      }
    }
  }
}
