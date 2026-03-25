import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var def: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // ── Local edit state ─────────────────────────────────
    property bool   editCapture:  cfg.captureEnabled ?? def.captureEnabled ?? true
    property string editDevice:   cfg.evtestDevice   || def.evtestDevice   || "/dev/input/event3"
    property bool   editUseCustomColors: cfg.useCustomColors ?? def.useCustomColors ?? false
    property string editPillColor: cfg.pillColor ? cfg.pillColor : (def.pillColor ? def.pillColor : Color.mPrimary.toString())
    property string editPillBg:    cfg.pillBg    ? cfg.pillBg    : (def.pillBg    ? def.pillBg    : Color.mSurface.toString())
    property string editPosition:  cfg.position   || def.position   || "bottom"
    property int    editMargin:    cfg.marginPx   ?? def.marginPx   ?? 60
    property int    editDelay:     cfg.hideDelaySec ?? def.hideDelaySec ?? 2

    property var editDisabledScreens: cfg.disabledScreens ? cfg.disabledScreens.slice() : (def.disabledScreens ? def.disabledScreens.slice() : [])

    spacing: Style.marginL

    // ── Capture Toggle ───────────────────────────────────
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.capture.label")
        description: pluginApi?.tr("settings.capture.description")
        checked: root.editCapture
        onToggled: checked => root.editCapture = checked
    }

    // ── IPC Information ──────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: infoCol.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
            id: infoCol
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
                spacing: Style.marginS

                NIcon {
                    icon: "info-circle"
                    pointSize: Style.fontSizeS
                    color: Color.mPrimary
                }

                NText {
                    text: pluginApi?.tr("settings.ipc.title")
                    pointSize: Style.fontSizeS
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                }
            }

            NText {
                Layout.fillWidth: true
                text: pluginApi?.tr("settings.ipc.toggleCommand")
                pointSize: Style.fontSizeXS
                font.family: Settings.data.ui.fontFixed
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WrapAnywhere
            }
        }
    }

    // ── Security Notice ─────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: securityCol.implicitHeight + Style.marginM * 2
        color: Qt.alpha(Color.mError, 0.12)
        border.color: Qt.alpha(Color.mError, 0.32)
        border.width: 1
        radius: Style.radiusM

        ColumnLayout {
            id: securityCol
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
                spacing: Style.marginS

                NIcon {
                    icon: "exclamation-circle"
                    pointSize: Style.fontSizeS
                    color: Color.mError
                }

                NText {
                    text: pluginApi?.tr("settings.security.title")
                    pointSize: Style.fontSizeS
                    font.weight: Font.Medium
                    color: Color.mError
                }
            }

            NText {
                Layout.fillWidth: true
                text: pluginApi?.tr("settings.security.message")
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }

            NText {
                Layout.fillWidth: true
                text: pluginApi?.tr("settings.security.disclaimer")
                pointSize: Style.fontSizeXS
                font.weight: Font.Medium
                color: Color.mError
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }



    // ── Device Path Input  ──────────────────
    NTextInput {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.device.label")
        description: pluginApi?.tr("settings.device.description")
        placeholderText: pluginApi?.tr("settings.device.placeholder")
        text: root.editDevice
        onTextChanged: root.editDevice = text
    }

    // ── Setup Guide  ───────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: guideCol.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
            id: guideCol
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
                spacing: Style.marginS

                NIcon {
                    icon: "terminal"
                    pointSize: Style.fontSizeS
                    color: Color.mPrimary
                }

                NText {
                    text: pluginApi?.tr("settings.guide.title")
                    pointSize: Style.fontSizeS
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                }
            }

            NText {
                Layout.fillWidth: true
                text: pluginApi?.tr("settings.guide.steps")
                pointSize: Style.fontSizeXS
                font.family: Settings.data.ui.fontFixed
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WrapAnywhere
                lineHeight: 1.2
            }
        }
    }

    // ── Monitors ─────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.monitors.label")
            description: pluginApi?.tr("settings.monitors.description")
        }

        Repeater {
            model: Quickshell.screens
            
            NToggle {
                Layout.fillWidth: true
                label: modelData.name
                
                // Checked if NOT in the disabled array
                checked: root.editDisabledScreens.indexOf(modelData.name) === -1
                
                onToggled: function(isChecked) {
                    var arr = root.editDisabledScreens.slice();
                    var idx = arr.indexOf(modelData.name);
                    
                    if (isChecked) {
                        // Remove from disabled list
                        if (idx !== -1) arr.splice(idx, 1);
                    } else {
                        // Add to disabled list
                        if (idx === -1) arr.push(modelData.name);
                    }
                    root.editDisabledScreens = arr;
                }
            }
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Position ─────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.position.label")
            description: pluginApi?.tr("settings.position.description")
        }

        NComboBox {
            Layout.fillWidth: true
            model: [
                { key: "bottom", name: pluginApi?.tr("settings.position.bottom") },
                { key: "top",    name: pluginApi?.tr("settings.position.top")    }
            ]
            currentKey: root.editPosition
            onSelected: key => root.editPosition = key
        }
    }

    // ── Margin ───────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.margin.label")
            description: pluginApi?.tr("settings.margin.description", { value: root.editMargin })
        }

        NSlider {
            Layout.fillWidth: true
            from: 20
            to: 300
            stepSize: 10
            value: root.editMargin
            onValueChanged: root.editMargin = value
        }
    }

    // ── Auto-hide Delay ──────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.delay.label")
            description: pluginApi?.tr("settings.delay.description", { value: root.editDelay })
        }

        NSlider {
            Layout.fillWidth: true
            from: 1
            to: 10
            stepSize: 1
            value: root.editDelay
            onValueChanged: root.editDelay = value
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Colors ───────────────────────────────────────────
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.useCustomColors.label")
        description: pluginApi?.tr("settings.useCustomColors.description")
        checked: root.editUseCustomColors
        onToggled: checked => root.editUseCustomColors = checked
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: root.editUseCustomColors

        NLabel {
            label: pluginApi?.tr("settings.pillColor.label")
            description: pluginApi?.tr("settings.pillColor.description")
        }

        NColorPicker {
            Layout.preferredWidth: Style.sliderWidth
            Layout.preferredHeight: Style.baseWidgetSize
            selectedColor: root.editPillColor
            onColorSelected: function(color) { root.editPillColor = color }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: root.editUseCustomColors

        NLabel {
            label: pluginApi?.tr("settings.pillBg.label")
            description: pluginApi?.tr("settings.pillBg.description")
        }

        NColorPicker {
            Layout.preferredWidth: Style.sliderWidth
            Layout.preferredHeight: Style.baseWidgetSize
            selectedColor: root.editPillBg
            onColorSelected: function(color) { root.editPillBg = color }
        }
    }

    NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginS
        Layout.bottomMargin: Style.marginS
    }

    // ── Preview ──────────────────────────────────────────
    NLabel {
        label: pluginApi?.tr("settings.preview.label")
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6

        Repeater {
            model: ["󰴈 +a", "CTRL+c", "H", "e", "l", "l", "o"]

            Rectangle {
                width: previewText.implicitWidth + 20
                height: 36
                radius: 8
                readonly property color previewBg: root.editUseCustomColors ? root.editPillBg : Color.mSurface
                readonly property color previewFg: root.editUseCustomColors ? root.editPillColor : Color.mPrimary
                
                color: Qt.alpha(previewBg, 0.8)
                border.color: Qt.alpha(previewFg, 0.27)
                border.width: 1

                Text {
                    id: previewText
                    anchors.centerIn: parent
                    text: modelData
                    color: parent.previewFg
                    font.pixelSize: 16
                    font.family: "monospace"
                    font.bold: true
                }
            }
        }
    }

    // ── Save ─────────────────────────────────────────────
    function saveSettings() {
        if (!pluginApi) return;

        pluginApi.pluginSettings.captureEnabled = root.editCapture;
        pluginApi.pluginSettings.evtestDevice   = root.editDevice;
        pluginApi.pluginSettings.useCustomColors= root.editUseCustomColors;
        if (root.editUseCustomColors) {
            pluginApi.pluginSettings.pillColor  = root.editPillColor.toString();
            pluginApi.pluginSettings.pillBg     = root.editPillBg.toString();
        }
        pluginApi.pluginSettings.position       = root.editPosition;

        pluginApi.pluginSettings.marginPx       = root.editMargin;
        pluginApi.pluginSettings.hideDelaySec   = root.editDelay;
        pluginApi.pluginSettings.disabledScreens= root.editDisabledScreens;

        pluginApi.saveSettings();
    }
}
