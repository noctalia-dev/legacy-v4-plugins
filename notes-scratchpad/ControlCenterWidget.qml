import QtQuick
import Quickshell
import qs.Services.UI
import qs.Widgets

NIconButtonHot {
    property ShellScreen screen
    property var pluginApi: null

    icon: "file-text"
    tooltipText: pluginApi?.tr("bar_widget.tooltip") || "Scratchpad"

    onClicked: {
        if (pluginApi) {
            pluginApi.togglePanel(screen);
        }
    }

    onRightClicked: {
        if (pluginApi && pluginApi.manifest) {
            BarService.openPluginSettings(screen, pluginApi.manifest);
        }
    }
}
