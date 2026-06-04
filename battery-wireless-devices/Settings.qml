import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Plugin-wide settings UI (the "settings" entry point). Rendered inside a
// scroll view by Noctalia's plugin settings popup. Every control applies its
// change live (debounced) via commit(); the popup's Apply button just calls
// saveSettings() -> commit() again, so it's effectively redundant.
ColumnLayout {
    id: root

    property var pluginApi: null
    property real preferredWidth: 540

    spacing: Style.marginM
    Layout.fillWidth: true

    // Working copy of the per-device config: { <id>: { enabled, icon, iconColor,
    // ringColor, launchCmd, name, type } }. Mutated in place by the controls so
    // the Repeater never rebuilds and loses edits.
    property var editDevices: ({})

    // Devices shown in the list: union of currently-detected devices and any
    // previously-configured ones (so unplugged devices keep their settings).
    property var deviceList: []

    readonly property var liveDevices: (pluginApi && pluginApi.mainInstance) ? (pluginApi.mainInstance.devices || []) : []

    readonly property var iconOptions: [
        { key: "", name: "Auto (by type)" },
        { key: "mouse", name: "Mouse" },
        { key: "keyboard", name: "Keyboard" },
        { key: "headphones", name: "Headphones" },
        { key: "device-gamepad", name: "Gamepad" },
        { key: "bluetooth", name: "Bluetooth" },
        { key: "device-desktop", name: "Desktop" },
        { key: "battery", name: "Battery" }
    ]

    // Guards against committing during initial population.
    property bool initialized: false

    Component.onCompleted: {
        populateList()
        initialized = true
    }

    function _defaultCfg() {
        return { enabled: false, icon: "", iconColor: "none", ringColor: "none", launchCmd: "", name: "", type: "device" }
    }

    // Build editDevices + deviceList from saved settings and live detection.
    function populateList() {
        var saved = (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.devices) ? pluginApi.pluginSettings.devices : {}
        var merged = ({})

        // Seed from saved config (preserves offline devices).
        for (var id in saved) {
            merged[id] = Object.assign(root._defaultCfg(), saved[id])
        }
        // Overlay live detection (updates name/type for known, adds new).
        var live = root.liveDevices
        var byId = ({})
        for (var i = 0; i < live.length; i++) {
            var d = live[i]
            byId[d.id] = d
            if (!merged[d.id])
                merged[d.id] = root._defaultCfg()
            merged[d.id].name = d.name
            merged[d.id].type = d.type
        }
        root.editDevices = merged

        // Ordered list for display: live devices first, then offline configured.
        var list = []
        for (var j = 0; j < live.length; j++) {
            var ld = live[j]
            list.push({ id: ld.id, name: ld.name, type: ld.type, battery: ld.battery, charging: ld.charging, online: true })
        }
        for (var sid in merged) {
            if (!byId[sid])
                list.push({ id: sid, name: merged[sid].name || sid, type: merged[sid].type || "device", battery: -1, charging: false, online: false })
        }
        root.deviceList = list
    }

    function set(id, key, value) {
        if (!root.editDevices[id])
            root.editDevices[id] = root._defaultCfg()
        root.editDevices[id][key] = value
        scheduleCommit()
    }

    // Coalesce rapid edits (e.g. typing) into a single persist.
    function scheduleCommit() {
        if (initialized)
            commitTimer.restart()
    }

    Timer {
        id: commitTimer
        interval: 200
        onTriggered: root.commit()
    }

    // Persist the working state to pluginSettings. Rebuilds devices with fresh
    // object identities so the bar widget's bindings re-fire (in-place mutation
    // alone wouldn't notify them).
    function commit() {
        if (!pluginApi)
            return
        var devices = ({})
        for (var id in root.editDevices)
            devices[id] = Object.assign({}, root.editDevices[id])
        pluginApi.pluginSettings.refreshInterval = intervalSpin.value
        pluginApi.pluginSettings.showPercentage = showPctToggle.checked
        pluginApi.pluginSettings.devices = devices
        pluginApi.saveSettings()
    }

    // Called by the settings popup's Apply button.
    function saveSettings() {
        commit()
    }

    // ---- Global options ----------------------------------------------------

    NLabel {
        label: "Device Battery Indicators"
        description: "Select which devices appear in the bar and how each looks."
    }

    NToggle {
        id: showPctToggle
        Layout.fillWidth: true
        label: "Show percentage"
        description: "Display the battery percentage next to each icon."
        checked: (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.showPercentage === true)
        onToggled: root.scheduleCommit()
    }

    NSpinBox {
        id: intervalSpin
        Layout.fillWidth: true
        label: "Refresh interval"
        description: "How often to re-scan devices, in seconds."
        from: 10
        to: 900
        stepSize: 10
        suffix: "s"
        value: {
            var v = (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings.refreshInterval : 60
            return (typeof v === "number" && v > 0) ? v : 60
        }
        onValueChanged: root.scheduleCommit()
    }

    RowLayout {
        Layout.fillWidth: true
        NButton {
            text: "Rescan devices"
            icon: "refresh"
            onClicked: {
                if (pluginApi && pluginApi.mainInstance)
                    pluginApi.mainInstance.refresh()
                rescanTimer.restart()
            }
        }
        Item { Layout.fillWidth: true }
    }

    // Re-read the device list shortly after a manual scan completes.
    Timer {
        id: rescanTimer
        interval: 3000
        onTriggered: root.populateList()
    }

    NDivider { Layout.fillWidth: true }

    NText {
        visible: root.deviceList.length === 0
        text: "No devices detected. Make sure the device is on, then press \"Rescan devices\"."
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // ---- Per-device cards --------------------------------------------------

    Repeater {
        model: root.deviceList

        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property var cfg: root.editDevices[modelData.id] || root._defaultCfg()
            // Notifiable mirror of cfg.enabled so the toggle updates live
            // (editDevices is mutated in place and doesn't emit change signals).
            property bool enabledLocal: cfg.enabled === true

            Layout.fillWidth: true
            implicitHeight: cardCol.implicitHeight + Style.marginM * 2
            radius: Style.radiusM
            color: Color.mSurfaceVariant
            border.width: 1
            border.color: Color.mOutline

            ColumnLayout {
                id: cardCol
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: card.modelData.name
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    NText {
                        text: card.modelData.online
                              ? (card.modelData.battery >= 0 ? card.modelData.battery + "%" : "—")
                                + (card.modelData.charging ? " ⚡" : "")
                              : "offline"
                        color: card.modelData.online ? Color.mPrimary : Color.mOnSurfaceVariant
                    }
                }

                NToggle {
                    Layout.fillWidth: true
                    label: "Show in bar"
                    checked: card.enabledLocal
                    onToggled: checked => {
                        card.enabledLocal = checked
                        root.set(card.modelData.id, "enabled", checked)
                    }
                }

                NComboBox {
                    Layout.fillWidth: true
                    label: "Icon"
                    model: root.iconOptions
                    currentKey: card.cfg.icon || ""
                    onSelected: key => root.set(card.modelData.id, "icon", key)
                }

                NColorChoice {
                    Layout.fillWidth: true
                    label: "Icon color"
                    description: "None uses the theme foreground."
                    currentKey: card.cfg.iconColor || "none"
                    onSelected: key => root.set(card.modelData.id, "iconColor", key)
                }

                NColorChoice {
                    Layout.fillWidth: true
                    label: "Battery ring color"
                    description: "None colours by battery level."
                    currentKey: card.cfg.ringColor || "none"
                    onSelected: key => root.set(card.modelData.id, "ringColor", key)
                }

                NTextInput {
                    Layout.fillWidth: true
                    label: "Command on click"
                    text: card.cfg.launchCmd || ""
                    placeholderText: "e.g. polychromatic-controller / solaar"
                    onTextChanged: root.set(card.modelData.id, "launchCmd", text)
                }
            }
        }
    }
}
