import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
    id: root

    property real pointSize: Style.fontSizeL
    property bool applyUiScale: true
    property color color: Color.mOnSurface
    // Diagonal strike when disconnected (keep off on tiny bar icons)
    property bool crossed: false

    // Whole-pixel size avoids half-pixel blur / MultiEffect shimmer
    readonly property int px: Math.max(1, Math.round(applyUiScale ? root.pointSize * Style.uiScaleRatio : root.pointSize))

    implicitWidth: px
    implicitHeight: px
    width: px
    height: px
    clip: true

    Image {
        id: iconImage
        anchors.centerIn: parent
        width: root.px
        height: root.px
        source: Qt.resolvedUrl("icons/openvpn.svg")
        sourceSize: Qt.size(root.px * 2, root.px * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: false

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.color
        }
    }

    // Thin, clipped strike — only for larger sizes (panel / control center)
    Rectangle {
        visible: root.crossed && root.px >= 16
        anchors.centerIn: parent
        width: parent.width * 1.05
        height: Math.max(1, Math.round(parent.height * 0.08))
        radius: height / 2
        color: root.color
        rotation: -45
        opacity: 0.85
        antialiasing: true
    }
}
