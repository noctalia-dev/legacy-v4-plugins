import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Info-only panel: state, countdown, today's windows in local/UTC/Beijing time,
// and a drift warning. All state and strings come from Main.qml.
Item {
    id: root
    property var pluginApi: null

    readonly property var main: pluginApi?.mainInstance
    readonly property color driftColor: (pluginApi?.pluginSettings?.driftColor ?? pluginApi?.manifest?.metadata?.defaultSettings?.driftColor) ?? "#fbbf24"

    // Required for background rendering
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: panelColumn.implicitHeight + Style.marginL * 2
    readonly property bool allowAttach: true

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: panelColumn
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginS

            NText {
                Layout.fillWidth: true
                text: root.main ? root.main.panelStateText : ""
                color: (root.main && root.main.drift) ? root.driftColor : Color.mPrimary
            }
            NText {
                Layout.fillWidth: true
                text: root.main ? root.main.countdownLabel + "  " + root.main.countdownHMS : ""
            }
            NDivider {
                Layout.fillWidth: true
            }
            NText {
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
                text: root.main ? root.main.localLine : ""
            }
            NText {
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
                text: root.main ? root.main.utcLine : ""
            }
            NText {
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
                text: root.main ? root.main.beijingLine : ""
            }
            NText {
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
                text: root.main ? root.main.costText : ""
            }
            NText {
                visible: root.main ? root.main.checkedAtMs > 0 : false
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
                text: root.main ? root.main.checkedText : ""
            }
            NText {
                visible: root.main ? root.main.drift : false
                Layout.fillWidth: true
                pointSize: Style.fontSizeS
                text: root.main ? root.main.driftText : ""
                color: root.driftColor
            }
        }
    }
}
