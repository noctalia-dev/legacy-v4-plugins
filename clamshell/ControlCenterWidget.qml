import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

NIconButtonHot {
    id: root

    property ShellScreen screen
    property var pluginApi: null

    readonly property var main: pluginApi ? pluginApi.mainInstance : null
    readonly property bool isActive: !!main && main.enabled && main.externalPresent
    readonly property bool isStandby: !!main && main.enabled && !main.externalPresent
    readonly property bool isDisabled: !main || !main.enabled
    readonly property string stateText: main?.stateLabel ? main.stateLabel() : (pluginApi?.tr("state.disabled") || "Off")
    readonly property string outputsText: main?.outputSummary ? main.outputSummary() : ""

    icon: isActive ? "display" : (isDisabled ? "display-off" : "laptop")
    tooltipText: outputsText ? stateText + "\n" + outputsText : stateText

    onClicked: {
        if (root.main) {
            root.main.toggle();
        }
    }
}
