import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services.Compositor

Item {
  id: root
  property var pluginApi: null

  readonly property var liveOutputs: isNiri ? niriProvider.outputs : wlrProvider.outputs
  readonly property var niriOutputs: configParser.outputs
  readonly property bool isNiri: CompositorService.isNiri
  readonly property bool loading: niriProvider.loading || wlrProvider.loading || configParser.loading
  readonly property bool modifying: niriProvider.modifying

  Component.onCompleted: { if (pluginApi) refresh() }
  onPluginApiChanged: { if (pluginApi) refresh() }

  function refresh() {
    refreshLive()
    if (isNiri) refreshConfig()
  }

  function refreshLive() {
    if (isNiri) niriProvider.refresh()
    else wlrProvider.refresh()
  }

  function refreshConfig() {
    configParser.configPath = pluginApi?.pluginSettings?.niriConfigPath || "~/.config/niri/config.kdl"
    configParser.start()
  }

  function setMode(name, mode) { niriProvider.setMode(name, mode) }
  function setScale(name, scale) { niriProvider.setScale(name, scale) }
  function setTransform(name, t) { niriProvider.setTransform(name, t) }
  function setVrr(name, on) { niriProvider.setVrr(name, on) }
  function setPower(name, on) { niriProvider.setPower(name, on) }

  function startMonitor() { udev.start() }
  function stopMonitor() { udev.stop() }

  NiriOutputProvider {
    id: niriProvider
    onModifySucceeded: root.refreshLive()
  }

  WlrOutputProvider { id: wlrProvider }

  NiriConfigParser { id: configParser }

  UdevMonitor {
    id: udev
    onTriggered: root.refreshLive()
  }

  IpcHandler {
    target: "plugin:display-settings"

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => root.pluginApi.togglePanel(screen))
      }
    }
  }
}
