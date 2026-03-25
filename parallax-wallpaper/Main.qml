import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root

    property var pluginApi

    ParallaxBackground {
        pluginApi: root.pluginApi
    }
}
