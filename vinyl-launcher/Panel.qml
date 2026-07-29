import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property var screen: pluginApi ? pluginApi.panelOpenScreen : null

    readonly property var geometryPlaceholder: core
    readonly property bool allowAttach: false

    readonly property bool panelAnchorHorizontalCenter: true
    readonly property bool panelAnchorVerticalCenter: true
    readonly property color panelBackgroundColor: "transparent"

    property real contentPreferredWidth: screen ? Math.round(screen.height * 0.463) : Math.round(500 * Style.uiScaleRatio)
    property real contentPreferredHeight: contentPreferredWidth

    implicitWidth: contentPreferredWidth
    implicitHeight: contentPreferredHeight

    VinylCore {
        id: core
        anchors.fill: parent
        
        screen: root.screen
        isOpen: root.pluginApi ? (root.pluginApi.panelOpenScreen !== null) : false
        
        onRequestClose: {
            if (root.pluginApi && root.screen) {
                root.pluginApi.closePanel(root.screen)
            }
        }

        onRequestCloseImmediately: {
            if (root.pluginApi && root.screen) {
                root.pluginApi.closePanel(root.screen)
            }
        }
    }
}
