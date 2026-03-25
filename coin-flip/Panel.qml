import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Widgets

Item {
    id: root
    property var pluginApi: null

    // SmartPanel properties
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 200 * Style.uiScaleRatio
    property real contentPreferredHeight: 200 * Style.uiScaleRatio

    anchors.fill: parent

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: Style.marginL
            color: Color.mSurface
            radius: Style.radiusL
            border.color: Color.mOutline
            border.width: Style.borderS

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.marginL

                // Coin animation
                Item {
                    id: coinItem
                    Layout.preferredWidth: 128 * Style.uiScaleRatio
                    Layout.preferredHeight: 128 * Style.uiScaleRatio
                    Layout.alignment: Qt.AlignHCenter

                    property int frameIndex: 0
                    property bool flipping: true
                    property url currentIcon: Qt.resolvedUrl("icons/heads.svg")
                    property bool showResult: false
                    property string resultString: ""

                    property var flipFrames: [
                        Qt.resolvedUrl("icons/flip1.svg"),
                        Qt.resolvedUrl("icons/flip2.svg"),
                        Qt.resolvedUrl("icons/flip3.svg"),
                        Qt.resolvedUrl("icons/flip4.svg"),
                        Qt.resolvedUrl("icons/flip5.svg"),
                        Qt.resolvedUrl("icons/flip6.svg"),
                        Qt.resolvedUrl("icons/flip7.svg"),
                        Qt.resolvedUrl("icons/flip8.svg"),
                        Qt.resolvedUrl("icons/flip9.svg"),
                        Qt.resolvedUrl("icons/flip10.svg"),
                        Qt.resolvedUrl("icons/flip11.svg"),
                        Qt.resolvedUrl("icons/flip12.svg")
                    ]
                    property url headsIcon: Qt.resolvedUrl("icons/heads.svg")
                    property url tailsIcon: Qt.resolvedUrl("icons/tails.svg")

                    Timer {
                        id: flipTimer
                        interval: 20
                        repeat: true
                        running: coinItem.flipping
                        onTriggered: {
                            coinItem.frameIndex++
                            if (coinItem.frameIndex < coinItem.flipFrames.length * 3) {
                                coinItem.currentIcon = coinItem.flipFrames[coinItem.frameIndex % coinItem.flipFrames.length]
                                coinItem.showResult = false
                            } else {
                                coinItem.flipping = false
                                flipTimer.stop()
                                var isHeads = Math.random() < 0.5
                                coinItem.currentIcon = isHeads ? coinItem.headsIcon : coinItem.tailsIcon
                                coinItem.resultString = isHeads ? (pluginApi?.tr("common.heads") || "Heads")
                                                                 : (pluginApi?.tr("common.tails") || "Tails")
                                coinItem.showResult = true

                                if (pluginApi) {
                                    pluginApi.pluginSettings.lastResult = coinItem.resultString
                                    try { pluginApi.saveSettings() } catch(e) { Logger.w("CoinFlip", "saveSettings failed") }
                                }
                            }
                        }
                    }

                    Image {
                        id: coinImage
                        anchors.fill: parent
                        source: coinItem.currentIcon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!coinItem.flipping) {
                                    coinItem.frameIndex = 0
                                    coinItem.flipping = true
                                    coinItem.currentIcon = coinItem.flipFrames[0]
                                    flipTimer.start()
                                }
                            }
                        }
                    }
                }

                // Result text
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: coinItem.showResult ? coinItem.resultString : ""
                    font.pointSize: Style.fontSizeXL
                    font.weight: Font.Bold
                    color: Settings.data.colorSchemes.darkMode ? "white" : "black"
                }
            }
        }
    }

    Component.onCompleted: {
        // Start initial flip
        coinItem.frameIndex = 0
        coinItem.flipping = true
        coinItem.currentIcon = coinItem.flipFrames[0]
        flipTimer.start()
    }
}