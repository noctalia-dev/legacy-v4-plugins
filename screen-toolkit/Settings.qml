import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null
    spacing: Style.marginL

    property string screenshotPath: pluginApi?.pluginSettings?.screenshotPath || ""
    property string videoPath:      pluginApi?.pluginSettings?.videoPath      || ""
    property string filenameFormat: pluginApi?.pluginSettings?.filenameFormat || ""

    property string _previewNow: ""

    Timer {
        id: previewClock
        interval: 1000; repeat: true; running: true
        onTriggered: root._previewNow = new Date().toString()
    }

    function saveSettings() {
        if (!pluginApi) return
        pluginApi.pluginSettings.screenshotPath = root.screenshotPath
        pluginApi.pluginSettings.videoPath      = root.videoPath
        pluginApi.pluginSettings.filenameFormat = root.filenameFormat
        pluginApi.saveSettings()
    }

    function buildPreview(fmt) {
        var _ = root._previewNow
        var now = new Date()
        if (!fmt || fmt.trim() === "")
            return Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        return fmt
            .replace(/%Y/g, Qt.formatDateTime(now, "yyyy"))
            .replace(/%m/g, Qt.formatDateTime(now, "MM"))
            .replace(/%d/g, Qt.formatDateTime(now, "dd"))
            .replace(/%H/g, Qt.formatDateTime(now, "HH"))
            .replace(/%M/g, Qt.formatDateTime(now, "mm"))
            .replace(/%S/g, Qt.formatDateTime(now, "ss"))
    }

    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.screenshotPath")
        description:     pluginApi?.tr("settings.screenshotPathDesc")
        placeholderText: "~/Pictures/Screenshots"
        text:            root.screenshotPath
        onTextChanged: {
            root.screenshotPath = text
            saveSettings()
        }
    }

    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.videoPath")
        description:     pluginApi?.tr("settings.videoPathDesc")
        placeholderText: "~/Videos"
        text:            root.videoPath
        onTextChanged: {
            root.videoPath = text
            saveSettings()
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        ColumnLayout {
            spacing: Style.marginXS
            NLabel {
                label: pluginApi?.tr("settings.filenameFormat")
            }
            NText {
                text:        pluginApi?.tr("settings.filenameFormatDesc")
                pointSize:   Style.fontSizeXS
                color:       Color.mOnSurfaceVariant
                wrapMode:    Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Style.marginS

            readonly property var tokens: [
                { label: pluginApi?.tr("settings.filenameTokens.year"),   value: "%Y" },
                { label: pluginApi?.tr("settings.filenameTokens.month"),  value: "%m" },
                { label: pluginApi?.tr("settings.filenameTokens.day"),    value: "%d" },
                { label: pluginApi?.tr("settings.filenameTokens.hour"),   value: "%H" },
                { label: pluginApi?.tr("settings.filenameTokens.minute"), value: "%M" },
                { label: pluginApi?.tr("settings.filenameTokens.second"), value: "%S" },
            ]

            Repeater {
                model: parent.tokens
                delegate: Rectangle {
                    height: 28
                    width:  tokenRow.implicitWidth + Style.marginM * 2
                    radius: Style.radiusM
                    color:  tokenMA.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: tokenRow
                        anchors.centerIn: parent
                        spacing: Style.marginXS

                        NText {
                            text:        modelData.label
                            pointSize:   Style.fontSizeXS
                            font.weight: Font.Medium
                            color:       tokenMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        NText {
                            text:      modelData.value
                            pointSize: Style.fontSizeXS
                            color:     tokenMA.containsMouse ? Qt.rgba(1,1,1,0.65) : Color.mOnSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: tokenMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (!filenameInput.inputItem) return
                            var input = filenameInput.inputItem
                            var cur   = input.cursorPosition
                            var txt   = input.text
                            input.text = txt.substring(0, cur) + modelData.value + txt.substring(cur)
                            input.cursorPosition = cur + modelData.value.length
                            input.forceActiveFocus()
                        }
                    }
                }
            }
        }

        NTextInput {
            id: filenameInput
            Layout.fillWidth: true
            placeholderText: "%Y-%m-%dT%H-%M-%S"
            text: root.filenameFormat
            onTextChanged: {
                root.filenameFormat = text
                saveSettings()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height:  previewRow.implicitHeight + Style.marginM * 2
            radius:  Style.radiusM
            color:   Color.mSurfaceVariant
            opacity: 0.7

            Row {
                id: previewRow
                anchors {
                    left:           parent.left
                    right:          parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin:     Style.marginM
                    rightMargin:    Style.marginM
                }
                spacing: Style.marginS

                NIcon {
                    icon:   "file"
                    color:  Color.mOnSurfaceVariant
                    scale:  0.85
                    anchors.verticalCenter: parent.verticalCenter
                }
                NText {
                    text:        root.buildPreview(root.filenameFormat) + ".ext"
                    pointSize:   Style.fontSizeXS
                    color:       Color.mOnSurface
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: parent.width - (Style.marginM * 2)
                }
            }
        }
    }
}

