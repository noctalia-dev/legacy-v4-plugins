import QtQuick
import Quickshell
import qs.Widgets

NIconButton {
	property ShellScreen screen
	property var pluginApi: null

	icon: "file-text"
	tooltipText: pluginApi?.tr("bar.tooltip")

	onClicked: {
		if (pluginApi) {
				pluginApi.togglePanel(screen);
		}
	}
}
