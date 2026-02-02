import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    
    icon: "wallpaper-selector"

    onClicked: {
        pluginApi?.openPanel(root.screen, root);
    }
}
