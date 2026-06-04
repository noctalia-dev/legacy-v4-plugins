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

    // Devices shown in the list, in bar order: union of currently-detected
    // devices and any previously-configured ones (so unplugged devices keep
    // their settings). Reorderable by drag; persisted as deviceOrder.
    property var deviceList: []

    // Geometry for the drag-reorderable, absolutely-positioned card list.
    // All cards are the same height, captured from a realized delegate.
    property real cardSpacing: Style.marginS
    property real cardHeight: 0
    readonly property real cardStride: cardHeight + cardSpacing

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

    // Notifiable mirror of the global "show percentage" setting. NToggle emits
    // toggled(checked) but never updates its own `checked`, so we drive it from
    // this property (same reason the per-device toggle uses enabledLocal).
    property bool showPercentageEdit: (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.showPercentage === true)
    property bool showChargingEdit: (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.showCharging === true)

    // Guards against committing during initial population.
    property bool initialized: false

    Component.onCompleted: {
        populateList()
        initialized = true
    }

    function _defaultCfg() {
        return { enabled: false, icon: "", iconColor: "none", ringColor: "none", launchCmd: "", name: "", type: "device" }
    }

    function _source(id) {
        var i = id.indexOf(":")
        return i >= 0 ? id.substring(0, i) : id
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

        // Heal stale duplicates: a saved offline entry that refers to the same
        // physical device as a detected one (same source + name, different id —
        // e.g. an old name-based id from when the serial was unreadable). Fold
        // its config into the detected id, then drop the stale entry.
        var changed = false
        for (var k = 0; k < live.length; k++) {
            var dd = live[k]
            for (var mid in merged) {
                if (mid === dd.id || byId[mid])
                    continue
                if (root._source(mid) !== dd.source || merged[mid].name !== dd.name)
                    continue
                if (!saved.hasOwnProperty(dd.id)) {
                    merged[mid].name = dd.name
                    merged[mid].type = dd.type
                    merged[dd.id] = merged[mid]
                }
                delete merged[mid]
                changed = true
            }
        }

        root.editDevices = merged

        // Build the display list honouring the saved order, appending any
        // newly-detected (online first) then offline devices not yet ordered.
        var order = (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.deviceOrder) ? pluginApi.pluginSettings.deviceOrder : []
        var seen = ({})
        var list = []
        var addId = function (id) {
            if (seen[id] || !merged[id])
                return
            seen[id] = true
            var on = byId[id]
            list.push({
                "id": id,
                "name": on ? on.name : (merged[id].name || id),
                "type": on ? on.type : (merged[id].type || "device"),
                "battery": on ? on.battery : -1,
                "charging": on ? on.charging : false,
                "online": !!on
            })
        }
        for (var oi = 0; oi < order.length; oi++)
            addId(order[oi])
        for (var j = 0; j < live.length; j++)
            addId(live[j].id)
        for (var sid in merged)
            addId(sid)
        root.deviceList = list

        // Persist the dedup so it doesn't reappear.
        if (changed && pluginApi)
            commit()
    }

    // Remove a device entry entirely (e.g. stale offline cruft). A still-present
    // device will be re-detected with default config on the next scan.
    function removeDevice(id) {
        if (root.editDevices[id])
            delete root.editDevices[id]
        var nl = []
        for (var i = 0; i < root.deviceList.length; i++) {
            if (root.deviceList[i].id !== id)
                nl.push(root.deviceList[i])
        }
        root.deviceList = nl
        commit()
    }

    // Reorder the device list (drag-and-drop). Top = left-most in the bar.
    function moveDevice(fromIndex, toIndex) {
        if (fromIndex === toIndex)
            return
        if (fromIndex < 0 || fromIndex >= root.deviceList.length)
            return
        if (toIndex < 0 || toIndex >= root.deviceList.length)
            return
        var nl = root.deviceList.slice()
        var item = nl.splice(fromIndex, 1)[0]
        nl.splice(toIndex, 0, item)
        root.deviceList = nl
        commit()
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
        var order = []
        for (var j = 0; j < root.deviceList.length; j++)
            order.push(root.deviceList[j].id)
        pluginApi.pluginSettings.refreshInterval = intervalSpin.value
        pluginApi.pluginSettings.showPercentage = root.showPercentageEdit
        pluginApi.pluginSettings.showCharging = root.showChargingEdit
        pluginApi.pluginSettings.devices = devices
        pluginApi.pluginSettings.deviceOrder = order
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
        Layout.fillWidth: true
        label: "Show percentage"
        description: "Display the battery percentage next to each icon."
        checked: root.showPercentageEdit
        onToggled: checked => {
            root.showPercentageEdit = checked
            root.scheduleCommit()
        }
    }

    NToggle {
        Layout.fillWidth: true
        label: "Show charging indicator"
        description: "Add a lightning icon next to devices that are charging."
        checked: root.showChargingEdit
        onToggled: checked => {
            root.showChargingEdit = checked
            root.scheduleCommit()
        }
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

    // ---- Per-device cards (drag the handle to reorder) ---------------------

    Item {
        id: cardsContainer
        Layout.fillWidth: true
        implicitHeight: root.deviceList.length > 0 ? root.deviceList.length * root.cardStride - root.cardSpacing : 0

        Repeater {
            id: cardsRepeater
            model: root.deviceList

            delegate: Rectangle {
                id: card
                required property int index
                required property var modelData
                readonly property var cfg: root.editDevices[modelData.id] || root._defaultCfg()
                // Notifiable mirror of cfg.enabled so the toggle updates live
                // (editDevices is mutated in place and doesn't emit change signals).
                property bool enabledLocal: cfg.enabled === true

                // Drag state
                property bool dragging: false
                property int dragStartIndex: -1
                property int dragTargetIndex: -1

                width: cardsContainer.width
                height: cardCol.implicitHeight + Style.marginM * 2
                onHeightChanged: if (root.cardHeight !== height) root.cardHeight = height

                radius: Style.radiusM
                color: Color.mSurfaceVariant
                border.width: 1
                border.color: dragging ? Color.mPrimary : Color.mOutline
                z: dragging ? 10 : 0

                // Resting position, with neighbours shifting to make room while
                // another card is dragged over them.
                y: {
                    if (card.dragging)
                        return card.y
                    var draggedIndex = -1
                    var targetIndex = -1
                    for (var i = 0; i < cardsRepeater.count; i++) {
                        var it = cardsRepeater.itemAt(i)
                        if (it && it.dragging) {
                            draggedIndex = it.dragStartIndex
                            targetIndex = it.dragTargetIndex
                            break
                        }
                    }
                    var stride = card.height + root.cardSpacing
                    if (draggedIndex !== -1 && targetIndex !== -1 && draggedIndex !== targetIndex) {
                        if (draggedIndex < targetIndex) {
                            if (card.index > draggedIndex && card.index <= targetIndex)
                                return (card.index - 1) * stride
                        } else {
                            if (card.index >= targetIndex && card.index < draggedIndex)
                                return (card.index + 1) * stride
                        }
                    }
                    return card.index * stride
                }

                Behavior on y {
                    enabled: !card.dragging
                    NumberAnimation {
                        duration: Style.animationNormal
                        easing.type: Easing.OutQuad
                    }
                }

                ColumnLayout {
                    id: cardCol
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        // Drag handle
                        Rectangle {
                            id: dragHandle
                            Layout.preferredWidth: Style.baseWidgetSize * 0.7
                            Layout.preferredHeight: Style.baseWidgetSize * 0.7
                            Layout.alignment: Qt.AlignVCenter
                            radius: Style.iRadiusXS
                            color: dragMouse.containsMouse ? Color.mSurface : "transparent"

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        Layout.preferredWidth: Style.baseWidgetSize * 0.45
                                        Layout.preferredHeight: 2
                                        radius: 1
                                        color: Color.mOutline
                                    }
                                }
                            }

                            MouseArea {
                                id: dragMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.SizeVerCursor
                                z: 1000
                                onPressed: mouse => {
                                    card.dragStartIndex = card.index
                                    card.dragTargetIndex = card.index
                                    card.dragging = true
                                }
                                onPositionChanged: mouse => {
                                    if (!card.dragging)
                                        return
                                    var dy = mouse.y - dragHandle.height / 2
                                    var newY = Math.max(0, Math.min(card.y + dy, cardsContainer.height - card.height))
                                    card.y = newY
                                    var stride = card.height + root.cardSpacing
                                    var t = Math.floor((newY + card.height / 2) / stride)
                                    card.dragTargetIndex = Math.max(0, Math.min(t, cardsRepeater.count - 1))
                                }
                                onReleased: {
                                    var from = card.dragStartIndex
                                    var to = card.dragTargetIndex
                                    card.dragging = false
                                    card.dragStartIndex = -1
                                    card.dragTargetIndex = -1
                                    if (from !== -1 && to !== -1 && from !== to)
                                        root.moveDevice(from, to)
                                    else
                                        root.deviceList = root.deviceList.slice() // rebuild to snap back
                                }
                                onCanceled: {
                                    card.dragging = false
                                    card.dragStartIndex = -1
                                    card.dragTargetIndex = -1
                                    root.deviceList = root.deviceList.slice()
                                }
                            }
                        }

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

                        NIconButton {
                            icon: "trash"
                            baseSize: Style.baseWidgetSize * 0.8
                            tooltipText: "Remove this device"
                            colorFg: Color.mError
                            onClicked: root.removeDevice(card.modelData.id)
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
}
