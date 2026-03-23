import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

FocusScope {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 360 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.ceil(panelCard.implicitHeight + (Style.marginM * 2))
    readonly property bool allowAttach: true

    anchors.fill: parent
    focus: visible

    readonly property var mainInst: pluginApi?.mainInstance ?? null
    property string flashedAction: ""

    readonly property var buttonModel: [
        { "label": "AC", "action": "clear", "tone": "danger", "span": 1 },
        { "label": "+/-", "action": "sign", "tone": "operator", "span": 1 },
        { "label": "%", "action": "percent", "tone": "operator", "span": 1 },
        { "label": "DEL", "action": "delete", "tone": "operator", "span": 1 },
        { "label": "7", "action": "7", "tone": "number", "span": 1 },
        { "label": "8", "action": "8", "tone": "number", "span": 1 },
        { "label": "9", "action": "9", "tone": "number", "span": 1 },
        { "label": "/", "action": "divide", "tone": "operator", "span": 1 },
        { "label": "4", "action": "4", "tone": "number", "span": 1 },
        { "label": "5", "action": "5", "tone": "number", "span": 1 },
        { "label": "6", "action": "6", "tone": "number", "span": 1 },
        { "label": "x", "action": "multiply", "tone": "operator", "span": 1 },
        { "label": "1", "action": "1", "tone": "number", "span": 1 },
        { "label": "2", "action": "2", "tone": "number", "span": 1 },
        { "label": "3", "action": "3", "tone": "number", "span": 1 },
        { "label": "-", "action": "subtract", "tone": "operator", "span": 1 },
        { "label": "0", "action": "0", "tone": "number", "span": 2 },
        { "label": ".", "action": "decimal", "tone": "number", "span": 1 },
        { "label": "+", "action": "add", "tone": "operator", "span": 1 },
        { "label": "=", "action": "equals", "tone": "accent", "span": 4 }
    ]

    Timer {
        id: flashTimer
        interval: 140
        repeat: false
        onTriggered: root.flashedAction = ""
    }

    Component.onCompleted: {
        if (visible) root.forceActiveFocus();
    }

    onVisibleChanged: {
        if (visible) root.forceActiveFocus();
    }

    Keys.onPressed: event => {
        const action = mainInst?.actionForKeyEvent(event) ?? "";
        if (action !== "") {
            root.flashButton(action);
        }
        if (mainInst?.handleKeyEvent(event)) {
            event.accepted = true;
        }
    }

    function flashButton(action) {
        flashedAction = action;
        flashTimer.restart();
    }

    function buttonFill(buttonData, hovered, active) {
        if (active) {
            if (buttonData.tone === "accent") return Qt.darker(Color.mPrimary, 1.12);
            if (buttonData.tone === "danger") return Qt.alpha(Color.mError, 0.22);
            if (buttonData.tone === "operator") return Qt.alpha(Color.mPrimary, 0.28);
            return Qt.alpha(Color.mOnSurface, 0.16);
        }
        if (buttonData.tone === "accent") {
            return hovered ? Qt.darker(Color.mPrimary, 1.05) : Color.mPrimary;
        }
        if (buttonData.tone === "danger") {
            return hovered ? Qt.alpha(Color.mError, 0.18) : Qt.alpha(Color.mError, 0.12);
        }
        if (buttonData.tone === "operator") {
            return hovered ? Qt.alpha(Color.mPrimary, 0.22) : Qt.alpha(Color.mPrimary, 0.15);
        }
        return hovered ? Qt.alpha(Color.mOnSurface, 0.10) : Color.mSurfaceVariant;
    }

    function buttonBorder(buttonData, hovered, active) {
        if (active) {
            if (buttonData.tone === "danger") return Qt.alpha(Color.mError, 0.85);
            return Color.mPrimary;
        }
        if (buttonData.tone === "accent") return Color.mPrimary;
        if (buttonData.tone === "danger") return Qt.alpha(Color.mError, 0.65);
        return hovered ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.7);
    }

    function buttonTextColor(buttonData) {
        if (buttonData.tone === "accent") return Color.mOnPrimary;
        if (buttonData.tone === "danger") return Color.mError;
        if (buttonData.tone === "operator") return Color.mPrimary;
        return Color.mOnSurface;
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NBox {
                id: panelCard
                Layout.fillWidth: true
                implicitHeight: Math.ceil(cardContent.implicitHeight + (Style.marginM * 2))

                ColumnLayout {
                    id: cardContent
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIcon {
                            icon: "calculator"
                            pointSize: Style.fontSizeL
                            color: Color.mPrimary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Style.marginS

                            NText {
                                text: pluginApi?.tr("panel.title") ?? "Calculator"
                                pointSize: Style.fontSizeL
                                font.bold: true
                                color: Color.mOnSurface
                            }

                            NText {
                                Layout.fillWidth: true
                                text: pluginApi?.tr("panel.subtitle") ?? "Quick math in the bar"
                                color: Qt.alpha(Color.mOnSurface, 0.68)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: expressionLabel.visible ? 92 : 72
                        Layout.minimumHeight: Layout.preferredHeight
                        radius: Style.radiusL
                        color: Qt.alpha(Color.mPrimary, 0.08)
                        border.color: root.activeFocus ? Qt.alpha(Color.mPrimary, 0.8) : Qt.alpha(Color.mOutline, 0.65)
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Style.marginM
                            spacing: Style.marginS

                            NText {
                                id: expressionLabel
                                Layout.fillWidth: true
                                text: mainInst?.expressionText ?? ""
                                visible: text !== ""
                                pointSize: Style.fontSizeS
                                color: Qt.alpha(Color.mOnSurface, 0.68)
                                elide: Text.ElideLeft
                                horizontalAlignment: Text.AlignRight
                            }

                            NText {
                                Layout.fillWidth: true
                                text: mainInst?.displayText ?? "0"
                                pointSize: Math.round(Style.fontSizeL * 1.85)
                                font.bold: true
                                color: (mainInst?.errorState ?? false) ? Color.mError : Color.mOnSurface
                                elide: Text.ElideLeft
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: Style.marginS
                        columnSpacing: Style.marginS

                        Repeater {
                            model: root.buttonModel

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.columnSpan: modelData.span
                                Layout.preferredHeight: modelData.action === "equals" ? 58 : 52
                                Layout.minimumHeight: Layout.preferredHeight

                                readonly property bool isFlashed: root.flashedAction === modelData.action
                                radius: Style.radiusL
                                color: root.buttonFill(modelData, buttonMouse.containsMouse, isFlashed)
                                border.color: root.buttonBorder(modelData, buttonMouse.containsMouse, isFlashed)
                                border.width: 1
                                scale: isFlashed ? 0.96 : 1.0

                                Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                Behavior on border.color { ColorAnimation { duration: Style.animationFast } }
                                Behavior on scale { NumberAnimation { duration: 90 } }

                                NText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    pointSize: modelData.action === "equals" ? Style.fontSizeL : Style.fontSizeM
                                    font.bold: true
                                    color: root.buttonTextColor(modelData)
                                }

                                MouseArea {
                                    id: buttonMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        mainInst?.pressButton(modelData.action);
                                        root.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
