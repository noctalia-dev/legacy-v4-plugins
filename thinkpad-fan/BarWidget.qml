import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    // ===== NOCTALIA REQUIRED PROPERTIES =====
    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen ? (screen.name ?? "") : ""
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(root.screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(root.screenName)
    readonly property string fixedFont: Settings.data.ui.fontFixed

    property int fanRpm: 0
    property string fanLevel: "auto"
    property int currentTemp: 0
    property bool isInitialized: false

    // ===== READING NATIVE NOCTALIA SETTINGS =====
    readonly property bool colorizeByStatus:
        pluginApi?.pluginSettings?.colorizeByStatus ??
        pluginApi?.manifest?.metadata?.defaultSettings?.colorizeByStatus ??
        true

    readonly property bool allowPopupOpening:
        pluginApi?.pluginSettings?.allowPopupOpening ??
        pluginApi?.manifest?.metadata?.defaultSettings?.allowPopupOpening ??
        true

    readonly property real contentWidth: layout.implicitWidth + Style.marginS * 2
    readonly property real contentHeight: capsuleHeight
    implicitWidth: contentWidth
    implicitHeight: Style.barHeight

    Component.onCompleted: {
        if (pluginApi) {
            pluginApi.mainInstance = root;
        }
        fanLoader.reload();
        tempLoader.reload();
    }

    // Hardware fan monitoring (passive tracking bound to thinkfan)
    FileView {
        id: fanLoader
        path: "/proc/acpi/ibm/fan"
        printErrors: false
        onLoaded: {
            let content = text();
            if (content) {
                let lines = content.split("\n");
                let parsedRpm = 0;
                let parsedLevel = "auto";

                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line.indexOf("speed:") === 0) {
                        parsedRpm = parseInt(line.split(":")[1].trim());
                        if (isNaN(parsedRpm)) parsedRpm = 0;
                    } else if (line.indexOf("level:") === 0) {
                        parsedLevel = line.split(":")[1].replace(/[\r\n\t]/g, "").trim().toLowerCase();
                    }
                }

                root.fanRpm = parsedRpm;
                root.fanLevel = parsedLevel;
                root.isInitialized = true;
            }
        }
    }

    // System temperature monitoring
    FileView {
        id: tempLoader
        path: "/sys/class/thermal/thermal_zone0/temp"
        printErrors: false
        onLoaded: {
            let val = text();
            if (val) {
                let parsed = parseInt(val.trim());
                if (!isNaN(parsed)) {
                    root.currentTemp = Math.round(parsed / 1000);
                }
            }
        }
    }

    // Persistent process responsible for applying fan level changes
    Process {
        id: fanProcess
        onExited: (exitCode, exitStatus) => {
            refreshTimer.start();
        }
    }

    // Executing ACPI fan commands
    function setFanSpeed(targetLevel) {
        if (!root.isInitialized) {
            return;
        }

        let cleanLevel = String(targetLevel).replace(/[\r\n\t]/g, "").trim().toLowerCase();
        if (!cleanLevel || cleanLevel === "unknown") {
            return;
        }

        root.fanLevel = cleanLevel;
        fanProcess.running = false;
        fanProcess.command = ["sh", "-c", "echo level " + cleanLevel + " > /proc/acpi/ibm/fan"];
        fanProcess.running = true;
    }

    Timer { id: refreshTimer; interval: 300; repeat: false; onTriggered: { fanLoader.reload(); tempLoader.reload(); } }
    // procfs/sysfs don't emit inotify events — polling is required for live values
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { fanLoader.reload(); tempLoader.reload(); } }

    readonly property bool isCustomActive: root.fanLevel !== "auto" && root.fanLevel !== "0"

    // ===== NATIVE NOCTALIA CONTEXT MENU =====
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Widget Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: action => {
            contextMenu.close()
            PanelService.closeContextMenu(screen)

            if (action === "settings") {
                if (pluginApi?.manifest) {
                    BarService.openPluginSettings(screen, pluginApi.manifest)
                }
            }
        }
    }

    // ===== GRAPHICAL INTERFACE (CAPSULE) =====
    Rectangle {
        id: visualCapsule
        anchors.centerIn: parent
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        
        color: !root.colorizeByStatus
            ? Style.capsuleColor
            : (root.isCustomActive
                ? Color.mPrimary
                : (root.fanLevel === "0" ? "#cc241d" : Style.capsuleColor))

        border.color: !root.colorizeByStatus
            ? Style.capsuleBorderColor
            : (root.isCustomActive
                ? Color.mPrimary
                : (root.fanLevel === "0" ? "#cc241d" : Style.capsuleBorderColor))
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: Style.marginXS

            NIcon {
                id: fanIcon
                icon: "car-fan"
                color: root.colorizeByStatus && (root.isCustomActive || root.fanLevel === "0") ? Color.mOnPrimary : Color.mOnSurface
            }

            NText {
                id: fanText
                text: root.fanRpm + " RPM"
                pointSize: barFontSize
                font.family: root.fixedFont
                font.weight: Font.Bold
                color: root.colorizeByStatus && (root.isCustomActive || root.fanLevel === "0") ? Color.mOnPrimary : Color.mOnSurface
            }
        }
    }

    // ===== INTERACTION MANAGEMENT =====
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen)
            } else if (mouse.button === Qt.LeftButton) {
                if (root.allowPopupOpening && pluginApi && typeof pluginApi.openPanel === "function") {
                    pluginApi.openPanel(root.screen, root);
                }
            }
        }
    }
}
