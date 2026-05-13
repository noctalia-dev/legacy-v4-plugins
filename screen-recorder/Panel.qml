import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance

    readonly property var geometryPlaceholder: panelContainer
    readonly property real panelButtonSize: 40 * Style.uiScaleRatio
    readonly property bool showRecordingTimer: mainInstance?.recordingStart !== null && mainInstance?.isRecording

    property real contentPreferredWidth: 168 * Style.uiScaleRatio
    property real contentPreferredHeight: showRecordingTimer ? 102 * Style.uiScaleRatio : 64 * Style.uiScaleRatio

    Behavior on contentPreferredHeight {
        NumberAnimation {
            duration: Style.animationNormal
        }
    }

    readonly property bool allowAttach: true

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                RowLayout {
                    spacing: Style.marginM

                    NIconButton {
                        icon: mainInstance?.isRecording ? "stop" : "circle-dot"
                        tooltipText: mainInstance?.isRecording ? pluginApi?.tr("messages.stop-recording") : pluginApi?.tr("messages.start-recording")
                        baseSize: root.panelButtonSize
                        customRadius: baseSize / 2
                        colorBg: mainInstance?.isRecording ? Color.mPrimary : Style.capsuleColor
                        colorFg: mainInstance?.isRecording ? Color.mOnPrimary : Color.mPrimary
                        enabled: !!mainInstance
                        onClicked: {
                            if (mainInstance.isRecording) {
                                mainInstance.stopRecording();
                            } else {
                                mainInstance.startRecording();
                            }
                        }
                    }

                    NIconButton {
                        icon: "arrow-back-up"
                        tooltipText: mainInstance?.isReplaying ? pluginApi?.tr("messages.stop-replay") : pluginApi?.tr("messages.start-replay")
                        baseSize: root.panelButtonSize
                        customRadius: baseSize / 2
                        colorBg: mainInstance?.isReplaying ? Color.mPrimary : Style.capsuleColor
                        colorFg: mainInstance?.isReplaying ? Color.mOnPrimary : Color.mPrimary
                        enabled: !!mainInstance && !mainInstance.isRecording
                        onClicked: {
                            if (mainInstance.isReplaying) {
                                mainInstance.stopReplay();
                            } else {
                                mainInstance.startReplay();
                            }
                        }
                    }

                    NIconButton {
                        icon: "arrow-bar-to-down"
                        tooltipText: pluginApi?.tr("messages.save-replay")
                        baseSize: root.panelButtonSize
                        customRadius: baseSize / 2
                        colorBg: Style.capsuleColor
                        colorFg: Color.mPrimary
                        enabled: !!mainInstance && mainInstance.isReplaying
                        onClicked: mainInstance.saveReplay()
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                visible: root.showRecordingTimer
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                NLabel {
                    label: `${pluginApi?.tr("messages.elapsed")}: ${mainInstance?.recordingDuration ?? ""}`
                    labelColor: Color.mPrimary
                }
                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }
}
