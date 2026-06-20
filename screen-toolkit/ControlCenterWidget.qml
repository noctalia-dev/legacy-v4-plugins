import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI
Item {
    id: root
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section:  ""
    readonly property string screenName: screen?.name ?? ""
    readonly property bool _isRecording: (pluginApi?.mainInstance?.recordState ?? "") === "recording"
    implicitWidth:  btn.implicitWidth
    implicitHeight: btn.implicitHeight
    NIconButtonHot {
        id: btn
        anchors.fill: parent
        icon:        "crosshair"
        tooltipText: pluginApi?.tr("widget.tooltip")
        onClicked: {
            if (!pluginApi) return
            if (root._isRecording)
                pluginApi.mainInstance?.runRecordStop()
            else
                pluginApi.togglePanel(screen, btn)
        }
    }
    Rectangle {
        visible: root._isRecording
        width: 8; height: 8; radius: Style.radiusXXS
        color: Color.mError || "#f44336"
        anchors { top: btn.top; right: btn.right; topMargin: 4; rightMargin: 4 }
        SequentialAnimation on opacity {
            running: root._isRecording; loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 600 }
            NumberAnimation { to: 1.0; duration: 600 }
        }
    }
}

