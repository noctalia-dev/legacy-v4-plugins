import Quickshell
import qs.Widgets

NIconButtonHot {
  property ShellScreen screen
  property var pluginApi: null

  icon: "clipboard"
  tooltipText: pluginApi?.tr("widget.tooltip")
  onClicked: {
    if (pluginApi) {
      pluginApi.mainInstance?.refreshOnPanelOpen();
      pluginApi.togglePanel(screen, this);
    }
  }
}
