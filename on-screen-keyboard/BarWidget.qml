import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null

    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    NIconButton {
        id: barButton
        anchors.centerIn: parent
        icon: "keyboard"
        onClicked: {
            if (pluginApi?.mainInstance != null) {
                pluginApi.mainInstance.isOpen = !pluginApi.mainInstance.isOpen;
            }
        }
        tooltipText: pluginApi?.tr("bar.toggle-keyboard") || "Toggle on-screen keyboard"
    }
}
