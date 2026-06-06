import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Services.System
import qs.Widgets
// BatteryService import kept for potential future use

Item {
    id: root
    property var pluginApi: null

    readonly property var main: pluginApi?.mainInstance
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth:  360 * Style.uiScaleRatio
    property real contentPreferredHeight: mainCol.implicitHeight + Style.marginL * 4

    anchors.fill: parent

    // Register with SystemStatService so it runs while panel is open
    Component.onCompleted: SystemStatService.registerComponent("auto-cpufreq-panel")
    Component.onDestruction: SystemStatService.unregisterComponent("auto-cpufreq-panel")

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: mainCol
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            // ── Header ────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                RowLayout {
                    id: headerRow
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginM

                    NIcon {
                        icon: "cpu"
                        pointSize: Style.fontSizeXL
                        color: root.main?.daemonRunning ? Color.mPrimary : Color.mError
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        NText {
                            text: "auto-cpufreq"
                            pointSize: Style.fontSizeM
                            font.weight: Font.Bold
                            color: Color.mOnSurface
                        }
                        NText {
                            text: root.main?.daemonRunning
                                ? pluginApi?.tr("panel.daemon-running")
                                : pluginApi?.tr("panel.daemon-stopped")
                            pointSize: Style.fontSizeXS
                            color: root.main?.daemonRunning ? Color.mOnSurfaceVariant : Color.mError
                        }
                    }

                    NIconButton {
                        icon: "refresh"
                        onClicked: root.main?.refreshAll()
                    }
                }
            }

            // ── CPU stats (SystemStatService) ─────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: statsRow.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                RowLayout {
                    id: statsRow
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginL

                    StatCell {
                        icon: "activity"
                        label: pluginApi?.tr("panel.cpu-usage")
                        value: Math.round(SystemStatService.cpuUsage) + "%"
                        valueColor: {
                            let u = SystemStatService.cpuUsage
                            if (u >= 90) return Color.mError
                            if (u >= 70) return Color.mTertiary
                            return Color.mOnSurface
                        }
                    }

                    StatCell {
                        icon: "cpu"
                        label: pluginApi?.tr("panel.cpu-freq")
                        value: SystemStatService.cpuFreq || "—"
                    }

                    StatCell {
                        icon: "thermometer"
                        label: pluginApi?.tr("panel.cpu-temp")
                        value: SystemStatService.cpuTemp > 0
                            ? Math.round(SystemStatService.cpuTemp) + "°C"
                            : "—"
                        valueColor: {
                            let t = SystemStatService.cpuTemp
                            if (t >= 90) return Color.mError
                            if (t >= 75) return Color.mTertiary
                            return Color.mOnSurface
                        }
                    }
                }
            }

            // ── Battery (sysfs via BarWidget mainInstance) ────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: batRow.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                visible: (root.main?.batCapacity ?? -1) >= 0

                RowLayout {
                    id: batRow
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginM

                    NIcon {
                        icon: {
                            let s = root.main?.batStatus ?? ""
                            let c = root.main?.batCapacity ?? 0
                            if (s === "Charging") return "battery-charging"
                            if (c >= 80) return "battery-4"
                            if (c >= 60) return "battery-3"
                            if (c >= 40) return "battery-2"
                            if (c >= 20) return "battery-1"
                            return "battery"
                        }
                        color: {
                            let s = root.main?.batStatus ?? ""
                            let c = root.main?.batCapacity ?? 100
                            if (s === "Charging") return Color.mTertiary
                            if (c <= 20) return Color.mError
                            return Color.mOnSurface
                        }
                        pointSize: Style.fontSizeXL
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        NText {
                            text: (root.main?.batCapacity ?? 0) + "%  ·  " + (root.main?.batStatus ?? "—")
                            pointSize: Style.fontSizeM
                            font.weight: Font.Bold
                            color: Color.mOnSurface
                        }

                        NText {
                            visible: (root.main?.batWatts ?? 0) > 0
                            text: {
                                let s = root.main?.batStatus ?? ""
                                let w = root.main?.batWatts ?? 0
                                return (s === "Charging" ? "+" : "−") + w.toFixed(1) + " W"
                            }
                            pointSize: Style.fontSizeXS
                            color: Color.mOnSurfaceVariant
                        }
                    }
                }
            }

            // ── Governor & turbo ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: govCol.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                ColumnLayout {
                    id: govCol
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginS

                    NText {
                        text: pluginApi?.tr("panel.section-governor")
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.weight: Font.Medium
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIcon {
                            icon: {
                                let g = root.main?.governor ?? ""
                                if (g === "performance") return "gauge"
                                if (g === "powersave")   return "leaf"
                                return "cpu"
                            }
                            color: {
                                let g = root.main?.governor ?? ""
                                if (g === "performance") return Color.mTertiary
                                if (g === "powersave")   return Color.mPrimary
                                return Color.mOnSurface
                            }
                        }

                        NText {
                            text: root.main?.governor ?? "—"
                            pointSize: Style.fontSizeM
                            font.weight: Font.Bold
                            font.family: Settings.data?.ui?.fontFixed ?? "monospace"
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NText {
                            visible: (root.main?.forceOverride ?? "default") !== "default"
                            text: pluginApi?.tr("panel.forced")
                            pointSize: Style.fontSizeXS
                            color: Color.mTertiary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIcon {
                            icon: "bolt"
                            color: (root.main?.turboState ?? "") === "on"
                                ? Color.mTertiary : Color.mOnSurfaceVariant
                        }

                        NText {
                            text: pluginApi?.tr("panel.turbo") + ": " + (root.main?.turboState ?? "—")
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // ── pkexec error banner ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorRow.implicitHeight + Style.marginM * 2
                color: Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.15)
                radius: Style.radiusM
                visible: root.main?.pkexecFailed ?? false

                RowLayout {
                    id: errorRow
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginM
                    NIcon { icon: "alert-triangle"; color: Color.mError; pointSize: Style.fontSizeM }
                    NText {
                        text: pluginApi?.tr("panel.pkexec-error")
                        pointSize: Style.fontSizeXS
                        color: Color.mError
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ── Force override ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: forceCol.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                opacity: (root.main?.daemonRunning ?? false) ? 1.0 : 0.4

                ColumnLayout {
                    id: forceCol
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginS

                    NText {
                        text: pluginApi?.tr("panel.section-force")
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44 * Style.uiScaleRatio
                        color: Color.mSurface
                        radius: Style.radiusS
                        border.color: Color.mOutline
                        border.width: 1
                        clip: true

                        Row {
                            anchors.fill: parent

                            SegItem {
                                width: parent.width / 3; height: parent.height
                                icon: "leaf"; label: pluginApi?.tr("panel.powersave")
                                active: (root.main?.forceOverride ?? "") === "powersave"
                                enabled: root.main?.daemonRunning ?? false
                                showDivider: true
                                onClicked: root.main?.setForce("powersave")
                            }
                            SegItem {
                                width: parent.width / 3; height: parent.height
                                icon: "scale"; label: pluginApi?.tr("panel.auto")
                                active: (root.main?.forceOverride ?? "default") === "default"
                                enabled: root.main?.daemonRunning ?? false
                                showDivider: true
                                onClicked: root.main?.setForce("reset")
                            }
                            SegItem {
                                width: parent.width / 3; height: parent.height
                                icon: "gauge"; label: pluginApi?.tr("panel.performance")
                                active: (root.main?.forceOverride ?? "") === "performance"
                                enabled: root.main?.daemonRunning ?? false
                                showDivider: false
                                onClicked: root.main?.setForce("performance")
                            }
                        }
                    }
                }
            }

            // ── Turbo boost ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: turboCol.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                property bool turboAvailable: (root.main?.turboState ?? "n/a") !== "n/a"
                opacity: ((root.main?.daemonRunning ?? false) && turboAvailable) ? 1.0 : 0.4

                ColumnLayout {
                    id: turboCol
                    anchors { fill: parent; margins: Style.marginM }
                    spacing: Style.marginS

                    NText {
                        text: pluginApi?.tr("panel.section-turbo")
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 44 * Style.uiScaleRatio
                        color: Color.mSurface
                        radius: Style.radiusS
                        border.color: Color.mOutline
                        border.width: 1
                        clip: true

                        Row {
                            anchors.fill: parent
                            property bool avail: (root.main?.daemonRunning ?? false) && (root.main?.turboState ?? "n/a") !== "n/a"

                            SegItem {
                                width: parent.width / 3; height: parent.height
                                icon: "bolt-off"; label: pluginApi?.tr("panel.turbo-never")
                                active: (root.main?.turboOverride ?? "") === "never"
                                enabled: parent.avail; showDivider: true
                                onClicked: root.main?.setTurbo("never")
                            }
                            SegItem {
                                width: parent.width / 3; height: parent.height
                                icon: "cpu"; label: pluginApi?.tr("panel.turbo-auto")
                                active: (root.main?.turboOverride ?? "auto") === "auto"
                                enabled: parent.avail; showDivider: true
                                onClicked: root.main?.setTurbo("auto")
                            }
                            SegItem {
                                width: parent.width / 3; height: parent.height
                                icon: "bolt"; label: pluginApi?.tr("panel.turbo-always")
                                active: (root.main?.turboOverride ?? "") === "always"
                                enabled: parent.avail; showDivider: false
                                onClicked: root.main?.setTurbo("always")
                            }
                        }
                    }
                }
            }
        }
    }

    component StatCell: ColumnLayout {
        id: statCell
        property string icon: ""
        property string label: ""
        property string value: "—"
        property color  valueColor: Color.mOnSurface
        spacing: 2
        Layout.fillWidth: true
        NIcon {
            icon: statCell.icon; pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant; Layout.alignment: Qt.AlignHCenter
        }
        NText {
            text: statCell.value; pointSize: Style.fontSizeM; font.weight: Font.Bold
            color: statCell.valueColor; Layout.alignment: Qt.AlignHCenter
        }
        NText {
            text: statCell.label; pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant; Layout.alignment: Qt.AlignHCenter
        }
    }

    component SegItem: Item {
        id: segItem
        property string icon:        ""
        property string label:       ""
        property bool   active:      false
        property bool   enabled:     true
        property bool   showDivider: false
        signal clicked()

        Rectangle {
            anchors { fill: parent; margins: 3 }
            radius: Style.radiusS
            color: segItem.active ? Color.mPrimary : "transparent"
        }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 1; height: parent.height * 0.5
            color: Color.mOutline; opacity: 0.5
            visible: segItem.showDivider
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1
            NIcon {
                icon: segItem.icon; pointSize: Style.fontSizeS
                color: segItem.active ? Color.mOnPrimary : Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
            }
            NText {
                text: segItem.label; pointSize: Style.fontSizeXS
                color: segItem.active ? Color.mOnPrimary : Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
            }
        }
        MouseArea {
            anchors.fill: parent; enabled: segItem.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: segItem.clicked()
        }
    }
}
