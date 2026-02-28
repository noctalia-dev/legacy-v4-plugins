import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
    id: root
    property var pluginApi: null

    // Keyboard state
    property bool isOpen: false
    property bool isPinned: false
    property int shiftMode: 0  // 0: off, 1: single shift, 2: caps lock
    property var modifierStates: ({})  // Track modifier key states

    // Settings
    property string currentLayout: "English (US)"
    property bool showFunctionKeys: true
    property int keyboardHeight: 300

    // Ydotool shift key codes
    readonly property var shiftKeyCodes: [42, 54]  // Left and Right Shift

    // Load settings on startup
    onPluginApiChanged: {
        if (pluginApi) {
            currentLayout = pluginApi.pluginSettings?.layout ?? "English (US)";
            isPinned = pluginApi.pluginSettings?.pinnedOnStartup ?? false;
            showFunctionKeys = pluginApi.pluginSettings?.showFunctionKeys ?? true;
            keyboardHeight = pluginApi.pluginSettings?.keyboardHeight ?? 300;
        }
    }

    // IPC Handler for external control
    IpcHandler {
        target: "plugin:on-screen-keyboard"

        function toggle() {
            root.isOpen = !root.isOpen;
        }

        function open() {
            root.isOpen = true;
        }

        function close() {
            root.isOpen = false;
            releaseAllKeys();
        }

        function getState(): string {
            return JSON.stringify({
                isOpen: root.isOpen,
                isPinned: root.isPinned,
                layout: root.currentLayout
            });
        }
    }

    // Keyboard window management
    Variants {
        model: Quickshell.screens

        KeyboardWindow {
            required property var modelData
            screen: modelData
            pluginApi: root.pluginApi
            visible: root.isOpen
            isPinned: root.isPinned
            currentLayout: root.currentLayout
            keyboardHeight: root.keyboardHeight
            showFunctionKeys: root.showFunctionKeys
            
            onCloseRequested: {
                root.isOpen = false;
                releaseAllKeys();
            }

            onPinToggled: (pinned) => {
                root.isPinned = pinned;
                if (pluginApi) {
                    pluginApi.pluginSettings.pinnedOnStartup = pinned;
                    pluginApi.saveSettings();
                }
            }

            onKeyPress: (keycode) => {
                pressKey(keycode);
            }

            onKeyRelease: (keycode, keytype) => {
                releaseKey(keycode, keytype);
            }

            shiftMode: root.shiftMode
            onShiftModeChanged: root.shiftMode = shiftMode
        }
    }

    // Ydotool key simulation functions
    function pressKey(keycode) {
        ydotoolPress.command = ["ydotool", "key", keycode + ":1"];
        ydotoolPress.running = true;
    }

    function releaseKey(keycode, keytype) {
        if (keytype === "normal") {
            ydotoolRelease.command = ["ydotool", "key", keycode + ":0"];
            ydotoolRelease.running = true;

            // Auto-release shift after normal key
            if (root.shiftMode === 1) {
                releaseShiftKeys();
            }
        } else if (keytype === "modkey") {
            // Modkeys are toggle, handled in KeyboardWindow
        }
    }

    function releaseShiftKeys() {
        root.shiftMode = 0;
        for (var i = 0; i < shiftKeyCodes.length; i++) {
            ydotoolRelease.command = ["ydotool", "key", shiftKeyCodes[i] + ":0"];
            ydotoolRelease.running = true;
        }
    }

    function releaseAllKeys() {
        // Release all modifier keys
        releaseShiftKeys();
        
        // Release Ctrl keys
        ydotoolRelease.command = ["ydotool", "key", "29:0"];
        ydotoolRelease.running = true;
        ydotoolRelease.command = ["ydotool", "key", "97:0"];
        ydotoolRelease.running = true;
        
        // Release Alt keys
        ydotoolRelease.command = ["ydotool", "key", "56:0"];
        ydotoolRelease.running = true;
        ydotoolRelease.command = ["ydotool", "key", "100:0"];
        ydotoolRelease.running = true;

        root.modifierStates = {};
    }

    Process {
        id: ydotoolPress
        running: false
    }

    Process {
        id: ydotoolRelease
        running: false
    }

    // Check if ydotool is installed
    Process {
        id: ydotoolCheck
        command: ["which", "ydotool"]
        running: true

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                ToastService.showError(
                    pluginApi?.tr("error.ydotool-not-found") || "ydotool not found",
                    pluginApi?.tr("error.ydotool-install") || "Please install ydotool to use the on-screen keyboard"
                );
                Logger.e("OnScreenKeyboard", "ydotool is not installed");
            } else {
                Logger.i("OnScreenKeyboard", "ydotool found and ready");
            }
        }
    }
}
