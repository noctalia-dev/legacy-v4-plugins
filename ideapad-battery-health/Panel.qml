import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: panelContent.implicitHeight + Style.marginL * 2
    readonly property bool allowAttach: true
    anchors.fill: parent

    readonly property var service: pluginApi?.mainInstance?.service

    property string batteryModelName: ""

    FileView {
        id: modelNameView
        path: service?.batteryDir ? `${service.batteryDir}/model_name` : ""
        printErrors: false

        onLoaded: {
            root.batteryModelName = text().trim()
        }
    }

    function writePreservation(value) {
        if (!service?.isWritable)
            return
        service.setPreservation(value)
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: panelContent
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                NText {
                    text: "Battery Preservation"
                    pointSize: Style.fontSizeL
                    font.weight: Font.DemiBold
                    color: Color.mOnSurface
                }

                NText {
                    visible: !service?.isAvailable
                             || root.batteryModelName !== ""
                    text: !service?.isAvailable ? "Not available on this system" : root.batteryModelName
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutline
                opacity: 0.3
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: service?.isAvailable

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: "Full Capacity"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }

                    NToggle {
                        id: preservationToggle
                        Layout.fillWidth: true
                        enabled: service?.isWritable ?? false
                        checked: (service?.currentPreservation ?? 0) !== 0
                        onToggled: root.writePreservation(checked ? 1 : 0)
                    }

                    NText {
                        text: "Battery Preservation"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }
                }
            }
        }
    }
}
