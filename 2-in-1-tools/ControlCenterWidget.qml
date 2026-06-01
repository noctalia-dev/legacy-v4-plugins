import QtQuick
import Quickshell
import qs.Widgets

NIconButtonHot {
    property ShellScreen screen
    property var pluginApi: null

    readonly property string outputName: screen?.name ?? ""
    readonly property var backend: pluginApi?.mainInstance
    readonly property string currentTransform: backend?.transformForOutput(outputName) ?? "Normal"

    icon: backend?.buttonIconName() ?? "rotate-cw"
    visible: backend?.buttonVisible(outputName) ?? false
    enabled: backend?.buttonEnabled(outputName) ?? false
    tooltipText: backend?.buttonTooltip(outputName) ?? ("Rotate display · Current: " + (backend?.transformLabel(currentTransform) ?? "Normal"))

    onClicked: backend?.activatePrimaryButton(outputName)

    Component.onCompleted: backend?.refreshTransform(outputName)
    onScreenChanged: backend?.refreshTransform(outputName)
}
