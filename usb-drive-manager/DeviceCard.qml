import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    // ===== PROPERTIES =====
    property var device: null
    property var pluginApi: null
    property var mainInstance: null

    // Signals
    signal mountRequested(string devicePath, string deviceLabel)
    signal unmountRequested(string devicePath, string deviceLabel)
    signal ejectRequested(string devicePath, string parentPath, string deviceLabel)
    signal openRequested(string mountpoint)
    signal copyPathRequested(string mountpoint)

    // ===== COMPUTED =====
    readonly property string displayLabel: {
        if (!device) return ""
        if (device.label && device.label !== device.name) return device.label
        if (device.model) return device.model
        return device.name
    }

    readonly property string displaySubtitle: {
        if (!device) return ""
        const parts = []
        if (device.size) parts.push(device.size)
        if (device.fstype) parts.push(device.fstype.toUpperCase())
        if (device.vendor && device.vendor !== device.model) parts.push(device.vendor)
        return parts.join(" · ")
    }

    // ===== APPEARANCE =====
    color: Color.mSurface
    radius: Style.radiusM
    implicitHeight: cardLayout.implicitHeight + Style.marginM * 2

    ColumnLayout {
        id: cardLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Style.marginM
        }
        spacing: Style.marginS

        // ── Header Row ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            // USB icon
            NIcon {
                icon: "usb"
                pointSize: Style.fontSizeL
                color: device?.isMounted ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            // Label + subtitle
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXS

                NText {
                    Layout.fillWidth: true
                    text: root.displayLabel
                    pointSize: Style.fontSizeM
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                }

                NText {
                    Layout.fillWidth: true
                    text: root.displaySubtitle
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            // Mounted status badge
            Rectangle {
                visible: device?.isMounted ?? false
                width: statusLabel.implicitWidth + Style.marginS * 2
                height: statusLabel.implicitHeight + 4
                radius: height / 2
                color: Color.mPrimaryContainer

                NText {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: pluginApi?.tr("device.mounted")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnPrimaryContainer
                    font.weight: Font.Medium
                }
            }
        }

        // ── Mountpoint path ─────────────────────────────────────────────────
        NText {
            visible: device?.isMounted ?? false
            Layout.fillWidth: true
            text: device?.mountpoint || ""
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideMiddle
            font.family: "monospace"
        }

        // ── Usage bar ────────────────────────────────────────────────────────
        ColumnLayout {
            visible: (device?.isMounted ?? false) && (device?.usedPercent ?? 0) > 0
            Layout.fillWidth: true
            spacing: Style.marginXS

            // Bar
            Rectangle {
                Layout.fillWidth: true
                height: Style.marginXS
                radius: height / 2
                color: Color.mOutlineVariant

                Rectangle {
                    width: parent.width * Math.min((device?.usedPercent ?? 0) / 100, 1)
                    height: parent.height
                    radius: parent.radius
                    color: (device?.usedPercent ?? 0) > 90 ? Color.mError
                         : (device?.usedPercent ?? 0) > 75 ? Color.mWarning
                         : Color.mPrimary

                    Behavior on width {
                        NumberAnimation { duration: Style.animationNormal }
                    }
                }
            }

            // Usage text
            RowLayout {
                Layout.fillWidth: true

                NText {
                    text: pluginApi?.tr("device.used", { size: device?.usedSize ?? "" })
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                }

                Item { Layout.fillWidth: true }

                NText {
                    text: pluginApi?.tr("device.free", { size: device?.freeSize ?? "" })
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                }
            }
        }

        // ── Action Buttons ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginXS

            // Open in file browser (only when mounted)
            NButton {
                visible: device?.isMounted ?? false
                Layout.fillWidth: true
                text: pluginApi?.tr("device.action-open")
                icon: "folder-open"
                onClicked: root.openRequested(device.mountpoint)
            }

            // Copy path (only when mounted)
            NIconButton {
                visible: device?.isMounted ?? false
                icon: "copy"
                tooltipText: pluginApi?.tr("device.action-copy-path")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: Color.mSurfaceVariant
                colorFg: Color.mOnSurfaceVariant
                colorBgHover: Color.mHover
                colorFgHover: Color.mOnHover
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.copyPathRequested(device.mountpoint)
            }

            // Mount (only when not mounted)
            NButton {
                visible: !(device?.isMounted ?? false)
                Layout.fillWidth: true
                text: pluginApi?.tr("device.action-mount")
                icon: "plug-connected"
                onClicked: root.mountRequested(device.path, root.displayLabel)
            }

            // Unmount
            NIconButton {
                visible: device?.isMounted ?? false
                icon: "plug-connected-x"
                tooltipText: pluginApi?.tr("device.action-unmount")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: Color.mSurfaceVariant
                colorFg: Color.mOnSurfaceVariant
                colorBgHover: Color.mHover
                colorFgHover: Color.mOnHover
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.unmountRequested(device.path, root.displayLabel)
            }

            // Eject (safe remove)
            NIconButton {
                icon: "player-eject"
                tooltipText: pluginApi?.tr("device.action-eject")
                baseSize: Style.baseWidgetSize * 0.8
                colorBg: Color.mSurfaceVariant
                colorFg: Color.mOnSurfaceVariant
                colorBgHover: Color.mHover
                colorFgHover: Color.mOnHover
                colorBorder: "transparent"
                colorBorderHover: "transparent"
                onClicked: root.ejectRequested(device.path, device.parentPath, root.displayLabel)
            }
        }
    }
}
