import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var service: pluginApi?.mainInstance?.service
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: panelContent.implicitHeight + Style.marginL * 2
    readonly property bool allowAttach: true
    anchors.fill: parent

    property string batteryModelName: ""

    FileView {
        id: modelNameView
        path: `${pluginApi?.pluginSettings?.batteryDevice || service.batteries[0]}/model_name`
        printErrors: false

        onLoaded: {
            Logger.d("BatteryThreshold", "device: " + modelNameView.path);
            root.batteryModelName = text().trim();
        }
    }

    function writeThreshold(value) {
        if (!service.isWritable)
            return;
        Logger.d("BatteryThreshold", "thresholdFile: " + service.thresholdFile);
        thresholdWriter.command = ["sh", "-c", `echo ${value} > ${service.thresholdFile}`];
        thresholdWriter.running = true;
    }

    Process {
        id: thresholdWriter
        running: false

        onExited: function (exitCode) {
            if (exitCode === 0) {
                service.refresh();
                if (pluginApi) {
                    pluginApi.pluginSettings.chargeThreshold = Math.round(thresholdSlider.value);
                    pluginApi.saveSettings();
                }
            }
        }
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
                    text: "Battery Threshold"
                    pointSize: Style.fontSizeL
                    font.weight: Font.DemiBold
                    color: Color.mOnSurface
                }

                NText {
                    visible: !service.isAvailable || root.batteryModelName !== ""
                    text: !service.isAvailable ? "Not available on this system" : root.batteryModelName
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutline
                opacity: 0.3
                visible: service.isAvailable
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: service.isAvailable

                RowLayout {
                    Layout.fillWidth: true

                    NText {
                        text: "Battery Threshold"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NText {
                        text: service.currentThreshold + "%"
                        pointSize: Style.fontSizeL
                        font.weight: Font.Bold
                        color: Color.mPrimary
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: "40%"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }

                    NSlider {
                        id: thresholdSlider
                        Layout.fillWidth: true
                        from: 40
                        to: 100
                        stepSize: 5
                        value: service.currentThreshold
                        enabled: service.isWritable
                        onValueChanged: root.writeThreshold(Math.round(value))
                    }

                    NText {
                        text: "100%"
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }
                }

                NText {
                    Layout.fillWidth: true
                    text: service.isWritable ? "Drag slider to adjust limit" : "Read-only: Install udev rule for write access"
                    pointSize: Style.fontSizeXS
                    color: service.isWritable ? Color.mOnSurfaceVariant : Color.mTertiary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
