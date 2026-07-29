import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root
  visible: false

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Mode-dependent: normal mode always uses localhost for the local bridge.
  // clientOnlyMode uses the configured remote host/port.
  // Without this, toggling clientOnlyMode OFF leaves bridgeHost pointing at the
  // remote server, causing the plugin to send the LOCAL token to the REMOTE bridge → 403.
  readonly property string bridgeHost: clientOnlyMode ? (cfg.bridgeHost ?? defaults.bridgeHost ?? "127.0.0.1") : "127.0.0.1"
  readonly property int bridgePort: clientOnlyMode ? (cfg.bridgePort ?? defaults.bridgePort ?? 19777) : (defaults.bridgePort ?? 19777)
  readonly property string stateFile: cfg.stateFile ?? defaults.stateFile ?? "~/.cache/noctalia-hermes/state.json"
  readonly property string hermesHome: cfg.hermesHome ?? defaults.hermesHome ?? "~/.hermes"
  readonly property string hermesCommand: cfg.hermesCommand ?? defaults.hermesCommand ?? "hermes"
  readonly property bool autoStartBridge: cfg.autoStartBridge ?? defaults.autoStartBridge ?? true
  readonly property bool autoStartGateway: cfg.autoStartGateway ?? defaults.autoStartGateway ?? true
  readonly property int statusPollIntervalSec: cfg.statusPollIntervalSec ?? defaults.statusPollIntervalSec ?? 30
  readonly property bool clientOnlyMode: cfg.clientOnlyMode ?? defaults.clientOnlyMode ?? false

  // Switching to client-only at runtime: stop local gateway, tear down local bridge.
  // The remote bridge (via SSH tunnel) manages the gateway on the server side.
  // Switching back: ensureBridge() starts the local bridge; tokenFileView.onLoaded
  // auto-starts the gateway when autoStartGateway is true and it is not running.
  onClientOnlyModeChanged: {
    Logger.i("hermes-agent", "clientOnlyModeChanged:", clientOnlyMode,
      "bridgeHost:", bridgeHost, "bridgePort:", bridgePort,
      "tokenManual len:", (cfg.bridgeTokenManual ?? "").length,
      "bridgeToken len:", root.bridgeToken.length,
      "bridgeTokenFromFile len:", root.bridgeTokenFromFile.length);
    if (clientOnlyMode) {
      if (bridgeProcess.running) {
        bridgeProcess.running = false;
      }
      // ponytail: removed stopGateway() here — bridgeHost has already updated to
      // remote, so stopGateway() would hit the REMOTE bridge and stop the REMOTE
      // gateway. Local gateway is orphaned but harmless; maybeStartGateway() handles
      // it when switching back to normal mode.
    }
    root.ensureBridge();
  }
  readonly property string expandedStateFile: expandHome(stateFile)
  readonly property string expandedHermesHome: expandHome(hermesHome)
  readonly property string bridgeScript: (pluginApi?.pluginDir || ".") + "/scripts/hermes_bridge.py"
  readonly property string bridgeTokenFile: expandedStateFile.replace(/\/[^/]*$/, "/bridge.token")
  // In client-only mode the token is pasted into settings (the server prints it);
  // otherwise it is read from the local bridge.token file by tokenFileView.
  // readonly: imperative assignment in tokenFileView.onLoaded would break the binding,
  // leaving bridgeToken stuck on the local token when switching to client-only mode.
  property string bridgeTokenFromFile: ""
  readonly property string bridgeToken: clientOnlyMode ? (cfg.bridgeTokenManual ?? "") : bridgeTokenFromFile
  property bool bridgeOnlinePending: false

  property var state: ({
    "bridge": { "status": "offline", "error": "" },
    "hermes": { "status": "unknown", "gateway_pid": "", "model": "", "provider": "" },
    "session": { "id": "", "stored_id": "", "title": "", "running": false, "cwd": "" },
    "messages": [],
    "events": [],
    "approval": { "pending": false, "message": "", "tool_name": "", "request": ({}) },
    "usage": { "input": 0, "output": 0, "total": 0, "cost_usd": null },
    "summary": {
      "model": { "name": "", "provider": "" },
      "models": [],
      "mcp": { "enabled": 0, "total": 0, "status": "unknown" },
      "cron": { "active": 0, "total": 0, "next_run": "", "jobs": [] },
      "activity": { "tool_events": 0, "running_tools": 0, "last_tool": "" },
      "gateway": { "status": "unknown", "platforms": ({}) }
    },
    "updated_at": 0
  })

  property bool pinnedPanelRequested: cfg.panelPinned ?? defaults.panelPinned ?? false
  property bool pinnedPanelVisible: cfg.panelPinned ?? defaults.panelPinned ?? false
  property var pinnedPanelScreen: null

  function expandHome(path) {
    if (!path) return path;
    if (path === "~") return Quickshell.env("HOME") || path;
    if (path.indexOf("~/") === 0) return (Quickshell.env("HOME") || "") + path.slice(1);
    return path;
  }

  function bridgeUrl(path) {
    return "http://" + bridgeHost + ":" + bridgePort + path;
  }

  property bool autoStartGatewayPending: false

  function maybeStartGateway() {
    if (root.clientOnlyMode) return;
    if (!root.autoStartGateway) return;
    var gw = root.state?.summary?.gateway?.status || root.state?.hermes?.gateway_status || "";
    if (gw === "offline" || gw === "stopped" || gw === "unknown" || gw === "") {
      root.startGateway();
    }
  }

  function refreshState() {
    Logger.i("hermes-agent", "refreshState fetching:", bridgeUrl("/state"), "tokenPresent:", !!root.bridgeToken, "tokenLen:", root.bridgeToken.length);
    getJson("/state", function(data) {
      if (data) {
        Logger.i("hermes-agent", "refreshState got data, hermes.status:", data.hermes?.status, "gateway:", data.summary?.gateway?.status);
        root.state = data;
        if (root.autoStartGatewayPending) {
          root.autoStartGatewayPending = false;
          root.maybeStartGateway();
        }
      }
    });
  }

  function startBridge() {
    if (root.clientOnlyMode) return; // remote bridge: never spawn a local subprocess
    if (bridgeProcess.running) return;
    bridgeProcess.command = [
      "python3",
      bridgeScript,
      "--host", bridgeHost,
      "--port", String(bridgePort),
      "--state-file", expandedStateFile,
      "--hermes-home", expandedHermesHome,
      "--hermes-command", hermesCommand
    ];
    bridgeProcess.running = true;
  }

  function onBridgeOnline() {
    Logger.i("hermes-agent", "onBridgeOnline clientOnlyMode:", root.clientOnlyMode);
    if (root.clientOnlyMode) {
      // Token is already set from settings; go straight to state + detection.
      root.bridgeOnlinePending = false;
      root.refreshState();
      root.autoConfigure();
      return;
    }
    root.bridgeOnlinePending = true;
    root.autoStartGatewayPending = true;
    tokenFileView.reload();
  }

  function ensureBridge() {
    Logger.i("hermes-agent", "ensureBridge ping:", bridgeUrl("/health"));
    getJson("/health", function(data) {
      if (data && data.bridge && data.bridge.status === "online") {
        Logger.i("hermes-agent", "ensureBridge health OK");
        root.onBridgeOnline();
      } else if (root.clientOnlyMode) {
        Logger.i("hermes-agent", "ensureBridge remote unreachable");
        // Remote bridge not reachable. statePollTimer will keep retrying /state
        // and surface connection errors via setBridgeError.
        root.setBridgeError("Remote bridge unreachable at " + bridgeHost + ":" + bridgePort);
      } else if (root.autoStartBridge) {
        Logger.i("hermes-agent", "ensureBridge starting local bridge");
        root.startBridge();
        bridgeRetryTimer.start();
      }
    });
  }

  function startGateway() {
    postJson("/gateway/start", {}, function(data) {
      if (data) {
        root.refreshState();
      }
    });
  }

  function stopGateway() {
    postJson("/gateway/stop", {}, function(data) {
      if (data) {
        root.refreshState();
      }
    });
  }

  function autoConfigure() {
    var isFirstRun = !(root.cfg.configured ?? false);
    if (!isFirstRun) return;
    getJson("/detect", function(data) {
      if (!data) return;
      var s = pluginApi?.pluginSettings || ({});
      if (data.hermesHome && data.hermesHomeExists) s.hermesHome = data.hermesHome;
      if (data.hermesCommand) s.hermesCommand = data.hermesCommand;
      if (data.model && data.model.name) s.defaultModel = data.model.name;
      if (data.model && data.model.provider) s.defaultProvider = data.model.provider;
      s.configured = true;
      if (pluginApi) {
        pluginApi.pluginSettings = s;
        pluginApi.saveSettings();
      }
      if (data.hermesHome && data.hermesHome !== root.expandedHermesHome) {
        root.startBridge();
      }
      if (root.autoStartGateway && data.gateway) {
        var gwStatus = data.gateway.status || "";
        if (gwStatus === "offline" || gwStatus === "stopped" || gwStatus === "unknown") {
          root.startGateway();
        }
      }
    });
  }

  function clearChat() {
    var next = JSON.parse(JSON.stringify(root.state));
    next.messages = [];
    next.events = [];
    next.approval = { "pending": false, "message": "", "tool_name": "", "request": ({}) };
    next.session.running = false;
    root.state = next;
  }

  function createSession() {
    Logger.i("hermes-agent", "createSession called");
    postJson("/session/create", {}, function(data) {
      Logger.i("hermes-agent", "createSession response:", data ? "OK session:" + (data.session?.id || "?") : "null");
      if (data) root.state = data;
    });
  }

  function resumeSession(sessionId) {
    postJson("/session/resume", { "session_id": sessionId }, function(data) {
      if (data) root.state = data.state || data;
    });
  }

  function listSessions(callback) {
    getJson("/sessions", function(data) {
      callback(data ? (data.sessions || []) : []);
    });
  }

  function sendPrompt(text) {
    postJson("/prompt", { "text": text }, function(data) {
      if (data && data.state) root.state = data.state;
    });
  }

  function interrupt() {
    postJson("/interrupt", {}, function(data) {
      if (data && data.state) root.state = data.state;
    });
  }

  function respondApproval(choice, all) {
    postJson("/approval", { "choice": choice, "all": all || false }, function(data) {
      if (data && data.state) root.state = data.state;
    });
  }

  function setModel(provider, model, persist) {
    Logger.i("hermes-agent", "setModel:", provider, model, "persist:", persist);
    postJson("/model", { "provider": provider || "", "model": model || "", "persist": persist || false }, function(data) {
      Logger.i("hermes-agent", "setModel response:", data ? "has state:" + !!data.state : "null");
      if (data && data.state) root.state = data.state;
    });
  }

  function openPreferredPanel(screen, buttonItem) {
    if (root.cfg.panelPinned ?? root.defaults.panelPinned ?? false) {
      root.openPinnedPanel(screen);
      return;
    }
    if (screen) {
      root.pluginApi?.openPanel(screen, buttonItem || null);
      return;
    }
    root.pluginApi?.withCurrentScreen(function(currentScreen) {
      if (currentScreen) root.pluginApi?.openPanel(currentScreen, buttonItem || null);
    });
  }

  function openPinnedPanel(screen) {
    if (screen) {
      root.pinnedPanelScreen = screen;
      root.pinnedPanelVisible = true;
      root.refreshState();
      return;
    }
    root.pluginApi?.withCurrentScreen(function(currentScreen) {
      if (currentScreen) {
        root.pinnedPanelScreen = currentScreen;
        root.pinnedPanelVisible = true;
        root.refreshState();
      }
    });
  }

  function closePinnedPanel() {
    root.pinnedPanelVisible = false;
  }

  function setPinnedPanelRequested(value) {
    pinnedPanelRequested = value;
    if (value) {
      root.openPinnedPanel(root.pluginApi?.panelOpenScreen);
      if (root.pluginApi?.panelOpenScreen) root.pluginApi.closePanel(root.pluginApi.panelOpenScreen);
    } else {
      root.closePinnedPanel();
    }
  }

  function oneShot(text) {
    postJson("/oneshot", { "text": text }, function(data) {
      if (data && data.state) root.state = data.state;
    });
  }

  function getJson(path, callback) {
    requestJson("GET", path, null, callback);
  }

  function postJson(path, payload, callback) {
    requestJson("POST", path, payload, callback);
  }

  function requestJson(method, path, payload, callback) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return;
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          Logger.i("hermes-agent", method.toLowerCase() + "Json", path, "OK, token set:", !!root.bridgeToken);
          callback(JSON.parse(xhr.responseText));
        } catch (e) {
          setBridgeError("Invalid bridge response");
          callback(null);
        }
      } else {
        Logger.i("hermes-agent", method.toLowerCase() + "Json", path, "failed status:", xhr.status, "token set:", !!root.bridgeToken, "response:", xhr.responseText?.substring(0,100));
        var msg;
        if (xhr.status === 0) {
          msg = "Connection failed: " + bridgeHost + ":" + bridgePort + " unreachable";
        } else if (xhr.status === 403) {
          msg = "Authentication failed: wrong bridge token";
        } else {
          msg = "Bridge request failed: " + xhr.status;
        }
        setBridgeError(msg);
        callback(null);
      }
    };
    xhr.open(method, bridgeUrl(path));
    if (root.bridgeToken) {
      xhr.setRequestHeader("X-Bridge-Token", root.bridgeToken);
    }
    if (method === "POST") {
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.send(JSON.stringify(payload || {}));
    } else {
      xhr.send();
    }
  }

  function setBridgeError(message) {
    var next = JSON.parse(JSON.stringify(root.state));
    next.bridge = next.bridge || {};
    next.bridge.status = "offline";
    next.bridge.error = message;
    root.state = next;
  }

  function loadStateFromFile() {
    if (root.clientOnlyMode) return; // remote bridge: never overwrite HTTP state with local file
    try {
      var text = stateFileView.text();
      if (!text || text.trim() === "") return;
      root.state = JSON.parse(text);
    } catch (e) {
      setBridgeError("Invalid state file");
    }
  }

  Process {
    id: bridgeProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.setBridgeError("Bridge exited: " + exitCode);
      }
    }
  }

  FileView {
    id: stateFileView
    // Local file watching only works for a local bridge; in client-only mode
    // state is fetched over HTTP by statePollTimer instead.
    path: root.clientOnlyMode ? "" : root.expandedStateFile
    watchChanges: !root.clientOnlyMode
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadStateFromFile()
    onLoadFailed: root.refreshState()
  }

  FileView {
    id: tokenFileView
    path: root.clientOnlyMode ? "" : root.bridgeTokenFile
    watchChanges: !root.clientOnlyMode
    printErrors: false
    onLoaded: {
      var text = tokenFileView.text();
      root.bridgeTokenFromFile = text ? text.trim() : "";
      if (root.bridgeOnlinePending) {
        root.bridgeOnlinePending = false;
        root.refreshState();
        root.autoConfigure();
      }
    }
    onFileChanged: reload()
    onLoadFailed: {}
  }

  Timer {
    interval: root.statusPollIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.ensureBridge()
  }

  // Client-only mode has no local state file to watch, so poll over HTTP.
  // Poll fast while a session is running (live streaming / approvals), slow when idle.
  Timer {
    id: statePollTimer
    interval: (root.state.session && root.state.session.running) ? 1500 : root.statusPollIntervalSec * 1000
    running: root.clientOnlyMode
    repeat: true
    onTriggered: root.ensureBridge()
  }

  Timer {
    id: bridgeRetryTimer
    interval: 500
    repeat: true
    property int attempts: 0
    onTriggered: {
      attempts++;
      if (attempts > 20) {
        bridgeRetryTimer.stop();
        attempts = 0;
        root.setBridgeError("Bridge failed to start");
        return;
      }
      getJson("/health", function(data) {
        if (data && data.bridge && data.bridge.status === "online") {
          bridgeRetryTimer.stop();
          attempts = 0;
          root.onBridgeOnline();
        }
      });
    }
  }

  Component.onCompleted: {
    root.ensureBridge();
    if (root.pinnedPanelRequested && root.pinnedPanelVisible) {
      root.openPinnedPanel(null);
    }
  }

  PinnedPanelWindow {
    pluginApi: root.pluginApi
    panelScreen: root.pinnedPanelScreen
    active: root.pinnedPanelRequested && root.pinnedPanelVisible && (root.cfg.panelPinned ?? root.defaults.panelPinned ?? false)
  }
}
