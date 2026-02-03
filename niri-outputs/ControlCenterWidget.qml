import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property var screen: null
    
    tooltipText: pluginApi ? pluginApi.tr("panel.display-configuration") : "Displays"
    icon: "device-desktop"

    // Default styling (inactive)
    colorBg: Color.mSurfaceVariant
    colorFg: Color.mOnSurface

    onClicked: {
        if (pluginApi) {
            pluginApi.openPanel(root.screen, root)
        }
    }
}
