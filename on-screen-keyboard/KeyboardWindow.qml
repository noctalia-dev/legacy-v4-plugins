import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services.Keyboard
import qs.Widgets
import "Layouts.mjs" as Layouts

PanelWindow {
    id: root

    required property ShellScreen screen
    property var pluginApi: null
    property bool isPinned: false
    property string currentLayout: KeyboardLayoutService.currentLayout
    property int keyboardHeight: 300
    property bool showFunctionKeys: true
    property int shiftMode: 0

    signal closeRequested
    signal pinToggled(bool pinned)
    signal keyPress(int keycode)
    signal keyRelease(int keycode, string keytype)

    property var layoutData: Layouts.byName[currentLayout] || Layouts.byName[Layouts.defaultLayout]

    anchors {
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "noctalia-on-screen-keyboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: isPinned ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: isPinned ? keyboardContainer.implicitHeight : 0

    implicitHeight: keyboardContainer.implicitHeight
    implicitWidth: screen.width

    // Background with shadow
    Rectangle {
        id: keyboardContainer
        anchors.centerIn: parent
        width: keyRows.implicitWidth + Style.marginL * 2
        implicitHeight: keyRows.implicitHeight + Style.marginL * 2 + controlBar.height
        color: Color.mSurface
        radius: Style.radiusL

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            // Control bar
            RowLayout {
                id: controlBar
                Layout.fillWidth: true
                spacing: Style.marginS

                NIconButton {
                    icon: root.isPinned ? "pin" : "pinned"
                    onClicked: {
                        root.isPinned = !root.isPinned;
                        root.pinToggled(root.isPinned);
                    }
                    tooltipText: root.isPinned ? (pluginApi?.tr("tooltip.unpin") || "Unpin keyboard") : (pluginApi?.tr("tooltip.pin") || "Pin keyboard")
                }

                Item {
                    Layout.fillWidth: true
                }

                NText {
                    readonly property string languageName: layoutData.name_short || "Unknown"
                    text: pluginApi?.tr("panel.current_language", {
                        "language": languageName
                    }) || `Current language: ${languageName}`
                }

                NIconButton {
                    icon: "x"
                    onClicked: root.closeRequested()
                    tooltipText: pluginApi?.tr("tooltip.close") || "Close keyboard"
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutlineVariant
            }

            // Keyboard layout
            KeyboardContent {
                id: keyRows
                Layout.fillWidth: true
                Layout.fillHeight: true
                layoutData: root.layoutData
                showFunctionKeys: root.showFunctionKeys
                shiftMode: root.shiftMode

                onKeyPressed: (keycode, keytype) => {
                    root.keyPress(keycode);

                    // Handle shift mode
                    if (keytype === "modkey" && root.isShiftKey(keycode)) {
                        if (root.shiftMode === 0) {
                            root.shiftMode = 1;  // Single shift
                        } else if (root.shiftMode === 1) {
                            root.shiftMode = 2;  // Caps lock
                        } else {
                            root.shiftMode = 0;  // Turn off
                        }
                    }
                }

                onKeyReleased: (keycode, keytype) => {
                    root.keyRelease(keycode, keytype);
                }
            }
        }
    }

    function isShiftKey(keycode) {
        return keycode === 42 || keycode === 54;
    }

    Keys.onEscapePressed: root.closeRequested()
}
