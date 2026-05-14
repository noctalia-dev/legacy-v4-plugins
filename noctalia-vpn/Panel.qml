import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

/*
  Noctalia VPN — full panel UI.

  Layout matches the v6 main-screen JSX design: header → connected hero card →
  speed-test card → routing chips → servers list. Modals (Edit Server, Settings)
  cover the panel as full overlays.

  All actions are routed through `main.callBackend(...)`; the panel itself is
  pure presentation.
*/
Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 700 * Style.uiScaleRatio

    readonly property var main: pluginApi ? pluginApi.mainInstance : null

    // ── Design tokens (V2Ray Proxy UX — olive / chartreuse palette) ────────
    readonly property QtObject tokens: QtObject {
        readonly property color bg:          "#1b1c17"
        readonly property color bgSoft:      "#23241d"
        readonly property color card:        "#26271f"
        readonly property color cardHi:      "#2e2f25"
        readonly property color cardActive:  "#34362a"
        readonly property color border:      "#33342a"
        readonly property color borderSoft:  "#2a2b22"
        readonly property color accent:      "#cfe04e"
        readonly property color accentDim:   "#a8b73f"
        readonly property color accentText:  "#1b1c17"
        readonly property color text:        "#e8e7df"
        readonly property color textDim:     "#a3a497"
        readonly property color muted:       "#7d7e71"
        readonly property color success:     "#9bd17a"
        readonly property color successDim:  "#6b9a52"
        readonly property color danger:      "#d68a7a"
        readonly property color pingGood:    "#9bd17a"
        readonly property color pingMid:     "#e0c84e"
        readonly property color pingBad:     "#d68a7a"

        readonly property string fontUi:   "Inter, -apple-system, system-ui, sans-serif"
        readonly property string fontMono: "JetBrains Mono, ui-monospace, Menlo, monospace"
    }

    function pingTone(ms) {
        if (ms === undefined || ms === null || ms < 0) return tokens.muted
        if (ms < 60)  return tokens.pingGood
        if (ms < 150) return tokens.pingMid
        return tokens.pingBad
    }

    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // Country code → regional-indicator emoji flag (ISO 3166 alpha-2).
    function flagFor(code) {
        if (!code || code.length < 2) return ""
        const base = 0x1F1E6
        const a = code.toUpperCase().charCodeAt(0) - 65
        const b = code.toUpperCase().charCodeAt(1) - 65
        if (a < 0 || a > 25 || b < 0 || b > 25) return ""
        return String.fromCodePoint(base + a) + String.fromCodePoint(base + b)
    }

    function protoTokens(p) {
        switch ((p || "").toUpperCase()) {
        case "SSH":    return { bg: Qt.rgba(0.608, 0.702, 0.819, 0.12), fg: "#9ab7d1", bd: Qt.rgba(0.608, 0.702, 0.819, 0.22) }
        case "VLESS":  return { bg: Qt.rgba(0.812, 0.878, 0.306, 0.14), fg: "#cfe04e", bd: Qt.rgba(0.812, 0.878, 0.306, 0.28) }
        case "VMESS":  return { bg: Qt.rgba(0.757, 0.549, 0.851, 0.14), fg: "#c18cd9", bd: Qt.rgba(0.757, 0.549, 0.851, 0.25) }
        case "SS":     return { bg: Qt.rgba(0.851, 0.6, 0.404, 0.14),   fg: "#d99967", bd: Qt.rgba(0.851, 0.6, 0.404, 0.25) }
        case "SOCKS5": return { bg: Qt.rgba(0.851, 0.6, 0.404, 0.14),   fg: "#d99967", bd: Qt.rgba(0.851, 0.6, 0.404, 0.25) }
        }
        return { bg: tokens.cardHi, fg: tokens.textDim, bd: tokens.border }
    }

    // ── Modal state ─────────────────────────────────────────────────────────
    property bool serverEditorOpen: false
    property var serverEditorPayload: ({})  // working copy
    property bool settingsOpen: false
    property string settingsTab: "rules"     // general | rules | lists | advanced

    // ── Speed test transient (per-panel; result lives in main) ──────────────
    property bool testRunning: false
    property int testPingMs: -1
    property int testJitterMs: -1
    property string testTakenAt: ""
    property var testTakenSamples: []  // for jitter calc

    anchors.fill: parent

    // ──────────────────────────────────────────────────────────────────────
    // Card / list helpers (declared as inner components)
    // ──────────────────────────────────────────────────────────────────────

    component HCard: Rectangle {
        radius: 14
        color: tokens.card
        border.color: tokens.borderSoft
        border.width: 1
    }

    component SmallIcon: Rectangle {
        property string icon: ""
        property color tint: tokens.textDim
        property bool solid: false
        property int sz: 28
        signal clicked()

        width: sz; height: sz
        radius: sz / 2
        color: solid ? tokens.cardHi : "transparent"

        NIcon {
            anchors.centerIn: parent
            icon: parent.icon
            color: parent.tint
            pointSize: Math.max(11, Math.round(parent.sz * 0.52))
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component MasterToggle: Rectangle {
        property bool on: false
        property bool compact: false
        signal toggled()

        readonly property int w: compact ? 30 : 38
        readonly property int h: compact ? 18 : 22
        readonly property int knob: h - 4

        width: w; height: h
        implicitWidth: w; implicitHeight: h
        Layout.preferredWidth: w
        Layout.preferredHeight: h
        radius: 99
        color: on ? tokens.accent : tokens.cardHi
        border.color: on ? tokens.accent : tokens.border
        border.width: 1

        Rectangle {
            width: parent.knob; height: parent.knob
            radius: parent.knob / 2
            color: parent.on ? tokens.accentText : tokens.textDim
            x: parent.on ? parent.width - width - 3 : 1
            y: (parent.height - height) / 2
            Behavior on x { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    // ProtoTag pill: SSH / VLESS / VMess / SS / SOCKS5
    component ProtoTag: Rectangle {
        property string proto: ""
        readonly property var pc: protoTokens(proto)
        radius: 4
        color: pc.bg
        border.color: pc.bd
        border.width: 1
        implicitWidth: protoLabel.implicitWidth + 12
        implicitHeight: protoLabel.implicitHeight + 3

        NText {
            id: protoLabel
            anchors.centerIn: parent
            text: parent.proto.toUpperCase()
            color: parent.pc.fg
            font.pointSize: 9
            font.family: tokens.fontMono
            font.weight: Font.Bold
            font.letterSpacing: 0.6
        }
    }

    // Ping badge: dot (with glow) + ms (mono, tabular)
    component PingBadge: Row {
        property int ms: -1
        spacing: 5
        visible: ms >= 0

        Rectangle {
            width: 6; height: 6; radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: pingTone(parent.ms)
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 10; radius: 5
                color: "transparent"
                border.color: pingTone(parent.parent.ms)
                border.width: 1
                opacity: 0.4
            }
        }
        NText {
            text: parent.ms + "ms"
            color: tokens.textDim
            pointSize: 10
            font.family: tokens.fontMono
        }
    }

    // Mode segmented button (chip)
    component ModeChip: Rectangle {
        property string label: ""
        property string value: ""
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        height: 38
        radius: 10
        color: selected ? tokens.accent : tokens.card
        border.color: selected ? tokens.accent : tokens.border
        border.width: 1

        NText {
            anchors.centerIn: parent
            text: parent.label
            color: parent.selected ? tokens.accentText : tokens.text
            font.weight: Font.Bold
            pointSize: Style.fontSizeM
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Background container — this is what the panel mounts into
    // ──────────────────────────────────────────────────────────────────────

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            id: surface
            anchors.fill: parent
            radius: 18
            color: tokens.bg
            border.color: tokens.borderSoft
            border.width: 1

            // ── Main column ────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // ── Header ─────────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: headerRow.implicitHeight + 24
                    color: "transparent"

                    // bottom divider
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: tokens.borderSoft
                    }

                    RowLayout {
                        id: headerRow
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 14
                        anchors.bottomMargin: 10
                        spacing: 10

                        NText {
                            text: "V2Ray Proxy"
                            color: tokens.text
                            font.weight: Font.DemiBold
                            font.pointSize: 14
                            font.letterSpacing: -0.1
                            Layout.fillWidth: true
                        }

                        MasterToggle {
                            on: root.main && root.main.running
                            onToggled: { if (root.main) root.main.toggleProxy() }
                        }

                        SmallIcon {
                            icon: "settings"
                            solid: false
                            onClicked: root.openSettings("rules")
                        }

                        SmallIcon {
                            icon: "x"
                            onClicked: if (pluginApi) pluginApi.closePanel(root)
                        }
                    }
                }

                // ── Status hero card ───────────────────────────────────────
                HCard {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14
                    Layout.preferredHeight: heroRow.implicitHeight + 28

                    RowLayout {
                        id: heroRow
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        anchors.topMargin: 14
                        anchors.bottomMargin: 14
                        spacing: 12

                        // Shield disk
                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            radius: 19
                            color: heroAccent(0.14)
                            border.color: heroAccent(0.28)
                            border.width: 1

                            NIcon {
                                anchors.centerIn: parent
                                icon: heroIconName()
                                color: heroIconColor()
                                pointSize: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                spacing: 6

                                Rectangle {
                                    Layout.preferredWidth: 7
                                    Layout.preferredHeight: 7
                                    radius: 4
                                    color: heroIconColor()
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 13; height: 13; radius: 7
                                        color: "transparent"
                                        border.color: parent.color
                                        border.width: 1
                                        opacity: 0.45
                                    }
                                }
                                NText {
                                    text: heroTitle()
                                    color: tokens.text
                                    font.weight: Font.DemiBold
                                    font.pointSize: 12
                                }
                                NText {
                                    visible: heroSubtitle().length > 0
                                    text: "· " + heroSubtitle()
                                    color: tokens.muted
                                    font.pointSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                NText {
                                    text: heroLine2()
                                    color: tokens.textDim
                                    font.pointSize: 10
                                    font.family: tokens.fontMono
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // ── Speed test card ────────────────────────────────────────
                HCard {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 10
                    Layout.preferredHeight: speedCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: speedCol
                        anchors.fill: parent
                        spacing: 0

                        // Top row: title + run button
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.topMargin: 11
                            Layout.bottomMargin: 10
                            spacing: 10

                            NIcon {
                                icon: "bolt"
                                color: tokens.textDim
                                pointSize: 12
                            }

                            ColumnLayout {
                                spacing: 1

                                NText {
                                    text: root.testRunning ? "Testing…" : "Network test"
                                    color: tokens.text
                                    font.pointSize: 11
                                    font.weight: Font.DemiBold
                                }
                                NText {
                                    text: root.testRunning
                                          ? "measuring through tunnel"
                                          : (root.testTakenAt.length
                                             ? "Last run " + root.testTakenAt
                                             : "Tap Run to test current server")
                                    color: tokens.muted
                                    font.pointSize: 9
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                radius: 10
                                color: root.testRunning ? tokens.cardHi : tokens.accent
                                border.width: 0
                                implicitWidth: runText.implicitWidth + 28

                                NText {
                                    id: runText
                                    anchors.centerIn: parent
                                    text: root.testRunning ? "STOP" : "RUN TEST"
                                    color: root.testRunning ? tokens.textDim : tokens.accentText
                                    font.weight: Font.Bold
                                    font.pointSize: 10
                                    font.letterSpacing: 0.3
                                    font.family: tokens.fontUi
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSpeedTest()
                                }
                            }
                        }

                        // Top divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: tokens.borderSoft
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            rowSpacing: 0
                            columnSpacing: 1

                            Repeater {
                                model: [
                                    { label: "Ping",   unit: "ms",   key: "ping",   icon: "" },
                                    { label: "Jitter", unit: "ms",   key: "jitter", icon: "" },
                                    { label: "Down",   unit: "Mbps", key: "down",   icon: "arrow-down" },
                                    { label: "Up",     unit: "Mbps", key: "up",     icon: "arrow-up" }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: cellCol.implicitHeight + 22
                                    color: tokens.card

                                    // Background "separator" provided by columnSpacing on grid
                                    // showing the borderSoft beneath.
                                    Rectangle {
                                        visible: index > 0
                                        width: 1
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.leftMargin: -1
                                        color: tokens.borderSoft
                                    }

                                    ColumnLayout {
                                        id: cellCol
                                        anchors.centerIn: parent
                                        spacing: 3

                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 3

                                            NIcon {
                                                visible: modelData.icon.length > 0
                                                icon: modelData.icon
                                                color: tokens.muted
                                                pointSize: 10
                                            }
                                            NText {
                                                text: modelData.label.toUpperCase()
                                                color: tokens.muted
                                                font.pointSize: 9
                                                font.weight: Font.Bold
                                                font.letterSpacing: 0.7
                                            }
                                        }

                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 2

                                            NText {
                                                text: statValue(modelData.key)
                                                color: root.testRunning ? tokens.muted : tokens.text
                                                font.pointSize: root.testRunning ? 12 : 14
                                                font.family: tokens.fontMono
                                                font.weight: Font.DemiBold
                                            }
                                            NText {
                                                Layout.bottomMargin: 1
                                                Layout.alignment: Qt.AlignBottom
                                                text: modelData.unit
                                                color: tokens.muted
                                                font.pointSize: 9
                                                font.weight: Font.Medium
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Progress strip while testing
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 2
                            color: tokens.cardHi
                            visible: root.testRunning
                            clip: true

                            Rectangle {
                                id: progressBar
                                width: parent.width * 0.4
                                height: parent.height
                                color: tokens.accent
                                NumberAnimation on x {
                                    running: root.testRunning
                                    from: -progressBar.width
                                    to: parent.width
                                    duration: 1400
                                    loops: Animation.Infinite
                                }
                            }
                        }
                    }
                }

                // ── Mode chips (Routing + Via) ────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 12
                    spacing: 8

                    ModeSummaryChip {
                        title: "ROUTING"
                        value: (root.main && root.main.mode === "global") ? "Global" : "Rules"
                        onClicked: {
                            if (!root.main) return
                            root.main.setMode(root.main.mode === "rules" ? "global" : "rules")
                        }
                    }

                    ModeSummaryChip {
                        title: "VIA"
                        value: (root.main && root.main.proxyMode === "tun") ? "VPN (TUN)" : "System proxy"
                        onClicked: {
                            if (!root.main) return
                            root.main.setProxyMode(root.main.proxyMode === "system" ? "tun" : "system")
                        }
                    }
                }

                // ── Servers section header ─────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 16
                    Layout.bottomMargin: 8
                    spacing: 8

                    NText {
                        text: "Servers"
                        color: tokens.text
                        font.weight: Font.DemiBold
                        font.pointSize: 12
                    }
                    NText {
                        text: "· " + (root.main ? (root.main.servers || []).length : 0)
                        color: tokens.muted
                        font.pointSize: 10
                        Layout.fillWidth: true
                    }
                    // "+ Add" button
                    Rectangle {
                        Layout.preferredHeight: 28
                        implicitWidth: addRow.implicitWidth + 18
                        radius: 10
                        color: "transparent"
                        border.color: tokens.border
                        border.width: 1

                        RowLayout {
                            id: addRow
                            anchors.centerIn: parent
                            spacing: 5

                            NIcon { icon: "plus"; color: tokens.text; pointSize: 11 }
                            NText {
                                text: "Add"
                                color: tokens.text
                                font.pointSize: 10
                                font.family: tokens.fontUi
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openServerEditor(null)
                        }
                    }
                }

                // (Search bar removed — was triggered by a no-op icon. Re-add later if needed.)

                // ── Server list ────────────────────────────────────────────
                ListView {
                    id: serverList
                    readonly property real cardSlot: 58 * Style.uiScaleRatio
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4 * cardSlot + 3 * 4
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.topMargin: 0
                    Layout.bottomMargin: 12
                    clip: true
                    spacing: 4
                    model: filteredServers()

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        property bool isSelected: root.main
                                                  && modelData
                                                  && modelData.id === root.main.activeServerId
                        property bool isActive: isSelected && root.main && root.main.running

                        width: ListView.view ? ListView.view.width : implicitWidth
                        implicitHeight: row.implicitHeight + 20
                        radius: 10
                        color: isActive
                               ? tokens.cardActive
                               : (isSelected ? withAlpha(tokens.accent, 0.05) : "transparent")
                        border.color: isActive
                                      ? tokens.border
                                      : (isSelected ? withAlpha(tokens.accent, 0.4) : "transparent")
                        border.width: 1

                        RowLayout {
                            id: row
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 10

                            // active / selected dot (with halo when active)
                            Rectangle {
                                Layout.preferredWidth: 7
                                Layout.preferredHeight: 7
                                radius: 4
                                color: row.parent.isActive
                                       ? tokens.success
                                       : (row.parent.isSelected ? withAlpha(tokens.accent, 0.7) : tokens.border)
                                Rectangle {
                                    visible: row.parent.isActive
                                    anchors.centerIn: parent
                                    width: 13; height: 13; radius: 7
                                    color: "transparent"
                                    border.color: tokens.success
                                    border.width: 1
                                    opacity: 0.45
                                }
                            }

                            NText {
                                text: flagFor(modelData ? (modelData.country || "") : "")
                                font.pointSize: 14
                                visible: text.length > 0
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    spacing: 6

                                    NText {
                                        text: modelData ? (modelData.name || "Server") : ""
                                        color: tokens.text
                                        font.weight: row.parent.isSelected ? Font.DemiBold : Font.Medium
                                        font.pointSize: 11
                                    }

                                    ProtoTag { proto: protoLabelFor(modelData) }
                                }

                                NText {
                                    text: serverEndpoint(modelData)
                                    color: tokens.muted
                                    font.pointSize: 9
                                    font.family: tokens.fontMono
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }

                            // Latency for the active server
                            PingBadge {
                                visible: row.parent.isActive && root.main && root.main.healthLatencyMs > 0
                                ms: root.main ? root.main.healthLatencyMs : -1
                            }

                            SmallIcon {
                                sz: 24
                                icon: "edit"
                                onClicked: root.openServerEditor(modelData)
                            }
                            SmallIcon {
                                sz: 24
                                icon: "trash"
                                onClicked: {
                                    if (!root.main || !modelData) return
                                    root.main.removeServer(modelData.id)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true
                            z: -1
                            onClicked: {
                                if (!root.main || !modelData) return
                                root.main.selectServer(modelData.id)
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Rectangle {
                        anchors.fill: parent
                        visible: serverList.count === 0
                        color: "transparent"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            NIcon { icon: "shield"; color: tokens.textDim; pointSize: 28; Layout.alignment: Qt.AlignHCenter }
                            NText {
                                text: "No servers yet"
                                color: tokens.textDim
                                font.pointSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                            NText {
                                text: "Tap + Add to import or paste a share link"
                                color: tokens.muted
                                font.pointSize: 10
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // Spacer so the panel ends cleanly after the server list.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    // Mode summary chip (inner component, depends on outer state)
    component ModeSummaryChip: Rectangle {
        id: chipRoot
        property string title: ""
        property string value: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: chipCol.implicitHeight + 18
        radius: 10
        color: tokens.card
        border.color: tokens.borderSoft
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            ColumnLayout {
                id: chipCol
                Layout.fillWidth: true
                spacing: 1

                NText {
                    text: chipRoot.title
                    color: tokens.muted
                    font.pointSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 0.7
                }
                NText {
                    text: chipRoot.value
                    color: tokens.text
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                }
            }

            NText {
                text: "⇅"
                color: tokens.textDim
                font.pointSize: 14
                font.family: tokens.fontUi
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chipRoot.clicked()
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Edit / add server modal
    // ──────────────────────────────────────────────────────────────────────

    Rectangle {
        id: serverEditorScrim
        anchors.fill: parent
        visible: root.serverEditorOpen
        color: "#cc000000"
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeServerEditor()
        }

        Rectangle {
            id: serverEditorPanel
            anchors.centerIn: parent
            width: parent.width - 32
            height: Math.min(parent.height - 32, 640)
            radius: 16
            color: tokens.bg
            border.color: tokens.border
            border.width: 1

            MouseArea { anchors.fill: parent }  // swallow scrim clicks

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // header
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: sehRow.implicitHeight + 26
                    color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: tokens.borderSoft
                    }

                    RowLayout {
                        id: sehRow
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 14
                        anchors.bottomMargin: 12
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            NText {
                                text: serverEditorPayload && serverEditorPayload.id
                                      ? "Edit server" : "Add server"
                                color: tokens.text
                                font.weight: Font.DemiBold
                                font.pointSize: 13
                                font.letterSpacing: -0.1
                            }
                            NText {
                                text: (serverEditorPayload && serverEditorPayload.name
                                       ? serverEditorPayload.name
                                       : "New server") + " · " + (currentProto || "VLESS").toUpperCase()
                                color: tokens.muted
                                font.pointSize: 10
                            }
                        }
                        SmallIcon { icon: "x"; onClicked: root.closeServerEditor() }
                    }
                }

                // Share link import banner (dashed accent, no overlay hack)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 12
                    implicitHeight: importRow.implicitHeight + 14
                    radius: 10
                    color: withAlpha(tokens.accent, 0.06)
                    border.color: withAlpha(tokens.accent, 0.30)
                    border.width: 1

                    RowLayout {
                        id: importRow
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 8
                        spacing: 8

                        NIcon { icon: "world"; color: tokens.textDim; pointSize: 11 }
                        NText {
                            text: "Paste share link to auto-fill"
                            color: tokens.textDim
                            font.pointSize: 10
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            Layout.preferredHeight: 22
                            implicitWidth: importBtnText.implicitWidth + 14
                            radius: 6
                            color: "transparent"
                            NText {
                                id: importBtnText
                                anchors.centerIn: parent
                                text: "Import"
                                color: tokens.accent
                                font.weight: Font.DemiBold
                                font.pointSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: importShareLinkFromClipboard()
                            }
                        }
                    }
                }

                // Body
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14
                    Layout.bottomMargin: 12
                    clip: true

                    ColumnLayout {
                        width: serverEditorPanel.width - 32
                        spacing: 16

                        // Protocol picker
                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            NText {
                                text: "PROTOCOL"
                                color: tokens.textDim
                                font.pointSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.7
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: ["vless", "vmess", "shadowsocks", "ssh", "socks5"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        property bool selected: currentProto === modelData

                                        implicitWidth: protoCol.implicitWidth + 22
                                        implicitHeight: protoCol.implicitHeight + 14
                                        radius: 10
                                        color: selected ? tokens.accent : tokens.card
                                        border.color: selected ? tokens.accent : tokens.borderSoft
                                        border.width: 1

                                        ColumnLayout {
                                            id: protoCol
                                            anchors.left: parent.left
                                            anchors.leftMargin: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1
                                            NText {
                                                text: protoDisplayLabel(modelData)
                                                color: parent.parent.selected ? tokens.accentText : tokens.text
                                                font.family: tokens.fontMono
                                                font.weight: Font.Bold
                                                font.pointSize: 10
                                            }
                                            NText {
                                                text: protoEngine(modelData)
                                                color: parent.parent.selected ? tokens.accentText : tokens.muted
                                                font.pointSize: 8
                                                opacity: parent.parent.selected ? 0.7 : 1
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: switchProtocol(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // Identity
                        SeField { label: "NAME"; binding: "name" }

                        // Connection
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            NText {
                                text: "CONNECTION"
                                color: tokens.muted
                                font.pointSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.7
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SeField { Layout.fillWidth: true; Layout.preferredWidth: 2
                                          label: "HOST"; binding: hostFieldKey(); mono: true }
                                SeField { Layout.fillWidth: true; Layout.preferredWidth: 1
                                          label: "PORT"; binding: "port"; mono: true }
                            }
                        }

                        // Authentication block — varies by protocol
                        Loader {
                            Layout.fillWidth: true
                            sourceComponent: {
                                switch (currentProto) {
                                case "ssh":         return sshAuthBlock
                                case "vless":       return vlessAuthBlock
                                case "vmess":       return vmessAuthBlock
                                case "shadowsocks": return ssAuthBlock
                                case "socks5":      return socks5AuthBlock
                                }
                                return null
                            }
                        }
                    }
                }

                // Footer
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: sefRow.implicitHeight + 24
                    color: "transparent"

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: tokens.borderSoft
                    }

                    RowLayout {
                        id: sefRow
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 12
                        anchors.bottomMargin: 12
                        spacing: 10

                        // Test connection
                        Rectangle {
                            Layout.preferredHeight: 32
                            implicitWidth: testBtnRow.implicitWidth + 22
                            radius: 10
                            color: "transparent"
                            border.color: tokens.border
                            border.width: 1

                            RowLayout {
                                id: testBtnRow
                                anchors.centerIn: parent
                                spacing: 6
                                NIcon { icon: "bolt"; color: tokens.text; pointSize: 11 }
                                NText { text: "Test connection"; color: tokens.text; font.pointSize: 11 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: testEditorConnection()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Cancel
                        Rectangle {
                            Layout.preferredHeight: 32
                            implicitWidth: cancelTxt.implicitWidth + 20
                            radius: 10
                            color: "transparent"
                            NText { id: cancelTxt; anchors.centerIn: parent; text: "Cancel"
                                    color: tokens.textDim; font.pointSize: 11 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeServerEditor()
                            }
                        }

                        // Save (accent)
                        Rectangle {
                            Layout.preferredHeight: 32
                            implicitWidth: saveTxt.implicitWidth + 36
                            radius: 10
                            color: tokens.accent
                            border.width: 0
                            NText { id: saveTxt; anchors.centerIn: parent; text: "Save"
                                    color: tokens.accentText
                                    font.pointSize: 12; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: saveServerEditor()
                            }
                        }
                    }
                }
            }
        }
    }

    // Authentication sub-blocks  ----------------------------------------------
    Component {
        id: sshAuthBlock
        ColumnLayout {
            spacing: Style.marginS
            NText {
                text: "AUTHENTICATION"
                color: tokens.muted
                font.pointSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 0.7
            }
            SeField { label: "USER"; binding: "user"; mono: true }
            SeField { label: "KEY FILE"; binding: "keyFile"; mono: true; placeholder: "~/.ssh/id_ed25519" }
            SeField { label: "PASSWORD"; binding: "password"; mono: true; secret: true }
            NText {
                text: "Either key file or password is required."
                color: tokens.muted
                font.pointSize: 10
            }
        }
    }

    Component {
        id: vlessAuthBlock
        ColumnLayout {
            spacing: Style.marginS
            NText { text: "AUTHENTICATION"; color: tokens.muted
                    font.pointSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.7 }
            SeField { label: "UUID";      binding: "uuid";      mono: true }
            SeField { label: "TRANSPORT"; binding: "transport"; mono: true; placeholder: "tcp" }
            SeField { label: "FLOW";      binding: "flow";      mono: true; placeholder: "xtls-rprx-vision" }
            SeField { label: "SECURITY";  binding: "security";  mono: true; placeholder: "reality | tls | none" }
            SeField { label: "SNI";       binding: "sni";       mono: true }
            SeField { label: "FINGERPRINT"; binding: "fp";      mono: true; placeholder: "chrome" }
            SeField { label: "REALITY PBK"; binding: "pbk";     mono: true }
            SeField { label: "REALITY SID"; binding: "sid";     mono: true }
        }
    }

    Component {
        id: vmessAuthBlock
        ColumnLayout {
            spacing: Style.marginS
            NText { text: "AUTHENTICATION"; color: tokens.muted
                    font.pointSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.7 }
            SeField { label: "UUID";      binding: "uuid";     mono: true }
            SeField { label: "ALTER ID";  binding: "alterId";  mono: true; placeholder: "0" }
            SeField { label: "SECURITY";  binding: "security"; mono: true; placeholder: "auto" }
            SeField { label: "TRANSPORT"; binding: "transport"; mono: true; placeholder: "tcp" }
        }
    }

    Component {
        id: ssAuthBlock
        ColumnLayout {
            spacing: Style.marginS
            NText { text: "AUTHENTICATION"; color: tokens.muted
                    font.pointSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.7 }
            SeField { label: "METHOD";   binding: "method";   mono: true; placeholder: "aes-256-gcm" }
            SeField { label: "PASSWORD"; binding: "password"; mono: true; secret: true }
        }
    }

    Component {
        id: socks5AuthBlock
        ColumnLayout {
            spacing: Style.marginS
            NText { text: "AUTHENTICATION"; color: tokens.muted
                    font.pointSize: 9; font.weight: Font.Bold; font.letterSpacing: 0.7 }
            SeField { label: "USERNAME"; binding: "username"; mono: true }
            SeField { label: "PASSWORD"; binding: "password"; mono: true; secret: true }
        }
    }

    // Field used inside the editor — bound to serverEditorPayload[binding]
    component SeField: ColumnLayout {
        id: seRoot
        property string label: ""
        property string binding: ""
        property string placeholder: ""
        property bool mono: false
        property bool secret: false

        Layout.fillWidth: true
        spacing: 5

        NText {
            text: seRoot.label.toUpperCase()
            color: tokens.muted
            font.pointSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 0.7
        }

        Rectangle {
            id: seBox
            Layout.fillWidth: true
            implicitHeight: tin.implicitHeight + 18
            radius: 9
            color: tokens.card
            border.color: tin.activeFocus ? tokens.accent : tokens.borderSoft
            border.width: 1

            TextInput {
                id: tin
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                verticalAlignment: TextInput.AlignVCenter
                color: tokens.text
                selectionColor: tokens.accent
                selectedTextColor: tokens.accentText
                font.family: seRoot.mono ? tokens.fontMono : tokens.fontUi
                font.pointSize: 11
                selectByMouse: true
                clip: true
                activeFocusOnTab: true
                cursorVisible: activeFocus
                echoMode: seRoot.secret ? TextInput.Password : TextInput.Normal

                cursorDelegate: Rectangle {
                    width: 1
                    color: tokens.accent
                    visible: tin.cursorVisible
                }

                Keys.onReturnPressed: tin.nextItemInFocusChain(true).forceActiveFocus()
                Keys.onTabPressed: tin.nextItemInFocusChain(true).forceActiveFocus()

                Component.onCompleted: text = String(seGet(seRoot.binding) || "")
                onTextChanged: seSet(seRoot.binding, text)

                Connections {
                    target: root
                    function onServerEditorPayloadChanged() {
                        const v = seGet(seRoot.binding)
                        const s = v === undefined || v === null ? "" : String(v)
                        if (tin.text !== s) tin.text = s
                    }
                }

                NText {
                    visible: tin.text.length === 0
                    text: seRoot.placeholder
                    color: tokens.muted
                    font.family: tin.font.family
                    font.pointSize: tin.font.pointSize
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Click anywhere in the field box to focus the input
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: tin.forceActiveFocus()
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Settings modal (tabs: General / Routing / Lists / Advanced)
    // ──────────────────────────────────────────────────────────────────────

    Rectangle {
        id: settingsScrim
        anchors.fill: parent
        visible: root.settingsOpen
        color: "#cc000000"
        z: 90

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSettings()
        }

        Rectangle {
            id: settingsPanel
            anchors.centerIn: parent
            width: parent.width - 32
            height: Math.min(parent.height - 32, 700)
            radius: 16
            color: tokens.bg
            border.color: tokens.border
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: settingsHeader.implicitHeight + 26
                    color: "transparent"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: tokens.borderSoft
                    }

                    RowLayout {
                        id: settingsHeader
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 14
                        anchors.bottomMargin: 12
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            NText { text: "Settings"; color: tokens.text
                                    font.weight: Font.DemiBold; font.pointSize: 13
                                    font.letterSpacing: -0.1 }
                            NText { text: "V2Ray Proxy · sing-box · OpenSSH"
                                    color: tokens.muted; font.pointSize: 10 }
                        }
                        SmallIcon { icon: "x"; onClicked: root.closeSettings() }
                    }
                }

                // Tab bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: tabRow.implicitHeight + 16
                    color: tokens.bgSoft
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: tokens.borderSoft
                    }
                    RowLayout {
                        id: tabRow
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 2

                        SettingsTab { label: "General";  value: "general";
                                      selected: settingsTab === "general"
                                      onClicked: settingsTab = "general" }
                        SettingsTab { label: "Routing";  value: "rules";
                                      selected: settingsTab === "rules"
                                      badge: (root.main && root.main.rules) ? root.main.rules.length : 0
                                      onClicked: settingsTab = "rules" }
                        SettingsTab { label: "Subs";     value: "lists";
                                      selected: settingsTab === "lists"
                                      badge: (root.main && root.main.subscriptions) ? root.main.subscriptions.length : 0
                                      onClicked: settingsTab = "lists" }
                        SettingsTab { label: "Advanced"; value: "advanced";
                                      selected: settingsTab === "advanced"
                                      onClicked: settingsTab = "advanced" }
                    }
                }

                // Body
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Loader {
                        width: settingsPanel.width
                        sourceComponent: {
                            switch (settingsTab) {
                            case "general":  return generalPane
                            case "rules":    return rulesPane
                            case "lists":    return listsPane
                            case "advanced": return advancedPane
                            }
                            return null
                        }
                    }
                }

                // Footer
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: settingsFooter.implicitHeight + 16
                    color: "transparent"
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: tokens.borderSoft
                    }
                    RowLayout {
                        id: settingsFooter
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 10

                        NText { text: "Backend: " + bridgeStatusText()
                                color: tokens.muted
                                font.pointSize: 10
                                Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                }
            }
        }
    }

    // Settings tab button
    component SettingsTab: Rectangle {
        id: stRoot
        property string label: ""
        property string value: ""
        property bool selected: false
        property int badge: 0
        signal clicked()

        implicitWidth: tabRowInner.implicitWidth + 24
        implicitHeight: tabRowInner.implicitHeight + 16
        radius: 8
        color: selected ? tokens.cardHi : "transparent"

        RowLayout {
            id: tabRowInner
            anchors.centerIn: parent
            spacing: 6

            NText {
                text: stRoot.label
                color: stRoot.selected ? tokens.text : tokens.textDim
                font.weight: stRoot.selected ? Font.DemiBold : Font.Medium
                font.pointSize: 10
                font.family: tokens.fontUi
            }
            Rectangle {
                visible: stRoot.badge > 0
                implicitWidth: badgeText.implicitWidth + 12
                implicitHeight: badgeText.implicitHeight + 2
                radius: 99
                color: stRoot.selected ? tokens.accent : tokens.border
                NText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "" + stRoot.badge
                    color: stRoot.selected ? tokens.accentText : tokens.textDim
                    font.weight: Font.Bold
                    font.pointSize: 8
                    font.family: tokens.fontMono
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: stRoot.clicked()
        }
    }

    // ── Settings panes ─────────────────────────────────────────────────────

    Component {
        id: generalPane
        ColumnLayout {
            spacing: 0

            SettingsRow {
                label: "Auto-start on shell launch"
                hint: "Activate the last-used server when this plugin loads."
                control: MasterToggle {
                    on: pluginApi && pluginApi.pluginSettings.autoStart === true
                    onToggled: {
                        if (!pluginApi) return
                        pluginApi.pluginSettings.autoStart = !pluginApi.pluginSettings.autoStart
                        pluginApi.saveSettings()
                    }
                }
            }
            SettingsRow {
                label: "Active server"
                hint: root.main && root.main.activeServer()
                      ? root.main.activeServer().name + " · " + serverEndpoint(root.main.activeServer())
                      : "Nothing selected"
                control: null
            }
            SettingsRow {
                label: "Bridge"
                hint: bridgeStatusText()
                control: null
            }
            // ── Bar widget section ──────────────────────────────────────────
            Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginM }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                NText {
                    text: "Bar widget"
                    color: tokens.muted
                    font.pointSize: 10
                    font.weight: Font.DemiBold
                }
            }
            SettingsRow {
                label: "Show ping"
                hint: "Display the active server's latency next to the VPN name (e.g. • 18ms)."
                control: MasterToggle {
                    on: root.main && root.main.showPingInBar === true
                    onToggled: {
                        if (!root.main) return
                        root.main.setShowPingInBar(!root.main.showPingInBar)
                    }
                }
            }
            SettingsRow {
                label: "Show traffic speed"
                hint: "Display download/upload counters in the bar (↓ down  ↑ up)."
                control: MasterToggle {
                    on: root.main && root.main.showTrafficInBar === true
                    onToggled: {
                        if (!root.main) return
                        root.main.setShowTrafficInBar(!root.main.showTrafficInBar)
                    }
                }
            }

            SettingsRow {
                label: "Reset all servers"
                hint: "Clear every server from the backend. Settings stay."
                danger: true
                control: Rectangle {
                    Layout.preferredHeight: 30
                    implicitWidth: resetTxt.implicitWidth + 22
                    radius: 10
                    color: "transparent"
                    border.color: tokens.danger
                    border.width: 1
                    NText { id: resetTxt; anchors.centerIn: parent; text: "Remove"
                            color: tokens.danger; font.pointSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.main) return
                            const list = (root.main.servers || []).slice()
                            for (let i = 0; i < list.length; ++i) {
                                root.main.removeServer(list[i].id)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: rulesPane
        ColumnLayout {
            spacing: Style.marginM

            Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginS }

            // ── Routing presets section ────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                NText {
                    text: "Routing presets"
                    color: tokens.muted
                    font.pointSize: 10
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                spacing: Style.marginXS

                Repeater {
                    model: root.main ? root.main.presets : []
                    delegate: HCard {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: presetRow.implicitHeight + Style.margin2S

                        RowLayout {
                            id: presetRow
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginM

                            NText {
                                text: modelData.flag || ""
                                font.pointSize: 18
                                Layout.alignment: Qt.AlignVCenter
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                NText {
                                    text: modelData.name || modelData.key
                                    color: tokens.text
                                    font.weight: Font.Bold
                                    font.pointSize: 11
                                }
                                NText {
                                    text: modelData.description || ""
                                    color: tokens.muted
                                    font.pointSize: 9
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            MasterToggle {
                                on: modelData.enabled === true
                                Layout.alignment: Qt.AlignVCenter
                                onToggled: {
                                    if (root.main && modelData) {
                                        root.main.togglePreset(modelData.key, !modelData.enabled)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Custom rules header ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                Layout.topMargin: Style.marginS
                NText {
                    text: "Custom rules"
                    color: tokens.muted
                    font.pointSize: 10
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
            }

            // Add rule row
            HCard {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                implicitHeight: addRuleCol.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: addRuleCol
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS
                        NIcon { icon: "filter"; color: tokens.text; pointSize: Style.fontSizeM }
                        NText { text: "Add routing rule"; color: tokens.text
                                font.weight: Font.Bold; font.pointSize: Style.fontSizeM
                                Layout.fillWidth: true }
                    }

                    // type chips (pill buttons matching design)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [
                                { v: "force-proxy", t: "Force proxy" },
                                { v: "direct",      t: "Direct" },
                                { v: "block",       t: "Block" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: ruleType === modelData.v
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 10
                                color: selected ? tokens.accent : tokens.card
                                border.color: selected ? tokens.accent : tokens.borderSoft
                                border.width: 1
                                NText {
                                    anchors.centerIn: parent
                                    text: modelData.t
                                    color: parent.selected ? tokens.accentText : tokens.text
                                    font.weight: Font.DemiBold
                                    font.pointSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ruleType = parent.modelData.v
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 9
                        color: tokens.card
                        border.color: rulePatternInput.activeFocus ? tokens.accent : tokens.borderSoft
                        border.width: 1

                        TextInput {
                            id: rulePatternInput
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            color: tokens.text
                            selectionColor: tokens.accent
                            selectedTextColor: tokens.accentText
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            cursorVisible: activeFocus
                            font.family: tokens.fontMono
                            font.pointSize: 11
                            clip: true
                            cursorDelegate: Rectangle {
                                width: 1
                                color: tokens.accent
                                visible: rulePatternInput.cursorVisible
                            }

                            onTextChanged: {
                                let t = text
                                const low = t.toLowerCase()
                                let stripped = false
                                if (low.indexOf("https://") === 0) { t = t.substring(8); stripped = true }
                                else if (low.indexOf("http://") === 0) { t = t.substring(7); stripped = true }
                                // Strip any trailing slashes that aren't a CIDR prefix.
                                while (t.endsWith("/")) {
                                    const slash = t.indexOf("/")
                                    if (slash >= 0 && slash < t.length - 1) break  // CIDR like 10.0.0.0/8
                                    t = t.substring(0, t.length - 1)
                                    stripped = true
                                }
                                if (stripped) text = t
                            }

                            NText {
                                visible: rulePatternInput.text.length === 0
                                text: "*.openai.com  or  10.0.0.0/8  or  example.com"
                                color: tokens.muted
                                font.family: rulePatternInput.font.family
                                font.pointSize: rulePatternInput.font.pointSize
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: rulePatternInput.forceActiveFocus()
                        }
                    }

                    NText {
                        visible: rulePatternInput.text.length > 0
                                 && /\s/.test(rulePatternInput.text.trim())
                        text: "Use a domain, *.wildcard, or CIDR — no URLs or spaces."
                        color: tokens.danger
                        font.pointSize: 9
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 32
                        implicitWidth: addRuleBtnTxt.implicitWidth + 28
                        radius: 10
                        color: tokens.accent
                        NText { id: addRuleBtnTxt; anchors.centerIn: parent; text: "Add rule"
                                color: tokens.accentText
                                font.weight: Font.Bold; font.pointSize: 11 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let pat = rulePatternInput.text.trim()
                                if (!pat || !root.main) return
                                const low = pat.toLowerCase()
                                if (low.indexOf("https://") === 0) pat = pat.substring(8)
                                else if (low.indexOf("http://") === 0) pat = pat.substring(7)
                                while (pat.endsWith("/")) {
                                    const slash = pat.indexOf("/")
                                    if (slash >= 0 && slash < pat.length - 1) break
                                    pat = pat.substring(0, pat.length - 1)
                                }
                                if (!pat) return
                                root.main.addRule({ type: ruleType, pattern: pat })
                                rulePatternInput.text = ""
                            }
                        }
                    }
                }
            }

            // Existing rules
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                spacing: Style.marginXS

                Repeater {
                    model: root.main ? root.main.rules : []
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: ruleRow.implicitHeight + Style.margin2S
                        radius: Style.radiusS
                        color: tokens.card
                        border.color: tokens.border
                        border.width: Style.borderS

                        RowLayout {
                            id: ruleRow
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginS

                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                color: ruleTypeColor(modelData.type)
                            }
                            NText {
                                text: ruleTypeLabel(modelData.type)
                                color: tokens.textDim
                                pointSize: Style.fontSizeXS
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                            }
                            NText {
                                text: modelData.pattern || ""
                                color: tokens.text
                                font.family: "JetBrains Mono, monospace"
                                font.pointSize: Style.fontSizeS
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            SmallIcon {
                                icon: "trash"
                                onClicked: { if (root.main && modelData) root.main.removeRule(modelData.id) }
                            }
                        }
                    }
                }

                NText {
                    visible: !root.main || (root.main && (root.main.rules || []).length === 0)
                    text: "No rules yet. Add one above."
                    color: tokens.textDim
                    pointSize: Style.fontSizeS
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Style.marginS
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginM }
        }
    }

    Component {
        id: listsPane
        ColumnLayout {
            spacing: Style.marginM

            Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginS }

            // Add subscription
            HCard {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                implicitHeight: subAddCol.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: subAddCol
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    NText { text: "Import subscription"; color: tokens.text
                            font.weight: Font.Bold; font.pointSize: Style.fontSizeM }

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36
                        radius: 9; color: tokens.card
                        border.color: subUrlInput.activeFocus ? tokens.accent : tokens.borderSoft
                        border.width: 1
                        TextInput {
                            id: subUrlInput
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            color: tokens.text
                            selectionColor: tokens.accent
                            selectedTextColor: tokens.accentText
                            font.family: tokens.fontMono
                            font.pointSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true; clip: true
                            cursorVisible: activeFocus
                            cursorDelegate: Rectangle { width: 1; color: tokens.accent; visible: subUrlInput.cursorVisible }
                            NText { visible: subUrlInput.text.length === 0
                                    text: "https://example.com/subscription.txt"
                                    color: tokens.muted
                                    font.family: subUrlInput.font.family
                                    font.pointSize: subUrlInput.font.pointSize
                                    anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor
                                    onClicked: subUrlInput.forceActiveFocus() }
                    }

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36
                        radius: 9; color: tokens.card
                        border.color: subNameInput.activeFocus ? tokens.accent : tokens.borderSoft
                        border.width: 1
                        TextInput {
                            id: subNameInput
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 11
                            color: tokens.text
                            selectionColor: tokens.accent
                            selectedTextColor: tokens.accentText
                            font.pointSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true; clip: true
                            cursorVisible: activeFocus
                            cursorDelegate: Rectangle { width: 1; color: tokens.accent; visible: subNameInput.cursorVisible }
                            NText { visible: subNameInput.text.length === 0
                                    text: "Friendly name (optional)"
                                    color: tokens.muted
                                    font.pointSize: subNameInput.font.pointSize
                                    anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor
                                    onClicked: subNameInput.forceActiveFocus() }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: 32
                        implicitWidth: addSubBtnTxt.implicitWidth + 28
                        radius: 10
                        color: tokens.accent
                        NText { id: addSubBtnTxt; anchors.centerIn: parent; text: "Add subscription"
                                color: tokens.accentText
                                font.weight: Font.Bold; font.pointSize: 11 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const u = subUrlInput.text.trim()
                                if (!u || !root.main) return
                                root.main.addSubscription(u, subNameInput.text.trim(), function(err) {
                                    if (!err) {
                                        root.main.updateSubscription(u)
                                        subUrlInput.text = ""
                                        subNameInput.text = ""
                                    }
                                })
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Style.marginL
                Layout.rightMargin: Style.marginL
                spacing: Style.marginXS

                Repeater {
                    model: root.main ? root.main.subscriptions : []
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: subRow.implicitHeight + Style.margin2S
                        radius: Style.radiusS
                        color: tokens.card
                        border.color: tokens.border
                        border.width: Style.borderS

                        RowLayout {
                            id: subRow
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginS

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                NText { text: modelData ? (modelData.name || modelData.url) : ""
                                        color: tokens.text
                                        font.weight: Font.Bold
                                        pointSize: Style.fontSizeM
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true }
                                NText { text: subSummary(modelData)
                                        color: tokens.textDim
                                        pointSize: Style.fontSizeXS
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true }
                            }
                            SmallIcon {
                                icon: "refresh"
                                onClicked: if (root.main && modelData) root.main.updateSubscription(modelData.url)
                            }
                            SmallIcon {
                                icon: "trash"
                                onClicked: if (root.main && modelData) root.main.removeSubscription(modelData.url)
                            }
                        }
                    }
                }

                NText {
                    visible: !root.main || (root.main && (root.main.subscriptions || []).length === 0)
                    text: "No subscriptions imported."
                    color: tokens.textDim
                    pointSize: Style.fontSizeS
                    opacity: 0.7
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Style.marginS
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginM }
        }
    }

    Component {
        id: advancedPane
        ColumnLayout {
            spacing: 0
            SettingsRow {
                label: "Kill switch"
                hint: (root.main && root.main.killSwitch && root.main.killSwitch.enabled
                       ? (root.main.killSwitch.active
                          ? "Active: all non-tunnel traffic blocked."
                          : "Setting persisted but nftables rules failed to install (needs root or polkit).")
                       : "Block all traffic when proxy fails. Prevents leaks.")
                control: MasterToggle {
                    on: root.main && root.main.killSwitch && root.main.killSwitch.enabled
                    onToggled: {
                        if (!root.main) return
                        const want = !(root.main.killSwitch && root.main.killSwitch.enabled)
                        root.main.setKillSwitch(want)
                    }
                }
            }
            SettingsRow {
                label: "DNS leak status"
                hint: "Run a check against /etc/resolv.conf and current proxy mode."
                control: Rectangle {
                    Layout.preferredHeight: 30
                    implicitWidth: dnsCheckTxt.implicitWidth + 22
                    radius: 10
                    color: "transparent"
                    border.color: tokens.border
                    border.width: 1
                    NText { id: dnsCheckTxt; anchors.centerIn: parent
                            text: "Check"; color: tokens.text; font.pointSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.main) return
                            root.main.callBackend("CheckDnsLeak", [], function(err, res) {
                                if (err) { root.main.toastWarn(err); return }
                                const tag = res && res.leaking ? "LEAKING" : "OK"
                                const ns = res && res.dns_servers ? res.dns_servers.join(", ") : ""
                                if (typeof ToastService !== "undefined")
                                    ToastService.showNotice("DNS " + tag + " · " + ns)
                            })
                        }
                    }
                }
            }
            SettingsRow {
                label: "Local transport port"
                hint: "sing-box / ssh listens here."
                control: NText { text: "" + (root.main ? root.main.transportPort : 11080)
                                 color: tokens.text
                                 pointSize: Style.fontSizeS
                                 font.family: "JetBrains Mono, monospace" }
            }
            SettingsRow {
                label: "Mux port (active)"
                hint: "11081 rules · 11082 global"
                control: NText { text: "" + (root.main ? root.main.muxPort : 11081)
                                 color: tokens.text
                                 pointSize: Style.fontSizeS
                                 font.family: "JetBrains Mono, monospace" }
            }
            SettingsRow {
                label: "Traffic"
                hint: root.main
                      ? ("↓ " + root.main.formatBytes(root.main.trafficRecv) +
                         "  ↑ " + root.main.formatBytes(root.main.trafficSent) +
                         "  · " + root.main.formatDuration(root.main.trafficUptime))
                      : ""
                control: null
            }
            SettingsRow {
                label: "Open log file"
                hint: "/tmp/noctalia-vpn-backend.log"
                control: Rectangle {
                    Layout.preferredHeight: 30
                    implicitWidth: openLogTxt.implicitWidth + 22
                    radius: 10
                    color: "transparent"
                    border.color: tokens.border
                    border.width: 1
                    NText { id: openLogTxt; anchors.centerIn: parent; text: "Reveal"
                            color: tokens.text; font.pointSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("file:///tmp/noctalia-vpn-backend.log")
                    }
                }
            }
        }
    }

    // Generic settings row
    component SettingsRow: Rectangle {
        id: srRoot
        property string label: ""
        property string hint: ""
        property Item control: null
        property bool danger: false

        Layout.fillWidth: true
        implicitHeight: rowCol.implicitHeight + 24
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: tokens.borderSoft
        }

        RowLayout {
            id: rowCol
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                NText {
                    text: srRoot.label
                    color: srRoot.danger ? tokens.danger : tokens.text
                    font.pointSize: 11
                    font.weight: Font.Medium
                }
                NText {
                    visible: srRoot.hint.length > 0
                    text: srRoot.hint
                    color: tokens.muted
                    font.pointSize: 10
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }
            }

            Item {
                Layout.preferredWidth: srRoot.control ? srRoot.control.implicitWidth : 0
                Layout.preferredHeight: srRoot.control ? srRoot.control.implicitHeight : 0
                children: srRoot.control ? [srRoot.control] : []
            }
        }
    }

    // ── Local state used by Settings rules pane ─────────────────────────────
    property string ruleType: "force-proxy"
    property string currentProto: "vless"

    // ──────────────────────────────────────────────────────────────────────
    // JS helpers
    // ──────────────────────────────────────────────────────────────────────

    function heroIconName() {
        if (!root.main) return "shield-off"
        if (root.main.running && root.main.statusLevel === "error") return "alert-triangle"
        if (root.main.running && root.main.statusLevel === "degraded") return "alert-circle"
        if (root.main.running) return "shield-check"
        return "shield-off"
    }
    function heroIconColor() {
        if (!root.main) return tokens.muted
        if (!root.main.running) return tokens.muted
        if (root.main.statusLevel === "error" || root.main.statusLevel === "failed") return tokens.danger
        if (root.main.statusLevel === "degraded") return tokens.pingMid
        return tokens.success
    }
    function heroAccent(a) {
        const c = heroIconColor()
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    function heroTitle() {
        if (!root.main) return "Connecting…"
        if (!root.main.bridgeReady) return "Connecting backend…"
        if (root.main.running) {
            const s = root.main.activeServer()
            return s ? "Connected" : "Connected"
        }
        return "Disconnected"
    }
    function heroSubtitle() {
        if (!root.main || !root.main.running) return ""
        const s = root.main.activeServer()
        return s ? (s.name || "") : ""
    }
    function heroLine2() {
        if (!root.main) return ""
        if (!root.main.running) {
            const s = root.main.activeServer()
            if (s) return "Will connect via: " + (s.name || "selected server")
            if (root.main.statusMessage) return root.main.statusMessage
            return "Select a server to connect."
        }
        const s = root.main.activeServer()
        if (!s) return "Active"
        const addr = (s.address || s.host || "?") + (s.port ? (":" + s.port) : "")
        const mode = root.main.mode === "global" ? "Global" : "Rules"
        const via  = root.main.proxyMode === "tun" ? "VPN (TUN)" : "System proxy"
        return "IP " + addr + "  ·  " + mode + " · " + via
    }

    function bridgeStatusText() {
        if (!root.main) return "idle"
        if (!root.main.bridgeReady) return "starting backend…"
        if (root.main.statusLevel === "error" || root.main.statusLevel === "failed")
            return root.main.statusReason || "backend error"
        if (root.main.busy) return "talking to backend…"
        return root.main.running ? "connected" : "ready"
    }

    function statValue(key) {
        if (!root.main) return "—"
        if (root.testRunning) return "…"
        if (key === "ping") {
            const ms = root.testPingMs >= 0 ? root.testPingMs : root.main.healthLatencyMs
            return ms >= 0 ? ("" + ms) : "—"
        }
        if (key === "jitter") {
            const j = root.testJitterMs >= 0 ? root.testJitterMs : root.main.healthJitterMs
            return j >= 0 ? ("" + j) : "—"
        }
        if (key === "down") {
            const v = root.main.healthDownMbps
            return v >= 0 ? v.toFixed(v < 100 ? 1 : 0) : "—"
        }
        if (key === "up") {
            const v = root.main.healthUpMbps
            return v >= 0 ? v.toFixed(v < 100 ? 1 : 0) : "—"
        }
        return "—"
    }

    function protoLabelFor(s) {
        if (!s) return ""
        switch ((s.protocol || "").toLowerCase()) {
        case "ssh":         return "SSH"
        case "vless":       return "VLESS"
        case "vmess":       return "VMess"
        case "shadowsocks": return "SS"
        case "socks5":      return "SOCKS5"
        }
        return (s.protocol || "").toUpperCase()
    }
    function protoDisplayLabel(p) {
        switch (p) {
        case "shadowsocks": return "SS"
        case "socks5":      return "SOCKS5"
        default:            return p.toUpperCase()
        }
    }
    function protoEngine(p) {
        switch (p) {
        case "ssh":         return "openssh"
        case "shadowsocks": return "shadowsocks"
        default:            return "sing-box"
        }
    }
    function protoBgFor(p) {
        const c = protoFgFor(p)
        return Qt.rgba(c.r, c.g, c.b, 0.14)
    }
    function protoBorderFor(p) {
        const c = protoFgFor(p)
        return Qt.rgba(c.r, c.g, c.b, 0.28)
    }
    function protoFgFor(p) {
        switch ((p || "").toUpperCase()) {
        case "SSH":    return Qt.rgba(0.6, 0.72, 0.82, 1)
        case "VLESS":  return tokens.accent
        case "SS":     return Qt.rgba(0.85, 0.6, 0.4, 1)
        case "VMESS":  return Qt.rgba(0.76, 0.55, 0.85, 1)
        case "SOCKS5": return Qt.rgba(0.85, 0.6, 0.4, 1)
        }
        return tokens.textDim
    }

    function serverEndpoint(s) {
        if (!s) return ""
        const addr = s.address || s.host || "?"
        const port = s.port ? (":" + s.port) : ""
        return addr + port
    }

    function filteredServers() {
        if (!root.main) return []
        return (root.main.servers || []).slice()
    }

    function subSummary(s) {
        if (!s) return ""
        const n = s.server_count || 0
        if (!s.last_updated) return "Never updated · " + n + " servers"
        const d = new Date(s.last_updated * 1000)
        return "Updated " + Qt.formatDateTime(d, "yyyy-MM-dd hh:mm") + "  ·  " + n + " servers"
    }

    function ruleTypeLabel(t) {
        if (t === "force-proxy") return "PROXY"
        if (t === "direct") return "DIRECT"
        if (t === "block") return "BLOCK"
        return t.toUpperCase()
    }
    function ruleTypeColor(t) {
        if (t === "force-proxy") return tokens.accent
        if (t === "direct") return tokens.success
        if (t === "block") return tokens.danger
        return tokens.textDim
    }

    // ── Modal open/close helpers ───────────────────────────────────────────
    function openSettings(tab) {
        root.settingsTab = tab || "rules"
        root.settingsOpen = true
    }
    function closeSettings() { root.settingsOpen = false }

    function openServerEditor(serverOrNull) {
        if (serverOrNull) {
            // Deep-clone so edits don't mutate the live model
            const copy = JSON.parse(JSON.stringify(serverOrNull))
            currentProto = (copy.protocol || "vless").toLowerCase()
            serverEditorPayload = copy
        } else {
            currentProto = "vless"
            serverEditorPayload = {
                protocol: "vless",
                name: "",
                address: "",
                port: 443,
                uuid: "",
                transport: "tcp"
            }
        }
        root.serverEditorOpen = true
    }
    function closeServerEditor() { root.serverEditorOpen = false }

    function seGet(key) {
        return (serverEditorPayload && serverEditorPayload[key] !== undefined)
            ? serverEditorPayload[key]
            : ""
    }
    function seSet(key, value) {
        // Single-key write that triggers a payloadChanged signal
        const next = Object.assign({}, serverEditorPayload)
        next[key] = value
        serverEditorPayload = next
    }
    function hostFieldKey() {
        return (currentProto === "ssh" || currentProto === "socks5") ? "host" : "address"
    }

    function switchProtocol(p) {
        currentProto = p
        const cur = Object.assign({}, serverEditorPayload)
        cur.protocol = p
        // sensible defaults per protocol
        if (p === "ssh") {
            if (!cur.port) cur.port = 22
            if (!cur.user) cur.user = "root"
        } else if (p === "socks5") {
            if (!cur.port) cur.port = 1080
        } else if (p === "vless" || p === "vmess") {
            if (!cur.port) cur.port = 443
            if (!cur.transport) cur.transport = "tcp"
        } else if (p === "shadowsocks") {
            if (!cur.port) cur.port = 8388
            if (!cur.method) cur.method = "aes-256-gcm"
        }
        serverEditorPayload = cur
    }

    function saveServerEditor() {
        if (!root.main) return
        const p = Object.assign({}, serverEditorPayload)
        // sanitize port
        if (typeof p.port === "string") p.port = parseInt(p.port, 10) || 0
        if (!p.protocol) p.protocol = currentProto
        if (p.id) {
            root.main.updateServer(p, function(err) { if (!err) root.closeServerEditor() })
        } else {
            root.main.addServer(p, function(err) { if (!err) root.closeServerEditor() })
        }
    }

    function testEditorConnection() {
        if (!root.main) return
        const p = serverEditorPayload || {}
        const host = p.address || p.host
        const port = parseInt(p.port, 10) || 0
        if (!host || !port) {
            root.main.toastWarn("Host and port required")
            return
        }
        // Use a transient ID by pinging a saved server only — for new entries
        // we fall back to a TCP probe via the bridge's GetHealth path on save.
        if (p.id) {
            root.main.pingServer(p.id, function(ms) {
                if (typeof ToastService !== "undefined")
                    ToastService.showNotice(ms > 0 ? ("Ping " + ms + " ms") : "Server unreachable")
            })
        } else {
            if (typeof ToastService !== "undefined")
                ToastService.showNotice("Save first to enable a live test")
        }
    }

    // ── Speed test (light-weight: 3-sample TCP ping via PingServer) ─────────
    Timer {
        id: speedTestTimer
        interval: 350
        repeat: false
        onTriggered: doSpeedTestSample()
    }

    function toggleSpeedTest() {
        if (testRunning) {
            testRunning = false
            return
        }
        if (!root.main || !root.main.activeServerId) {
            root.main && root.main.toastWarn("No active server")
            return
        }
        testRunning = true
        testPingMs = -1
        testJitterMs = -1
        testTakenSamples = []
        speedTestTimer.start()
        root.main.runSpeedTest(function(err) {
            if (err && root.main) root.main.toastWarn("Speed test failed: " + err)
            testTakenAt = "just now"
            testRunning = false
        })
    }
    function doSpeedTestSample() {
        if (!testRunning) return
        if (!root.main || !root.main.activeServerId) return
        root.main.pingServer(root.main.activeServerId, function(ms) {
            if (!testRunning) return
            if (ms > 0) {
                const samples = testTakenSamples.slice()
                samples.push(ms)
                testTakenSamples = samples
                testPingMs = Math.round(avg(samples))
                if (samples.length >= 2) testJitterMs = Math.round(jitter(samples))
            }
            if (testTakenSamples.length < 4) speedTestTimer.start()
        })
    }
    function avg(arr) {
        let s = 0
        for (let i = 0; i < arr.length; ++i) s += arr[i]
        return arr.length ? s / arr.length : 0
    }
    function jitter(arr) {
        if (arr.length < 2) return 0
        let d = 0
        for (let i = 1; i < arr.length; ++i) d += Math.abs(arr[i] - arr[i - 1])
        return d / (arr.length - 1)
    }

    function importShareLinkFromClipboard() {
        // Use a transient backend helper: parsers live in the backend, but we
        // don't have a dedicated DBus method to parse one link. Encourage user
        // to use Subscriptions instead — paste a tiny single-line "URL" of
        // their link by base64-encoding it themselves. Here we just toast.
        if (typeof ToastService !== "undefined")
            ToastService.showNotice("Paste share links via Settings → Subs (base64 or plain list)")
    }
}
