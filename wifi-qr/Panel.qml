import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 360 * Style.uiScaleRatio
    property real contentPreferredHeight: 480 * Style.uiScaleRatio

    property var qrRows: []
    property int qrSize: 0
    property string errorText: ""
    property bool loading: false
    property string ssid: ""

    anchors.fill: parent

    Process {
        id: qrProcess
        running: false
        command: ["bash", pluginApi.pluginDir + "/network-qr.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0)
                root.loading = false

                let matrixStart = 0
                if (lines.length > 0 && lines[0].startsWith("SSID:")) {
                    root.ssid = lines[0].slice(5)
                    matrixStart = 1
                } else {
                    root.ssid = ""
                }

                const matrix = lines.slice(matrixStart)
                if (matrix.length === 0) {
                    root.errorText = pluginApi?.tr("panel.error_no_connection") || "No Wi-Fi connection detected"
                    root.qrRows = []
                    root.qrSize = 0
                } else {
                    root.qrRows = matrix
                    root.qrSize = matrix.length
                    root.errorText = ""
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim()
                if (err.length > 0) {
                    root.errorText = err
                    root.qrRows = []
                    root.qrSize = 0
                    root.ssid = ""
                }
                root.loading = false
            }
        }

        onRunningChanged: if (running) root.loading = true
    }

    function refresh() {
        qrProcess.running = false
        Qt.callLater(() => qrProcess.running = true)
    }

    Component.onCompleted: refresh()

    onPluginApiChanged: {
        if (pluginApi) {
            refresh()
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginL

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                    text: pluginApi?.tr("panel.title") || "Wi-Fi QR"
                    pointSize: Style.fontSizeL
                    font.weight: Font.Bold
                    color: Color.mOnSurface
                }

                Item { Layout.fillWidth: true }

                NText {
                    visible: root.loading
                    text: "⟳"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeL

                    RotationAnimator on rotation {
                        running: root.loading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                    }
                }
            }

            // Error banner
            Rectangle {
                visible: root.errorText !== "" && !root.loading
                Layout.fillWidth: true
                implicitHeight: errorLabel.implicitHeight + Style.marginL * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                NText {
                    id: errorLabel
                    anchors { fill: parent; margins: Style.marginL }
                    text: root.errorText
                    color: Color.mOnSurface
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Empty state
            Item {
                visible: root.qrSize === 0 && root.errorText === "" && !root.loading
                Layout.fillWidth: true
                Layout.fillHeight: true

                NText {
                    anchors.centerIn: parent
                    text: pluginApi?.tr("panel.empty_state") || "No QR data available"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeM
                }
            }

            // QR Code card
            Rectangle {
                id: qrCard
                visible: root.qrSize > 0 && !root.loading
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginM
                Layout.bottomMargin: Style.marginM

                readonly property int maxDim: 280 * Style.uiScaleRatio
                readonly property int moduleSize: root.qrSize > 0
                    ? Math.max(3, Math.floor(maxDim / root.qrSize))
                    : 0
                readonly property int qrDim: moduleSize * root.qrSize

                width: qrDim + Style.marginL * 2
                height: qrDim + Style.marginL * 2
                color: "white"
                radius: Style.radiusM

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.08)
                    radius: parent.radius
                }

                opacity: visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                Grid {
                    anchors.centerIn: parent
                    columns: root.qrSize
                    spacing: 0

                    Repeater {
                        model: root.qrSize * root.qrSize

                        Rectangle {
                            required property int index

                            readonly property int row: Math.floor(index / root.qrSize)
                            readonly property int col: index % root.qrSize
                            readonly property string rowData: root.qrRows[row] ?? ""
                            readonly property bool isDark: col < rowData.length
                                && rowData.charAt(col) === "1"

                            width: qrCard.moduleSize
                            height: qrCard.moduleSize
                            color: isDark ? "#111111" : "white"
                        }
                    }
                }
            }

            // Network name
            NText {
                visible: root.ssid !== "" && !root.loading
                text: (pluginApi?.tr("panel.connected") || "Connected: ") + root.ssid
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                Layout.alignment: Qt.AlignHCenter
            }

            // Caption
            NText {
                visible: root.qrSize > 0 && !root.loading
                text: pluginApi?.tr("panel.scan_to_connect") || "Scan to connect"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }

            NButton {
                text: pluginApi?.tr("panel.refresh") || "Refresh"
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Style.marginS
                onClicked: root.refresh()
            }
        }
    }
}
