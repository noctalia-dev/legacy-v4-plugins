import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    readonly property string screenName: screen?.name ?? ""
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property bool hideInactive: pluginApi?.pluginSettings?.hideInactive ?? pluginApi?.manifest?.metadata?.defaultSettings?.hideInactive ?? false
    readonly property string buttonAction: pluginApi?.pluginSettings?.buttonAction || pluginApi?.manifest?.metadata?.defaultSettings?.buttonAction || "toggle-recording"
    readonly property bool recordingActive: mainInstance?.isRecording ?? false
    readonly property bool replayActive: mainInstance?.isReplaying ?? false

    readonly property color iconColor: Color.resolveColorKey(pluginApi?.pluginSettings?.iconColor ?? pluginApi?.manifest?.metadata?.defaultSettings?.iconColor ?? "none")

    readonly property bool shouldShow: !hideInactive || recordingActive || replayActive

    visible: true
    opacity: shouldShow ? 1.0 : 0.0
    implicitWidth: shouldShow ? baseSize : 0
    implicitHeight: shouldShow ? baseSize : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Style.animationNormal
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Style.animationNormal
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Style.animationNormal
        }
    }

    icon: "camera-video"
    tooltipText: pluginApi?.tr("name")
    tooltipDirection: BarService.getTooltipDirection()
    baseSize: root.capsuleHeight
    applyUiScale: false
    customRadius: Style.radiusL
    colorBg: recordingActive ? Color.mPrimary : (replayActive ? Qt.alpha(Color.mSecondary, 0.25) : Style.capsuleColor)
    colorFg: recordingActive ? Color.mOnPrimary : (replayActive ? Color.mSecondary : root.iconColor)
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    onClicked: {
        if (mainInstance)
            mainInstance.handleButtonAction(buttonAction, () => pluginApi.openPanel(screen, root));
    }

    onRightClicked: {
        PanelService.showContextMenu(contextMenu, root, screen);
    }

    NPopupContextMenu {
        id: contextMenu

        model: {
            var items = [];

            items.push({
                "label": recordingActive ? pluginApi.tr("messages.stop-recording") : pluginApi.tr("messages.start-recording"),
                "action": recordingActive ? "stop-recording" : "start-recording",
                "icon": recordingActive ? "stop" : "player-play",
                "enabled": true
            });
            items.push({
                "label": replayActive ? pluginApi.tr("messages.stop-replay") : pluginApi.tr("messages.start-replay"),
                "action": replayActive ? "stop-replay" : "start-replay",
                "icon": replayActive ? "stop" : "player-play",
                "enabled": !recordingActive
            });
            if (replayActive) {
                items.push({
                    "label": pluginApi.tr("messages.save-replay"),
                    "action": "save-replay",
                    "icon": "device-floppy",
                    "enabled": true
                });
            }
            items.push({
                "label": pluginApi.tr("messages.open-panel"),
                "action": "open-panel",
                "icon": "layout-sidebar-right-expand",
                "enabled": true
            });
            items.push({
                "label": I18n.tr("actions.widget-settings"),
                "action": "widget-settings",
                "icon": "settings",
                "enabled": true
            });

            return items;
        }

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "open-panel") {
                pluginApi.openPanel(screen, root);
            } else if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            } else if (mainInstance) {
                if (action === "start-recording") {
                    mainInstance.startRecording();
                } else if (action === "stop-recording") {
                    mainInstance.stopRecording();
                } else if (action === "start-replay") {
                    mainInstance.startReplay();
                } else if (action === "stop-replay") {
                    mainInstance.stopReplay();
                } else if (action === "save-replay") {
                    mainInstance.saveReplay();
                }
            }
        }
    }
}
