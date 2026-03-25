import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Widgets
import qs.Services.UI

PanelWindow {
    id: polkitWindow
   
    property AuthFlow flow
    property var pluginApi

    Connections {
        target: flow
        function onFailedChanged() {
            if (flow && flow.failed) {
                ToastService.showError(
                    pluginApi ? pluginApi.tr("error.failed.title") : "Authentication Failed",
                    pluginApi ? pluginApi.tr("error.failed.message") : "The password you entered was incorrect."
                )
            }
        }
    }
    
    // Layer above everything else (critical system prompt)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property real shadowPadding: Style.shadowBlurMax + Style.marginL

    // Explicit size - include shadowPadding so the shadow isn't clipped at window corners
    implicitWidth: 400 * Style.uiScaleRatio + shadowPadding * 2
    implicitHeight: contentLayout.implicitHeight + (Style.marginL * 2) + shadowPadding * 2

    color: "transparent"

    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: shadowPadding
        focus: true

        Keys.onPressed: function(event) {
            if (!flow) return;
            
            if (Keybinds.checkKey(event, "escape", Settings)) {
                flow.cancelAuthenticationRequest();
                event.accepted = true;
            } else if (Keybinds.checkKey(event, "enter", Settings)) {
                if (passwordInput.text !== "") {
                     flow.submit(passwordInput.text);
                     passwordInput.text = "";
                }
                event.accepted = true;
            }
        }

        
        transform: Translate {
            id: shakeTranslate
            x: 0
        }

        // Error animation
        SequentialAnimation {
            id: errorShake
            running: flow && flow.failed
            loops: 1
            
            NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: -10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: -10; to: 10; duration: 50; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeTranslate; property: "x"; from: 10; to: 0; duration: 50; easing.type: Easing.InOutQuad }
        }

        // Shadow effect (behind background)
        NDropShadow {
            anchors.fill: customBackground
            source: customBackground
            autoPaddingEnabled: true
            z: -1
        }

        Rectangle {
            id: customBackground
            anchors.fill: parent
            radius: Style.radiusL
            color: Qt.alpha(Color.mSurface, 0.95)
            border.color: (flow && (flow.failed || flow.supplementaryIsError)) ? Color.mError : Color.mOutline
            border.width: Style.borderS
            
            Behavior on border.color {
                ColorAnimation { duration: Style.animationFast }
            }
        }

        ColumnLayout {
            id: contentLayout
            anchors.centerIn: parent
            width: parent.width - (Style.marginL * 2)
            spacing: Style.marginM

            // Header with Icon
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NImageRounded {
                    Layout.preferredWidth: Style.fontSizeXXL * 2
                    Layout.preferredHeight: Style.fontSizeXXL * 2
                    imagePath: (flow && flow.iconName) ? Quickshell.iconPath(flow.iconName) : ""
                    fallbackIcon: "lock"
                    borderWidth: 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    NText {
                        text: flow ? flow.message : (pluginApi ? pluginApi.tr("window.title") : "Authentication Required")
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    NText {
                        text: flow ? flow.actionId : ""
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        visible: text !== ""
                    }
                }
            }
            
            // Supplementary Message (Error or prompt)
            NText {
                visible: flow && flow.supplementaryMessage !== ""
                text: flow ? flow.supplementaryMessage : ""
                pointSize: Style.fontSizeS
                color: (flow && flow.supplementaryIsError) ? Color.mError : Color.mOnSurfaceVariant
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            // Input Field
            NTextInput {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: flow ? flow.inputPrompt : (pluginApi ? pluginApi.tr("prompt.password") : "Password")
                label: (flow && flow.isResponseRequired) ? (pluginApi ? pluginApi.tr("prompt.password") : "Password") : ""
                inputItem.echoMode: (flow && !flow.responseVisible) ? TextInput.Password : TextInput.Normal
                visible: flow && flow.isResponseRequired
                
                onAccepted: {
                    if (flow) {
                        flow.submit(passwordInput.text)
                        passwordInput.text = ""
                    }
                }
            }

            // Actions
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.marginS
                spacing: Style.marginM

                Item { Layout.fillWidth: true } // Spacer

                NButton {
                    text: pluginApi ? pluginApi.tr("action.cancel") : "Cancel"
                    backgroundColor: Color.mSurfaceVariant
                    textColor: Color.mOnSurfaceVariant
                    outlined: false
                    onClicked: {
                        if (flow) flow.cancelAuthenticationRequest()
                    }
                }

                NButton {
                    text: pluginApi ? pluginApi.tr("action.authenticate") : "Authenticate"
                    backgroundColor: Color.mPrimary
                    textColor: Color.mOnPrimary
                    enabled: flow && flow.isResponseRequired
                    onClicked: {
                        if (flow) {
                            flow.submit(passwordInput.text)
                            passwordInput.text = ""
                        }
                    }
                }
            }
        }
    }
    
    // Focus handling
    Component.onCompleted: {
        passwordInput.inputItem.forceActiveFocus()
    }
}
