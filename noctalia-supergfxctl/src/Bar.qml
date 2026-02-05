/*
 * SPDX-FileCopyrightText: 2025 cod3ddot@proton.me
 *
 * SPDX-License-Identifier: MIT
 */

pragma ValueTypeBehavior: Addressable

import QtQuick

import Quickshell

import qs.Commons
import qs.Widgets
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Services.Noctalia

/**
	Bar widget for showing the current GPU mode, with an optional badge when a pending
	action is available.

	Left click to open the plugin panel
	Right click to open a context menu
 */
Item {
    id: root

    // Plugin API (injected by PluginPanelSlot)
    property QtObject pluginApi: null
    readonly property QtObject pluginCore: pluginApi?.mainInstance

    // Required properties for bar widgets
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string currentIcon: pluginCore?.getModeIcon(pluginCore.mode) ?? ""
    readonly property string currentLabel: pluginCore?.getModeLabel(pluginCore.mode) ?? ""

    implicitWidth: pill.width
    implicitHeight: pill.height

    // https://github.com/noctalia-dev/noctalia-shell/blob/main/Modules/Bar/Extras/BarPill.qml
    BarPill {
        id: pill

        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)

        // makes the tooltip delay shorter
        forceClose: true

        opacity: root.pluginCore?.available ? 1.0 : 0.5
        icon: root.currentIcon
        tooltipText: root.pluginCore?.getTooltip() ?? ""

        onClicked: root.pluginApi?.openPanel(root.screen, this)

        onRightClicked: {
            PanelService.showContextMenu(contextMenu, pill, root.screen);
        }

        Rectangle {
            id: badge
            visible: root.pluginCore?.hasPendingAction ?? false
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 2
            anchors.topMargin: 1
            z: 2
            height: 8
            width: 8
            radius: Style.radiusXS
            color: Color.mTertiary
            border.color: Color.mSurface
            border.width: Style.borderS
        }
    }

    // https://github.com/noctalia-dev/noctalia-shell/blob/main/Widgets/NPopupContextMenu.qml
    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": root.currentLabel,
                "action": "current",
                "icon": root.currentIcon,
                "enabled": false
            },
            {
                "label": root.pluginApi?.tr("context-menu.refresh"),
                "action": "refresh",
                "icon": "refresh",
                "enabled": root.pluginCore?.available && !root.pluginCore?.busy
            },
            {
                "label": "Access settings in the control center",
                "action": "widget-settings",
                "icon": "settings",
                "enabled": false
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);

            switch (action) {
            case "refresh":
                root.pluginCore?.refresh();
                break;
            case "widget-settings":
                // TODO: unsupported for now
                break;
            }
        }
    }
}
