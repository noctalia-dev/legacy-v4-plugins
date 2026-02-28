import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    property var keyData
    property string key:   keyData?.label   || ""
    property string type:  keyData?.keytype || "normal"
    property var code:  keyData?.keycode || 0
    property string shape: keyData?.shape   || "normal"
    property int shiftMode: 0

    property bool isShift:     (code === 42 || code === 54)
    property bool isBackspace: (key.toLowerCase() === "backspace")
    property bool isEnter:     (key.toLowerCase() === "enter" || key.toLowerCase() === "return")
    property bool toggled:     isShift ? shiftMode > 0 : false

    property real baseWidth: 45
    property real baseHeight: 45

    property var widthMultiplier: ({
        "normal": 1,
        "fn": 1,
        "tab": 1.6,
        "caps": 1.9,
        "shift": 2.5,
        "control": 1.3,
        "space": 6,
        "expand": 1.5,
        "empty": 1
    })

    property var heightMultiplier: ({
        "normal": 1,
        "fn": 0.7,
        "tab": 1,
        "caps": 1,
        "shift": 1,
        "control": 1,
        "space": 1,
        "expand": 1,
        "empty": 1
    })

    signal pressed (int code, string type)
    signal released(int code, string type)


    enabled: shape !== "empty"
    visible: shape !== "spacer"

    Layout.fillWidth: shape === "space" || shape === "expand"
    Layout.preferredWidth: shape === "space" || shape === "expand" ? -1 : baseWidth * (widthMultiplier[shape] || 1)
    Layout.preferredHeight: baseHeight * (heightMultiplier[shape] || 1)

    color: {
        if (!enabled) return "transparent";
        if (toggled) return Color.mPrimary;
        if (mouseArea.pressed) return Color.mSurfaceVariant;
        return Color.mSurfaceContainerHighest;
    }

    radius: Style.radiusS
    border.width: 1
    border.color: Color.mOutlineVariant

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    // Key label
    NText {
        anchors.centerIn: parent
        text: {
            if (root.isBackspace) return "⌫";
            if (root.isEnter) return "↵";
            if (root.shiftMode === 2) {
                return root.keyData?.labelCaps || root.keyData?.labelShift || root.keyData?.label || "";
            }
            if (root.shiftMode === 1) {
                return root.keyData?.labelShift || root.keyData?.label || "";
            }
            return root.keyData?.label || "";
        }
        pointSize: shape === "fn" ? Style.fontSizeS * 0.8 : Style.fontSizeM
        color: toggled ? Color.mOnPrimary : Color.mOnSurface
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled

        onPressed: {
            root.pressed(root.code, root.type);
        }

        onReleased: {
            root.released(root.code, root.type);
        }
    }
}
