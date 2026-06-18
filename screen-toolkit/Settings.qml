import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    property var pluginApi: null
    spacing: Style.marginL

    property string screenshotPath:         ""
    property string videoPath:              ""
    property string filenameFormat:         ""
    property string x02ApiKey:             ""
    property string x02Expiry:             "7d"
    property bool   shareSkipPopover:      false
    property bool   recordSkipConfirmation: false
    property bool   recordCopyToClipboard:  false
    property int    gifMaxSeconds:          30
    property string searchEngineUrl:        ""
    property bool   _loaded: false
    property string _previewNow: ""

    Timer {
        id: previewClock
        interval: 1000; repeat: true; running: root.visible
        onTriggered: root._previewNow = new Date().toString()
    }

    function _load() {
        if (!pluginApi?.pluginSettings) return
        _loaded = false
        screenshotPath         = pluginApi.pluginSettings.screenshotPath         || ""
        videoPath              = pluginApi.pluginSettings.videoPath              || ""
        filenameFormat         = pluginApi.pluginSettings.filenameFormat         || ""
        x02ApiKey              = pluginApi.pluginSettings.x02ApiKey              || ""
        x02Expiry              = pluginApi.pluginSettings.x02Expiry              || "7d"
        shareSkipPopover       = pluginApi.pluginSettings.shareSkipPopover       ?? false
        recordSkipConfirmation = pluginApi.pluginSettings.recordSkipConfirmation ?? false
        recordCopyToClipboard  = pluginApi.pluginSettings.recordCopyToClipboard  ?? false
        gifMaxSeconds          = pluginApi.pluginSettings.gifMaxSeconds          ?? 30
        searchEngineUrl        = pluginApi.pluginSettings.searchEngineUrl        || ""
        _loaded = true
    }

    Component.onCompleted: _load()
    onPluginApiChanged:    _load()

    function saveSettings() {
        if (!pluginApi || !_loaded) return
        pluginApi.pluginSettings.screenshotPath         = root.screenshotPath
        pluginApi.pluginSettings.videoPath              = root.videoPath
        pluginApi.pluginSettings.filenameFormat         = root.filenameFormat
        pluginApi.pluginSettings.x02ApiKey              = root.x02ApiKey
        pluginApi.pluginSettings.x02Expiry              = root.x02Expiry
        pluginApi.pluginSettings.shareSkipPopover       = root.shareSkipPopover
        pluginApi.pluginSettings.recordSkipConfirmation = root.recordSkipConfirmation
        pluginApi.pluginSettings.recordCopyToClipboard  = root.recordCopyToClipboard
        pluginApi.pluginSettings.gifMaxSeconds          = root.gifMaxSeconds
        pluginApi.pluginSettings.searchEngineUrl        = root.searchEngineUrl
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

    // ── Paths ─────────────────────────────────────────────────────────────────
    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.screenshotPath")
        description:     pluginApi?.tr("settings.screenshotPathDesc")
        placeholderText: "~/Pictures/Screenshots"
        text:            root.screenshotPath
        onTextChanged:   { root.screenshotPath = text; saveSettings() }
    }

    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.videoPath")
        description:     pluginApi?.tr("settings.videoPathDesc")
        placeholderText: "~/Videos"
        text:            root.videoPath
        onTextChanged:   { root.videoPath = text; saveSettings() }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── Filename format ───────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        ColumnLayout {
            spacing: Style.marginXS
            NLabel { label: pluginApi?.tr("settings.filenameFormat") }
            NText {
                text:      pluginApi?.tr("settings.filenameFormatDesc")
                pointSize: Style.fontSizeXS
                color:     Color.mOnSurfaceVariant
                wrapMode:  Text.WordWrap
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
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
            text:            root.filenameFormat
            onTextChanged:   { root.filenameFormat = text; saveSettings() }
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
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Style.marginM; rightMargin: Style.marginM
                }
                spacing: Style.marginS
                NIcon {
                    icon:  "file"; color: Color.mOnSurfaceVariant; scale: 0.85
                    anchors.verticalCenter: parent.verticalCenter
                }
                NText {
                    text:        root.buildPreview(root.filenameFormat) + ".ext"
                    pointSize:   Style.fontSizeXS
                    color:       Color.mOnSurface
                    font.family: "monospace"
                    elide:       Text.ElideRight
                    width:       parent.width - Style.marginM * 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── Share ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "share"; color: Color.mPrimary }
            NLabel { label: pluginApi?.tr("settings.shareSection") }
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.x02ApiKey")
            description:     pluginApi?.tr("settings.x02ApiKeyDesc")
            placeholderText: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
            text:            root.x02ApiKey
            onTextChanged:   { root.x02ApiKey = text; saveSettings() }
        }

        // Expiry — only relevant when API key is set
        ColumnLayout {
            Layout.fillWidth: true
            spacing:  Style.marginXS
            opacity:  root.x02ApiKey.trim() !== "" ? 1.0 : 0.4

            NLabel { label: pluginApi?.tr("settings.x02Expiry") }

            NText {
                text:      pluginApi?.tr("settings.x02ExpiryDesc")
                pointSize: Style.fontSizeXS
                color:     Color.mOnSurfaceVariant
                wrapMode:  Text.WordWrap
                Layout.fillWidth: true
            }

            Flow {
                Layout.fillWidth: true
                spacing: Style.marginS

                readonly property var expiryDefs: [
                    { id: "1h",        label: pluginApi?.tr("settings.expiry1h")        },
                    { id: "1d",        label: pluginApi?.tr("settings.expiry1d")        },
                    { id: "7d",        label: pluginApi?.tr("settings.expiry7d")        },
                    { id: "30d",       label: pluginApi?.tr("settings.expiry30d")       },
                    { id: "permanent", label: pluginApi?.tr("settings.expiryPermanent") },
                ]

                Repeater {
                    model: parent.expiryDefs
                    delegate: Rectangle {
                        height:  28
                        width:   _expLabel.implicitWidth + Style.marginM * 2
                        radius:  Style.radiusM
                        enabled: root.x02ApiKey.trim() !== ""
                        color:   root.x02Expiry === modelData.id
                            ? Color.mPrimary
                            : (_expMA.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        NText {
                            id: _expLabel
                            anchors.centerIn: parent
                            text:        modelData.label
                            pointSize:   Style.fontSizeXS
                            font.weight: root.x02Expiry === modelData.id ? Font.Bold : Font.Normal
                            color:       root.x02Expiry === modelData.id
                                ? Color.mOnPrimary
                                : (_expMA.containsMouse ? Color.mOnHover : Color.mOnSurface)
                        }
                        MouseArea {
                            id: _expMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled:      parent.enabled
                            onClicked:    { root.x02Expiry = modelData.id; saveSettings() }
                        }
                    }
                }
            }
        }

        NToggle {
            Layout.fillWidth: true
            label:       pluginApi?.tr("settings.shareSkipPopover")
            description: pluginApi?.tr("settings.shareSkipPopoverDesc")
            checked:     root.shareSkipPopover
            onToggled:   (v) => { root.shareSkipPopover = v; saveSettings() }
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── Recording ─────────────────────────────────────────────────────────────
    NLabel { label: pluginApi?.tr("settings.recordingSection") }

    NToggle {
        Layout.fillWidth: true
        label:       pluginApi?.tr("settings.recordSkipConfirmation")
        description: pluginApi?.tr("settings.recordSkipConfirmationDesc")
        checked:     root.recordSkipConfirmation
        onToggled:   (v) => { root.recordSkipConfirmation = v; saveSettings() }
    }

    NToggle {
        Layout.fillWidth: true
        label:       pluginApi?.tr("settings.recordCopyToClipboard")
        description: pluginApi?.tr("settings.recordCopyToClipboardDesc")
        checked:     root.recordCopyToClipboard
        onToggled:   (v) => { root.recordCopyToClipboard = v; saveSettings() }
    }

    NTextInput {
        Layout.fillWidth: true
        label:           pluginApi?.tr("settings.gifMaxSeconds")
        description:     pluginApi?.tr("settings.gifMaxSecondsDesc")
        placeholderText: "30"
        text:            root.gifMaxSeconds
        onTextChanged: {
            var val = parseInt(text)
            if (!isNaN(val)) {
                root.gifMaxSeconds = Math.max(5, Math.min(300, val))
                saveSettings()
            }
        }
    }

    NDivider { Layout.fillWidth: true; Layout.topMargin: Style.marginM; Layout.bottomMargin: Style.marginM }

    // ── OCR ───────────────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        RowLayout {
            spacing: Style.marginS
            NIcon  { icon: "scan"; color: Color.mPrimary }
            NLabel { label: pluginApi?.tr("settings.ocrSection") }
        }

        NTextInput {
            Layout.fillWidth: true
            label:           pluginApi?.tr("settings.searchEngineUrl")
            description:     pluginApi?.tr("settings.searchEngineUrlDesc")
            placeholderText: "https://www.google.com/search?q="
            text:            root.searchEngineUrl
            onTextChanged:   { root.searchEngineUrl = text; saveSettings() }
        }
    }
}

