import QtQuick
import Quickshell
import qs.Widgets
import qs.Commons

NIconButton {
    id: root

    property ShellScreen screen
    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance

    readonly property string buttonAction: pluginApi?.pluginSettings?.buttonAction || pluginApi?.manifest?.metadata?.defaultSettings?.buttonAction || "toggle-recording"

    icon: "camera-video"
    tooltipText: pluginApi?.tr("name")
    colorFg: mainInstance?.isRecording ? Color.mOnPrimary : (mainInstance?.isReplaying ? Color.mSecondary : Color.mPrimary)
    colorBg: mainInstance?.isRecording ? Color.mPrimary : (mainInstance?.isReplaying ? Qt.alpha(Color.mSecondary, 0.25) : Style.capsuleColor)
    onClicked: {
        if (mainInstance)
            mainInstance.handleButtonAction(buttonAction, () => pluginApi.openPanel(screen, root));
    }
}
