import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Services.Compositor
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null
    property bool inOverview: CompositorService.overviewActive
    property bool launcherOpen: false

    Connections {
        target: CompositorService

        function onOverviewActiveChanged() {
            if (!CompositorService.overviewActive) {
                root.launcherOpen = false;
            }
        }
    }

    // Create overlay windows on all screens
    Variants {
        id: overlayVariants
        model: Quickshell.screens

        PanelWindow {
            id: overlayWindow
            required property var modelData
            readonly property bool isActiveScreen: true
            readonly property var launcherPanel: PanelService.getPanel("launcherPanel", screen)
            // Monitor launcher panel state

            Connections {
                target: overlayWindow.launcherPanel
                function onIsPanelOpenChanged() {
                    if (!overlayWindow.launcherPanel.isPanelOpen) {
                        // Launcher closed
                        if (root.launcherOpen && root.inOverview) {
                            // User launched an app, exit overview mode
                            Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
                        }
                        // Reclaim keyboard focus
                        root.launcherOpen = false;
                    }
                }
            }

            screen: modelData
            visible: root.inOverview
            color: "transparent"

            WlrLayershell.namespace: "noctalia:niri-overview-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
						WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: {
                if (!root.inOverview) return WlrKeyboardFocus.None;
                if (root.launcherOpen) return WlrKeyboardFocus.None;
                if (!isActiveScreen) return WlrKeyboardFocus.None;
                return WlrKeyboardFocus.Exclusive;
            }

            // Make the window cover the whole screen but be transparent
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // Empty mask so the window is click-through
            mask: Region {
                item: null
            }

            FocusScope {
                id: keyboardFocusScope
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if ([Qt.Key_Escape, Qt.Key_Return].includes(event.key)) {
                        Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Left) {
                        Quickshell.execDetached(["niri", "msg", "action", "focus-column-left"]);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Right) {
                        Quickshell.execDetached(["niri", "msg", "action", "focus-column-right"]);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Up) {
                        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-up"]);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Down) {
                        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace-down"]);
                        event.accepted = true;
                        return;
                    }
                    if ([Qt.Key_Tab, Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta].includes(event.key)) {
                        event.accepted = false;
                        return;
                    }
                    if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
                        event.accepted = false;
                        return;
                    }
                    if ([Qt.Key_Delete, Qt.Key_Backspace].includes(event.key)) {
                        event.accepted = false;
                        return;
                    }
                    if (event.isAutoRepeat) {
                        event.accepted = false;
                        return;
                    }
                    if (!event.text || event.text.trim() === "") {
                        event.accepted = false;
                        return;
                    }
                    if (overlayWindow.launcherPanel) {
                        if (!overlayWindow.launcherPanel.isPanelOpen) {
                            overlayWindow.launcherPanel.open();
                        }
                        root.launcherOpen = true;
                        overlayWindow.launcherPanel.setSearchText(event.text);
                    }
                    event.accepted = true;
                }
            }
        }
    }
}
