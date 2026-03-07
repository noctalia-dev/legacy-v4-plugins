import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    visible: CompositorService.isHyprland

    z: 999

    readonly property string mainIcon: cfg.mainIcon ?? defaults.mainIcon
    readonly property string expandDirection: cfg.expandDirection ?? defaults.expandDirection
    readonly property bool isVertical: expandDirection === "up" || expandDirection === "down"

    // Primary button settings
    readonly property bool priShowPill: cfg.primaryShowPill ?? defaults.primaryShowPill
    readonly property string priSymbolColor: cfg.primarySymbolColor ?? defaults.primarySymbolColor
    readonly property string priPillColor: cfg.primaryPillColor ?? defaults.primaryPillColor
    readonly property real primarySize: cfg.primarySize ?? defaults.primarySize

    // Secondary button settings
    readonly property bool secShowPill: cfg.secondaryShowPill ?? defaults.secondaryShowPill
    readonly property string secSymbolColor: cfg.secondarySymbolColor ?? defaults.secondarySymbolColor
    readonly property string secPillColor: cfg.secondaryPillColor ?? defaults.secondaryPillColor
    readonly property real secondarySize: cfg.secondarySize ?? defaults.secondarySize

    readonly property real borderRadius: cfg.borderRadius ?? defaults.borderRadius
    readonly property string focusBorderColor: cfg.focusBorderColor ?? defaults.focusBorderColor

    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
    readonly property real mainPillSize: Math.round(capsuleHeight * primarySize / 2) * 2
    readonly property real secPillSize: Math.round(capsuleHeight * secondarySize / 2) * 2
    readonly property real mainIconSize: Style.toOdd(mainPillSize * 0.55)
    readonly property real secIconSize: Style.toOdd(secPillSize * 0.55)
    readonly property real pillSpacing: Style.marginXS

    readonly property var configuredWorkspaces: {
        var list = cfg.workspaces ?? defaults.workspaces;
        if (!list || !Array.isArray(list)) list = defaults.workspaces || [];
        var result = [];
        for (var i = 0; i < list.length; i++) {
            result.push({
                "name": "special:" + list[i].name,
                "shortName": list[i].name,
                "icon": list[i].icon
            });
        }
        return result;
    }

    // --- State tracking ---

    property var activeWorkspaceNames: ({})
    property string internalActiveSpecial: ""

    readonly property bool hasActiveWorkspaces: Object.keys(activeWorkspaceNames).length > 0
    readonly property bool isOnSpecial: internalActiveSpecial !== ""
    property bool manuallyExpanded: false
    readonly property bool expanded: isOnSpecial || manuallyExpanded

    onIsOnSpecialChanged: {
        if (!isOnSpecial) manuallyExpanded = false;
    }

    // --- Hyprland integration ---

    function updateActiveWorkspaces() {
        if (!CompositorService.isHyprland) {
            activeWorkspaceNames = {};
            return;
        }
        try {
            var names = {};
            var ws = Hyprland.workspaces.values;
            for (var i = 0; i < ws.length; i++) {
                if (ws[i].name && ws[i].name.startsWith("special:")) {
                    names[ws[i].name] = true;
                }
            }
            activeWorkspaceNames = names;
        } catch (e) {
            activeWorkspaceNames = {};
        }
    }

    Connections {
        target: CompositorService.isHyprland ? Hyprland : null
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                const dataParts = event.data.split(",");
                const wsName = dataParts[0];
                if (wsName && wsName.startsWith("special:")) {
                    root.internalActiveSpecial = wsName;
                } else {
                    root.internalActiveSpecial = "";
                }
            }
            if (["createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2"].includes(event.name)) {
                updateActiveWorkspaces();
            }
        }
    }

    Component.onCompleted: {
        Logger.i("SpecialWorkspaces", "Widget loaded");
        if (CompositorService.isHyprland) {
            updateActiveWorkspaces();
            try {
                const initial = Hyprland.focusedMonitor?.specialWorkspace?.name;
                if (initial && initial.startsWith("special:")) {
                    root.internalActiveSpecial = initial;
                }
            } catch(e) {}
        }
    }

    // --- Sizing ---

    readonly property int totalSecPills: expanded ? configuredWorkspaces.length : 0

    readonly property real fullSize: mainPillSize + (totalSecPills > 0 ? pillSpacing + secPillSize * totalSecPills + pillSpacing * Math.max(0, totalSecPills - 1) : 0)

    implicitWidth: isVertical ? capsuleHeight : fullSize
    implicitHeight: isVertical ? fullSize : capsuleHeight

    Behavior on implicitWidth { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic } }

    opacity: hasActiveWorkspaces ? 1.0 : 0.3
    Behavior on opacity { NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutQuad } }

    clip: false

    // --- Components ---

    component MainButton: Rectangle {
        id: mainBtn
        implicitWidth: root.mainPillSize
        implicitHeight: root.mainPillSize
        radius: root.mainPillSize / 2 * root.borderRadius
        color: {
            if (mainBtnMouse.containsMouse) return root.priShowPill ? Color.mHover : Color.mTertiary;
            if (!root.priShowPill) return "transparent";
            return root.priPillColor === "none" ? Color.mPrimary : Color.resolveColorKey(root.priPillColor);
        }

        Behavior on color { ColorAnimation { duration: Style.animationFast } }

        NIcon {
            icon: root.mainIcon
            pointSize: root.mainIconSize
            applyUiScale: false
            color: {
                if (mainBtnMouse.containsMouse) return root.priShowPill ? Color.mOnHover : Color.mOnTertiary;
                if (root.priSymbolColor !== "none") return Color.resolveColorKey(root.priSymbolColor);
                return root.priShowPill ? (root.priPillColor === "none" ? Color.mOnPrimary : Color.resolveOnColorKey(root.priPillColor)) : Color.mOnSurface;
            }
            anchors.centerIn: parent
        }

        MouseArea {
            id: mainBtnMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) {
                    PanelService.showContextMenu(contextMenu, root, screen);
                    return;
                }
                if (root.expanded) {
                    if (root.isOnSpecial) {
                        Hyprland.dispatch("togglespecialworkspace");
                    }
                    root.manuallyExpanded = false;
                } else {
                    root.manuallyExpanded = true;
                }
            }
        }
    }

    component WorkspacePill: Rectangle {
        id: wsPill
        required property var modelData

        implicitWidth: root.secPillSize
        implicitHeight: root.secPillSize
        radius: root.secPillSize / 2 * root.borderRadius
        color: {
            if (wsPillMouse.containsMouse) return root.secShowPill ? Color.mHover : Color.mTertiary;
            if (!root.secShowPill) return "transparent";
            return root.secPillColor === "none" ? Color.mPrimary : Color.resolveColorKey(root.secPillColor);
        }

        readonly property bool isActive: root.activeWorkspaceNames[modelData.name] === true
        readonly property bool isFocused: root.internalActiveSpecial === modelData.name

        opacity: isActive ? 1.0 : 0.2
        border.color: {
            if (!isFocused) return "transparent";
            if (root.focusBorderColor !== "none") return Color.resolveColorKey(root.focusBorderColor);
            return root.secShowPill ? Color.mOnPrimary : Color.mPrimary;
        }
        border.width: 2

        Behavior on color { ColorAnimation { duration: Style.animationFast } }

        NIcon {
            icon: wsPill.modelData.icon
            pointSize: root.secIconSize
            applyUiScale: false
            color: {
                if (wsPillMouse.containsMouse) return root.secShowPill ? Color.mOnHover : Color.mOnTertiary;
                if (root.secSymbolColor !== "none") return Color.resolveColorKey(root.secSymbolColor);
                return root.secShowPill ? (root.secPillColor === "none" ? Color.mOnPrimary : Color.resolveOnColorKey(root.secPillColor)) : Color.mOnSurface;
            }
            anchors.centerIn: parent
        }

        MouseArea {
            id: wsPillMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: {
                Hyprland.dispatch(`togglespecialworkspace ${wsPill.modelData.shortName}`);
            }
        }

        Behavior on opacity { NumberAnimation { duration: Style.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
    }

    // --- Context Menu ---

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Widget Settings",
                "action": "settings",
                "icon": "settings"
            }
        ]

        onTriggered: function (action) {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            }
        }
    }

    // --- Layouts ---

    RowLayout {
        visible: !root.isVertical
        anchors.centerIn: parent
        spacing: root.pillSpacing
        layoutDirection: root.expandDirection === "left" ? Qt.RightToLeft : Qt.LeftToRight
        MainButton { Layout.alignment: Qt.AlignVCenter }
        Repeater {
            model: root.configuredWorkspaces
            WorkspacePill { visible: root.expanded; Layout.alignment: Qt.AlignVCenter }
        }
    }

    ColumnLayout {
        visible: root.isVertical
        anchors.centerIn: parent
        spacing: root.pillSpacing

        Repeater {
            model: root.configuredWorkspaces
            WorkspacePill { visible: root.expanded && root.expandDirection === "up"; Layout.alignment: Qt.AlignHCenter }
        }
        MainButton { Layout.alignment: Qt.AlignHCenter }
        Repeater {
            model: root.configuredWorkspaces
            WorkspacePill { visible: root.expanded && root.expandDirection === "down"; Layout.alignment: Qt.AlignHCenter }
        }
    }
}
