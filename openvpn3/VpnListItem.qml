import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

NBox {
    id: root

    property string name: ""
    property string configPath: ""
    property string sessionPath: ""
    property bool isConnected: false
    property bool isLoading: false
    property bool isPersistent: false
    property bool isPaused: false
    property var stats: null
    property var details: null
    property bool showDetails: false

    signal buttonClicked
    signal renameRequested(string configPath, string currentName)
    signal deleteRequested(string configPath)
    signal restartRequested(string sessionPath)
    signal showDetailsRequested(string configPath)

    property bool editing: false
    property bool confirmingDelete: false
    property string editName: name
    property bool hovered: false
    property var pluginApi: null

    Layout.fillWidth: true
    Layout.leftMargin: Style.marginXS
    Layout.rightMargin: Style.marginXS
    implicitHeight: Math.round(netColumn.implicitHeight + Style.marginXL)

    color: root.isConnected ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurface

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onContainsMouseChanged: root.hovered = containsMouse
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        id: netColumn
        width: parent.width - Style.marginXL
        x: Style.marginM
        y: Style.marginM
        spacing: Style.marginS

        // --- Main row ---
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
                Layout.alignment: Qt.AlignVCenter
                icon: root.isConnected ? (root.isPaused ? "shield-pause" : "shield-lock") : "shield"
                pointSize: Style.fontSizeXXL
                color: root.isConnected ? Color.mPrimary : Color.mOnSurface
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 0
                spacing: Style.marginXS

                NText {
                    visible: !root.editing
                    text: root.name
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightMedium
                    color: Color.mOnSurface
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                }

                NTextInput {
                    id: renameInput
                    visible: root.editing
                    Layout.fillWidth: true
                    text: root.editName
                    placeholderText: pluginApi?.tr("import.namePlaceholder")
                    onAccepted: root._confirmRename()
                }

                RowLayout {
                    Layout.alignment: Qt.AlignLeft
                    spacing: Style.marginXS

                    NText {
                        text: root.isConnected ? (root.isPaused ? pluginApi?.tr("status.paused") : pluginApi?.tr("status.connected")) : pluginApi?.tr("status.disconnected")
                        pointSize: Style.fontSizeXXS
                        color: root.isConnected ? Color.mPrimary : Color.mOnSurfaceVariant
                        horizontalAlignment: Text.AlignLeft
                    }

                    NIcon {
                        visible: !root.isConnected && !root.isPersistent
                        Layout.alignment: Qt.AlignVCenter
                        icon: "clock"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: TooltipService.show(parent, pluginApi?.tr("tooltip.temporary"))
                            onExited: TooltipService.hide()
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                spacing: Style.marginS

                // Hover action buttons
                NIconButton {
                    visible: root.isConnected && !root.editing && !root.confirmingDelete && root.hovered
                    icon: "refresh"
                    tooltipText: pluginApi?.tr("actions.restart")
                    baseSize: Style.baseWidgetSize * 0.7
                    onClicked: root.restartRequested(root.sessionPath)
                }

                NIconButton {
                    visible: !root.isConnected && !root.editing && !root.confirmingDelete && root.hovered
                    icon: "pencil"
                    tooltipText: pluginApi?.tr("actions.rename")
                    baseSize: Style.baseWidgetSize * 0.7
                    onClicked: {
                        root.editing = true
                        renameInput.text = root.name
                        renameInput.forceActiveFocus()
                    }
                }

                NIconButton {
                    visible: !root.isConnected && !root.editing && !root.confirmingDelete && root.hovered
                    icon: "trash"
                    tooltipText: pluginApi?.tr("actions.delete")
                    baseSize: Style.baseWidgetSize * 0.7
                    colorBg: Qt.alpha(Color.mError, 0.15)
                    onClicked: root.confirmingDelete = true
                }

                // Rename confirm/cancel
                NIconButton {
                    visible: root.editing
                    icon: "check"
                    tooltipText: pluginApi?.tr("actions.confirm")
                    baseSize: Style.baseWidgetSize * 0.7
                    colorBg: Qt.alpha(Color.mPrimary, 0.2)
                    onClicked: root._confirmRename()
                }

                NIconButton {
                    visible: root.editing
                    icon: "x"
                    tooltipText: pluginApi?.tr("actions.cancel")
                    baseSize: Style.baseWidgetSize * 0.7
                    onClicked: {
                        root.editing = false
                        renameInput.text = root.name
                    }
                }

                // Delete confirm/cancel
                NIconButton {
                    visible: root.confirmingDelete
                    icon: "trash"
                    tooltipText: pluginApi?.tr("actions.confirmDelete")
                    baseSize: Style.baseWidgetSize * 0.7
                    colorBg: Qt.alpha(Color.mError, 0.3)
                    colorFg: Color.mError
                    onClicked: {
                        root.confirmingDelete = false
                        root.deleteRequested(root.configPath)
                    }
                }

                NIconButton {
                    visible: root.confirmingDelete
                    icon: "x"
                    tooltipText: pluginApi?.tr("actions.cancel")
                    baseSize: Style.baseWidgetSize * 0.7
                    onClicked: root.confirmingDelete = false
                }

                // Disconnect button
                NButton {
                    visible: root.isConnected
                    text: pluginApi?.tr("actions.disconnect")
                    outlined: !hovered
                    fontSize: Style.fontSizeS
                    backgroundColor: Color.mError
                    onClicked: root.buttonClicked()
                }

                // Connect button — text stays, spinner overlays when loading
                NButton {
                    visible: !root.isConnected && !root.editing
                    text: pluginApi?.tr("actions.connect")
                    outlined: !hovered
                    fontSize: Style.fontSizeS
                    enabled: !root.isLoading
                    onClicked: root.buttonClicked()

                    NBusyIndicator {
                        anchors.centerIn: parent
                        visible: root.isLoading
                        running: visible
                        color: Color.mPrimary
                        size: Style.baseWidgetSize * 0.4
                    }
                }
            }
        }

        // --- Stats row (connected sessions only) ---
        RowLayout {
            visible: root.isConnected && root.stats !== null
            spacing: Style.marginM
            Layout.fillWidth: true
            Layout.leftMargin: Style.fontSizeXXL + Style.marginS // indent under title column

            NText {
                text: pluginApi?.tr("stats.download") + " " + (root.stats ? formatBytes(root.stats.bytesIn) : "0 B")
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignLeft
            }

            NText {
                text: pluginApi?.tr("stats.upload") + " " + (root.stats ? formatBytes(root.stats.bytesOut) : "0 B")
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignLeft
            }

            NText {
                text: pluginApi?.tr("stats.packets") + " " + (root.stats ? root.stats.packetsIn + "/" + root.stats.packetsOut : "0/0")
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignLeft
            }

            NText {
                visible: root.stats && root.stats.nReconnect > 0
                text: pluginApi?.tr("stats.reconnect") + " " + (root.stats ? root.stats.nReconnect : 0)
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignLeft
            }

            Item { Layout.fillWidth: true }
        }

        // --- Config details row (disconnected, double-click to expand) ---
        ColumnLayout {
            visible: root.showDetails && !root.isConnected && root.details !== null
            spacing: Style.marginXS
            Layout.fillWidth: true

            Repeater {
                model: [
                    { label: pluginApi?.tr("details.server"), value: root.details ? root.details.server : "" },
                    { label: pluginApi?.tr("details.port"), value: root.details ? root.details.port : "" },
                    { label: pluginApi?.tr("details.protocol"), value: root.details ? root.details.protocol : "" },
                    { label: pluginApi?.tr("details.cipher"), value: root.details ? root.details.cipher : "" },
                    { label: pluginApi?.tr("details.device"), value: root.details ? root.details.device : "" },
                    { label: pluginApi?.tr("details.username"), value: root.details ? root.details.username : "" }
                ]
                delegate: RowLayout {
                    Layout.fillWidth: true
                    NText {
                        text: modelData.label + ":"
                        pointSize: Style.fontSizeXXS
                        font.weight: Style.fontWeightMedium
                        color: Color.mOnSurfaceVariant
                        Layout.preferredWidth: 80
                    }
                    NText {
                        text: modelData.value
                        pointSize: Style.fontSizeXXS
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    function formatBytes(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB"
        return (bytes / 1073741824).toFixed(2) + " GB"
    }

    function _confirmRename() {
        const newName = renameInput.text.trim()
        if (newName !== "" && newName !== root.name) {
            root.renameRequested(root.configPath, newName)
        }
        root.editing = false
    }

    MouseArea {
        anchors.fill: parent
        visible: !root.isConnected && !root.editing && !root.confirmingDelete
        acceptedButtons: Qt.LeftButton
        onDoubleClicked: {
            root.showDetails = !root.showDetails
            if (root.showDetails) root.showDetailsRequested(root.configPath)
        }
        z: -1
    }
}