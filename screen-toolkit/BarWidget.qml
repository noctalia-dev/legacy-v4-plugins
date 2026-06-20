import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Modules.Bar.Extras
import qs.Services.UI
Item {
    id: root
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    property var pluginApi: null
    implicitWidth:  pill.width
    implicitHeight: pill.height
    readonly property bool _isRecording: (pluginApi?.mainInstance?.recordState ?? "") === "recording"
    BarPill {
        id: pill
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        forceClose: true
        icon:        "crosshair"
        tooltipText: pluginApi?.tr("widget.tooltip")
        onClicked: {
            if (!pluginApi) return
            if ((pluginApi.mainInstance?.recordState ?? "") === "recording")
                pluginApi.mainInstance?.runRecordStop()
            else
                pluginApi.togglePanel(root.screen, pill)
        }
        onRightClicked: {
            PanelService.showContextMenu(contextMenu, pill, root.screen)
        }
    }
    Rectangle {
        visible: root._isRecording
        width: 8; height: 8; radius: Style.radiusXXS
        color: Color.mError
        anchors { top: pill.top; right: pill.right; topMargin: Style.marginXS; rightMargin: Style.marginXS }
        SequentialAnimation on opacity {
            running: root._isRecording; loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 600 }
            NumberAnimation { to: 1.0; duration: 600 }
        }
    }
    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label":   pluginApi?.tr("settings.widgetSettings"),
                "action":  "widget-settings",
                "icon":    "settings",
                "enabled": true
            }
        ]
        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(root.screen)
            if (action === "widget-settings")
                BarService.openPluginSettings(screen, pluginApi.manifest)
        }
    }
}

