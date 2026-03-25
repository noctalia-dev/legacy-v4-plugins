import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.UI
import "lib/Ui.js" as Ui

Item {
  id: root

  required property var pluginApi

  visible: false
  width: 0
  height: 0

  readonly property var defaults: pluginApi.manifest?.metadata?.defaultSettings ?? ({})
  readonly property var settings: pluginApi.pluginSettings ?? ({})
  readonly property string homeDir: Quickshell.env("HOME") ?? ""
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp"
  readonly property string userName: Quickshell.env("USER") ?? "user"
  readonly property string managedStatePath: `${runtimeDir}/noctalia-obs-control-${userName}.json`
  readonly property string configuredVideosPath: (settings.videosPath ?? defaults.videosPath ?? "").trim()
  readonly property string videosOpener: (settings.videosOpener ?? defaults.videosOpener ?? "xdg-open").trim()
  readonly property string defaultVideosPath: Quickshell.env("XDG_VIDEOS_DIR") ?? `${homeDir}/Videos`
  readonly property string videosPath: configuredVideosPath === ""
                                       ? defaultVideosPath
                                       : configuredVideosPath === "~"
                                         ? homeDir
                                         : configuredVideosPath.startsWith("~/")
                                           ? `${homeDir}/${configuredVideosPath.slice(2)}`
                                           : configuredVideosPath
  readonly property int minimumPollIntervalMs: 750
  readonly property int defaultPollIntervalMs: 2500
  readonly property int defaultWebsocketPort: 4455
  readonly property int actionRefreshDelayMs: 900
  readonly property int shutdownConfirmDelayMs: 250
  readonly property int displayTickMs: 1000
  readonly property int successToastDurationMs: 3200
  readonly property int errorToastDurationMs: 4200
  readonly property int pollIntervalMs: Math.max(minimumPollIntervalMs, Number(settings.pollIntervalMs ?? defaults.pollIntervalMs ?? defaultPollIntervalMs))
  readonly property string leftClickAction: settings.leftClickAction ?? defaults.leftClickAction ?? "panel"
  readonly property string launchBehavior: settings.launchBehavior ?? defaults.launchBehavior ?? "minimized-to-tray"
  readonly property string barLabelMode: settings.barLabelMode ?? defaults.barLabelMode ?? "short-label"
  readonly property bool showBarWhenRecording: settings.showBarWhenRecording ?? defaults.showBarWhenRecording ?? true
  readonly property bool showBarWhenReplay: settings.showBarWhenReplay ?? defaults.showBarWhenReplay ?? false
  readonly property bool showBarWhenStreaming: settings.showBarWhenStreaming ?? defaults.showBarWhenStreaming ?? true
  // Stored under the legacy showBarWhenReady key for settings compatibility.
  readonly property bool alwaysShowInBar: settings.showBarWhenReady ?? defaults.showBarWhenReady ?? true
  readonly property bool showControlCenterWhenRecording: settings.showControlCenterWhenRecording ?? defaults.showControlCenterWhenRecording ?? true
  readonly property bool showControlCenterWhenReplay: settings.showControlCenterWhenReplay ?? defaults.showControlCenterWhenReplay ?? true
  readonly property bool showControlCenterWhenStreaming: settings.showControlCenterWhenStreaming ?? defaults.showControlCenterWhenStreaming ?? true
  readonly property bool showControlCenterWhenReady: settings.showControlCenterWhenReady ?? defaults.showControlCenterWhenReady ?? false
  readonly property bool autoCloseManagedObs: settings.autoCloseManagedObs ?? defaults.autoCloseManagedObs ?? true
  readonly property bool openVideosAfterStop: settings.openVideosAfterStop ?? defaults.openVideosAfterStop ?? true
  readonly property bool showElapsedInBar: settings.showElapsedInBar ?? defaults.showElapsedInBar ?? false
  readonly property string websocketConfigPath: `${Quickshell.env("XDG_CONFIG_HOME") ?? `${homeDir}/.config`}/obs-studio/plugin_config/obs-websocket/config.json`
  readonly property string websocketUrl: websocketConfigAvailable ? `ws://127.0.0.1:${websocketPort}` : ""
  readonly property bool websocketSupportMissing: websocketLoader.status === Loader.Error
  readonly property bool websocketTransportReady: websocketLoader.status === Loader.Ready
  readonly property bool websocketConfigMissing: !websocketConfigAvailable
  readonly property bool websocketControlAvailable: websocketTransportReady && websocketConfigAvailable
  readonly property bool canOpenVideos: videosPath !== "" && videosOpener !== ""

  property bool actionBusy: false

  property bool websocketConfigAvailable: false
  property int websocketPort: defaultWebsocketPort
  property string websocketPassword: ""
  property bool managedObsLaunch: false
  property var obsProbeCallbacks: []
  property var terminateCallbacks: []
  property var shutdownConfirmCallback: null

  property bool obsRunning: false
  property bool websocket: false
  property bool recording: false
  property bool replayBuffer: false
  property bool streaming: false
  property int recordDurationMs: 0
  property int streamDurationMs: 0
  property int displayRecordDurationMs: 0
  property int displayStreamDurationMs: 0

  readonly property bool connected: obsRunning && websocket
  readonly property var outputState: ({
    recording: recording,
    replayBuffer: replayBuffer,
    streaming: streaming,
    recordDurationMs: recordDurationMs,
    streamDurationMs: streamDurationMs,
  })
  readonly property var visibilitySettings: ({
    showBarWhenRecording: showBarWhenRecording,
    showBarWhenReplay: showBarWhenReplay,
    showBarWhenStreaming: showBarWhenStreaming,
    alwaysShowInBar: alwaysShowInBar,
    showControlCenterWhenRecording: showControlCenterWhenRecording,
    showControlCenterWhenReplay: showControlCenterWhenReplay,
    showControlCenterWhenStreaming: showControlCenterWhenStreaming,
    showControlCenterWhenReady: showControlCenterWhenReady,
  })
  readonly property bool showInBar: Ui.shouldShowInBar(outputState, visibilitySettings)
  readonly property bool showInControlCenter: Ui.shouldShowInControlCenter(outputState, visibilitySettings, connected)
  readonly property string primaryActionText: Ui.primaryActionText(pluginApi, leftClickAction)

  function updateTransportCredentials() {
    if (!websocketLoader.item) {
      return
    }

    websocketLoader.item.url = websocketUrl
    websocketLoader.item.password = websocketPassword
  }

  function loadWebsocketConfig() {
    try {
      const parsed = JSON.parse(websocketConfigFile.text())
      const configuredPort = Number(parsed?.server_port ?? defaultWebsocketPort)
      const validPort = configuredPort > 0 && Math.floor(configuredPort) === configuredPort

      websocketPort = validPort ? configuredPort : defaultWebsocketPort
      websocketPassword = String(parsed?.server_password || "")
      websocketConfigAvailable = parsed?.server_enabled === true && validPort
    } catch (error) {
      websocketPort = defaultWebsocketPort
      websocketPassword = ""
      websocketConfigAvailable = false
    }

    updateTransportCredentials()
  }

  function loadManagedLaunchState() {
    try {
      const parsed = JSON.parse(managedStateFile.text())
      managedObsLaunch = parsed?.managedObsLaunch === true
    } catch (error) {
      managedObsLaunch = false
    }
  }

  function saveManagedLaunchState() {
    managedStateFile.setText(JSON.stringify({
      managedObsLaunch: managedObsLaunch,
    }))
  }

  function beginAction() {
    if (actionBusy) {
      return false
    }

    actionBusy = true
    return true
  }

  function finishAction(refreshSoon) {
    actionBusy = false

    if (refreshSoon !== false) {
      actionRefreshTimer.restart()
    }
  }

  function transportUnavailableBody() {
    if (websocketSupportMissing) {
      return pluginApi.tr("toast.qt_websockets_missing.body")
    }

    if (websocketConfigMissing) {
      return pluginApi.tr("toast.websocket_config_missing.body")
    }

    return pluginApi.tr("toast.error.body")
  }

  function applyStatus(payload) {
    obsRunning = payload?.obsRunning ?? false
    websocket = payload?.websocket ?? false
    recording = payload?.recording ?? false
    replayBuffer = payload?.replayBuffer ?? false
    streaming = payload?.streaming ?? false
    recordDurationMs = Math.max(0, Number(payload?.recordDurationMs ?? 0))
    streamDurationMs = Math.max(0, Number(payload?.streamDurationMs ?? 0))
    displayRecordDurationMs = recording ? recordDurationMs : 0
    displayStreamDurationMs = streaming ? streamDurationMs : 0
    displayTimer.running = recording || streaming
  }

  function resetStatus() {
    applyStatus({
      obsRunning: false,
      websocket: false,
      recording: false,
      replayBuffer: false,
      streaming: false,
      recordDurationMs: 0,
      streamDurationMs: 0,
    })
  }

  function refresh() {
    if (!websocketConfigAvailable) {
      websocketConfigFile.reload()
    }

    probeObsRunning(function(running) {
      obsRunning = running

      if (!running) {
        managedObsLaunch = false
        saveManagedLaunchState()
        websocketLoader.item?.disconnectFromServer()
        root.resetStatus()
        return
      }

      if (!websocketControlAvailable) {
        root.applyStatus({
          obsRunning: true,
          websocket: false,
          recording: false,
          replayBuffer: false,
          streaming: false,
          recordDurationMs: 0,
          streamDurationMs: 0,
        })
        return
      }

      fetchObsStatus(function(status) {
        root.applyStatus({
          obsRunning: true,
          websocket: true,
          recording: status.recording,
          replayBuffer: status.replayBuffer,
          streaming: status.streaming,
          recordDurationMs: status.recordDurationMs,
          streamDurationMs: status.streamDurationMs,
        })
      }, function() {
        root.applyStatus({
          obsRunning: true,
          websocket: false,
          recording: false,
          replayBuffer: false,
          streaming: false,
          recordDurationMs: 0,
          streamDurationMs: 0,
        })
      })
    })
  }

  function requestObs(type, requestData, onSuccess, onFailure) {
    if (!websocketControlAvailable || !websocketLoader.item) {
      if (onFailure) {
        onFailure(transportUnavailableBody())
      }
      return
    }

    updateTransportCredentials()
    websocketLoader.item.request(type, requestData ?? ({}), onSuccess, onFailure)
  }

  function fetchObsStatus(onSuccess, onFailure) {
    const status = {
      recording: false,
      replayBuffer: false,
      streaming: false,
      recordDurationMs: 0,
      streamDurationMs: 0,
    }

    let remaining = 3
    let failed = false

    function complete() {
      remaining -= 1
      if (remaining === 0 && !failed) {
        onSuccess(status)
      }
    }

    function fail(message) {
      if (failed) {
        return
      }

      failed = true
      if (onFailure) {
        onFailure(message)
      }
    }

    requestObs("GetRecordStatus", {}, function(response) {
      status.recording = response?.outputActive ?? false
      status.recordDurationMs = Number(response?.outputDuration ?? 0)
      complete()
    }, fail)

    requestObs("GetReplayBufferStatus", {}, function(response) {
      status.replayBuffer = response?.outputActive ?? false
      complete()
    }, fail)

    requestObs("GetStreamStatus", {}, function(response) {
      status.streaming = response?.outputActive ?? false
      status.streamDurationMs = Number(response?.outputDuration ?? 0)
      complete()
    }, fail)
  }

  function fetchAutoCloseState(onSuccess, onFailure) {
    const state = {
      recordActive: false,
      replayActive: false,
      streamActive: false,
      virtualCamActive: false,
    }

    let remaining = 4
    let failed = false

    function complete() {
      remaining -= 1
      if (remaining === 0 && !failed) {
        onSuccess(state)
      }
    }

    function fail(message) {
      if (failed) {
        return
      }

      failed = true
      if (onFailure) {
        onFailure(message)
      }
    }

    requestObs("GetRecordStatus", {}, function(response) {
      state.recordActive = response?.outputActive ?? false
      complete()
    }, fail)

    requestObs("GetReplayBufferStatus", {}, function(response) {
      state.replayActive = response?.outputActive ?? false
      complete()
    }, fail)

    requestObs("GetStreamStatus", {}, function(response) {
      state.streamActive = response?.outputActive ?? false
      complete()
    }, fail)

    requestObs("GetVirtualCamStatus", {}, function(response) {
      state.virtualCamActive = response?.outputActive ?? false
      complete()
    }, function() {
      state.virtualCamActive = false
      complete()
    })
  }

  function probeObsRunning(callback) {
    obsProbeCallbacks.push(callback)

    if (!obsProbeProcess.running) {
      obsProbeProcess.running = true
    }
  }

  function terminateObs(callback) {
    terminateCallbacks.push(callback)

    if (!terminateObsProcess.running) {
      terminateObsProcess.running = true
    }
  }

  function terminateObsAndConfirm(callback) {
    terminateObs(function() {
      shutdownConfirmCallback = callback
      shutdownConfirmTimer.restart()
    })
  }

  function openVideos() {
    if (videosPath === "" || videosOpener === "") {
      return
    }

    Quickshell.execDetached([videosOpener, videosPath])
  }

  function showActionToast(payload) {
    const translated = Ui.toastPayload(pluginApi, payload)
    const showOpenVideosAction = payload.openVideos && openVideosAfterStop && canOpenVideos
    const actionLabel = showOpenVideosAction ? pluginApi.tr("toast.actions.open_videos") : ""
    const actionCallback = showOpenVideosAction ? function() {
      root.openVideos()
    } : null

    ToastService.showNotice(translated.title, translated.body, "", successToastDurationMs, actionLabel, actionCallback)
  }

  function showProcessErrorToast(detail) {
    const body = detail && detail !== "" ? detail : pluginApi.tr("toast.error.body")

    ToastService.showNotice(
      pluginApi.tr("toast.error.title"),
      body,
      "",
      errorToastDurationMs
    )
  }

  function showUnavailableToast() {
    if (websocketSupportMissing) {
      ToastService.showNotice(
        pluginApi.tr("toast.qt_websockets_missing.title"),
        transportUnavailableBody(),
        "",
        errorToastDurationMs
      )
      return
    }

    if (websocketConfigMissing) {
      ToastService.showNotice(
        pluginApi.tr("toast.websocket_config_missing.title"),
        transportUnavailableBody(),
        "",
        errorToastDurationMs
      )
      return
    }

    showProcessErrorToast(transportUnavailableBody())
  }

  function openControls(screen, anchorItem) {
    if (!screen) {
      return
    }

    pluginApi.togglePanel(screen, anchorItem)
  }

  function openSettings(screen, closePanelFirst) {
    if (!screen || !pluginApi?.manifest) {
      return
    }

    if (closePanelFirst) {
      pluginApi.closePanel(screen)
    }

    Qt.callLater(function() {
      BarService.openPluginSettings(screen, pluginApi.manifest)
    })
  }

  function openSettingsForCurrentContext() {
    const panelScreen = pluginApi?.panelOpenScreen

    if (panelScreen) {
      root.openSettings(panelScreen, true)
      return
    }

    pluginApi.withCurrentScreen(function(screen) {
      root.openSettings(screen, false)
    })
  }

  function togglePanelFromIpc() {
    pluginApi.withCurrentScreen(function(screen) {
      root.openControls(screen, null)
    })
  }

  function launchObs() {
    if (!beginAction()) {
      return
    }

    probeObsRunning(function(running) {
      obsRunning = running

      if (!running) {
        const args = ["obs"]

        managedObsLaunch = false
        saveManagedLaunchState()

        if (launchBehavior === "minimized-to-tray") {
          args.push("--minimize-to-tray")
        }

        Quickshell.execDetached(args)
      }

      finishAction()
    })
  }

  function launchObsForOutputStart(startArgs, startedLaunchEvent) {
    managedObsLaunch = autoCloseManagedObs
    saveManagedLaunchState()
    Quickshell.execDetached(["obs", "--minimize-to-tray"].concat(startArgs ?? []))
    showActionToast({ event: startedLaunchEvent })
    finishAction()
  }

  function finishOutputStop(stopEvent, autoClosedStopEvent, openVideosOnStop) {
    if (!managedObsLaunch) {
      showActionToast({
        event: stopEvent,
        openVideos: openVideosOnStop,
      })
      finishAction()
      return
    }

    fetchAutoCloseState(function(state) {
      const hasActiveOutputs = state.recordActive || state.replayActive || state.streamActive || state.virtualCamActive
      if (hasActiveOutputs) {
        showActionToast({
          event: stopEvent,
          openVideos: openVideosOnStop,
        })
        finishAction()
        return
      }

      terminateObsAndConfirm(function(closed) {
        if (closed) {
          managedObsLaunch = false
          saveManagedLaunchState()
        }

        showActionToast({
          event: closed ? autoClosedStopEvent : stopEvent,
          openVideos: openVideosOnStop,
        })
        finishAction()
      })
    }, function() {
      showActionToast({
        event: stopEvent,
        openVideos: openVideosOnStop,
      })
      finishAction()
    })
  }

  function toggleOutput(startArgs, startedLaunchEvent, statusRequestType, stopRequestType, startRequestType, startedEvent, stoppedEvent, autoClosedStoppedEvent, openVideosOnStop) {
    if (!beginAction()) {
      return
    }

    probeObsRunning(function(running) {
      obsRunning = running

      if (!running) {
        launchObsForOutputStart(startArgs, startedLaunchEvent)
        return
      }

      if (!websocketControlAvailable) {
        showUnavailableToast()
        finishAction(false)
        return
      }

      requestObs(statusRequestType, {}, function(status) {
        const outputActive = status?.outputActive ?? false
        const requestType = outputActive ? stopRequestType : startRequestType

        requestObs(requestType, {}, function() {
          if (!outputActive) {
            showActionToast({ event: startedEvent })
            finishAction()
            return
          }

          finishOutputStop(stoppedEvent, autoClosedStoppedEvent, openVideosOnStop)
        }, function(error) {
          showProcessErrorToast(error)
          finishAction(false)
        })
      }, function(error) {
        showProcessErrorToast(error)
        finishAction(false)
      })
    })
  }

  function toggleRecord() {
    toggleOutput(
      ["--startrecording"],
      "record-started-launch",
      "GetRecordStatus",
      "StopRecord",
      "StartRecord",
      "record-started",
      "record-stopped",
      "record-stopped-autoclose",
      true
    )
  }

  function toggleReplay() {
    toggleOutput(
      ["--startreplaybuffer"],
      "replay-started-launch",
      "GetReplayBufferStatus",
      "StopReplayBuffer",
      "StartReplayBuffer",
      "replay-started",
      "replay-stopped",
      "replay-stopped-autoclose",
      false
    )
  }

  function toggleStream() {
    toggleOutput(
      ["--startstreaming"],
      "stream-started-launch",
      "GetStreamStatus",
      "StopStream",
      "StartStream",
      "stream-started",
      "stream-stopped",
      "stream-stopped-autoclose",
      false
    )
  }

  function saveReplay() {
    if (!beginAction()) {
      return
    }

    probeObsRunning(function(running) {
      obsRunning = running

      if (!running) {
        showActionToast({ event: "offline" })
        finishAction(false)
        return
      }

      if (!websocketControlAvailable) {
        showUnavailableToast()
        finishAction(false)
        return
      }

      requestObs("SaveReplayBuffer", {}, function() {
        showActionToast({
          event: "replay-saved",
          openVideos: true,
        })
        finishAction()
      }, function(error) {
        showProcessErrorToast(error)
        finishAction(false)
      })
    })
  }

  function runPrimaryAction(screen, anchorItem) {
    if (leftClickAction === "toggle-record") {
      toggleRecord()
      return
    }

    if (leftClickAction === "toggle-stream") {
      toggleStream()
      return
    }

    openControls(screen, anchorItem)
  }

  function runSecondaryAction() {
    if (!obsRunning) {
      launchObs()
      return
    }

    if (connected) {
      toggleRecord()
      return
    }

    if (websocketSupportMissing || websocketConfigMissing) {
      showUnavailableToast()
      return
    }

    refresh()
  }

  function runMiddleAction() {
    if (connected) {
      toggleReplay()
      return
    }

    if (obsRunning && (websocketSupportMissing || websocketConfigMissing)) {
      showUnavailableToast()
    }
  }

  Component.onCompleted: {
    managedStateFile.reload()
    refresh()
  }

  Loader {
    id: websocketLoader
    active: true
    source: "lib/ObsWebSocketTransport.qml"

    onStatusChanged: {
      root.updateTransportCredentials()
    }
  }

  FileView {
    id: websocketConfigFile
    path: root.websocketConfigPath
    watchChanges: true

    onLoaded: {
      root.loadWebsocketConfig()
    }

    onLoadFailed: function() {
      root.websocketConfigAvailable = false
      root.websocketPort = root.defaultWebsocketPort
      root.websocketPassword = ""
      root.updateTransportCredentials()
    }
  }

  FileView {
    id: managedStateFile
    path: root.managedStatePath
    watchChanges: false

    onLoaded: {
      root.loadManagedLaunchState()
    }

    onLoadFailed: function() {
      root.managedObsLaunch = false
    }
  }

  Timer {
    id: actionRefreshTimer
    interval: root.actionRefreshDelayMs
    running: false
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: pollTimer
    interval: root.pollIntervalMs
    running: true
    repeat: true

    onTriggered: {
      if (!root.actionBusy) {
        root.refresh()
      }
    }
  }

  Timer {
    id: shutdownConfirmTimer
    interval: root.shutdownConfirmDelayMs
    running: false
    repeat: false

    onTriggered: {
      root.probeObsRunning(function(running) {
        const callback = root.shutdownConfirmCallback
        root.shutdownConfirmCallback = null

        if (callback) {
          callback(!running)
        }
      })
    }
  }

  Timer {
    id: displayTimer
    interval: root.displayTickMs
    running: false
    repeat: true

    onTriggered: {
      if (!root.recording) {
        root.displayRecordDurationMs = 0
      }

      if (!root.streaming) {
        root.displayStreamDurationMs = 0
      }

      if (!root.recording && !root.streaming) {
        running = false
        return
      }

      if (root.recording) {
        root.displayRecordDurationMs += root.displayTickMs
      }

      if (root.streaming) {
        root.displayStreamDurationMs += root.displayTickMs
      }
    }
  }

  Process {
    id: obsProbeProcess
    running: false
    command: ["pgrep", "-x", "obs"]

    onExited: function(exitCode) {
      const callbacks = root.obsProbeCallbacks
      root.obsProbeCallbacks = []
      const running = exitCode === 0

      for (const callback of callbacks) {
        callback(running)
      }
    }
  }

  Process {
    id: terminateObsProcess
    running: false
    command: ["pkill", "-x", "obs"]

    onExited: function(exitCode) {
      const callbacks = root.terminateCallbacks
      root.terminateCallbacks = []
      const terminated = exitCode === 0 || exitCode === 1

      for (const callback of callbacks) {
        callback(terminated)
      }
    }
  }

  IpcHandler {
    target: "plugin:obs-control"

    function togglePanel() {
      root.togglePanelFromIpc()
    }

    function openSettings() {
      root.openSettingsForCurrentContext()
    }

    function refreshStatus() {
      root.refresh()
    }

    function launchObs() {
      root.launchObs()
    }

    function toggleRecord() {
      root.toggleRecord()
    }

    function toggleReplay() {
      root.toggleReplay()
    }

    function toggleStream() {
      root.toggleStream()
    }

    function saveReplay() {
      root.saveReplay()
    }

    function openVideos() {
      root.openVideos()
    }

    function primaryAction() {
      if (root.leftClickAction === "toggle-record") {
        root.toggleRecord()
        return
      }

      if (root.leftClickAction === "toggle-stream") {
        root.toggleStream()
        return
      }

      root.togglePanelFromIpc()
    }

    function secondaryAction() {
      root.runSecondaryAction()
    }

    function middleAction() {
      root.runMiddleAction()
    }
  }
}
