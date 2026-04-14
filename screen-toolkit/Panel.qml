import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
Item {
    id: root
    property var pluginApi: null
    readonly property var  geometryPlaceholder:    panelContainer
    readonly property bool allowAttach:            true
    property real contentPreferredWidth:           340 * Style.uiScaleRatio
    property real contentPreferredHeight:          mainCol.implicitHeight + Style.marginL * 2
    anchors.fill: parent
    onPluginApiChanged: {
        if (pluginApi) {
            var saved = pluginApi.pluginSettings.selectedOcrLang
            if (saved && saved !== "") root.selectedOcrLang = saved
            _resolveMainInstance()
            mainInstancePoller.start()
        }
    }
    property var mainInstance: null
    Connections {
        target: pluginApi
        ignoreUnknownSignals: true
        function onMainInstanceChanged() { root._resolveMainInstance() }
    }
    function _resolveMainInstance() {
        if (pluginApi?.mainInstance) {
            root.mainInstance = pluginApi.mainInstance
            mainInstancePoller.stop()
            Logger.i("ScreenToolkit", "mainInstance resolved: " + root.mainInstance)
        }
    }
    Timer {
        id: mainInstancePoller
        interval: 200; repeat: true
        onTriggered: root._resolveMainInstance()
    }
    readonly property bool   isRunning:    pluginApi?.pluginSettings?.stateIsRunning  ?? false
    readonly property string activeTool:   pluginApi?.pluginSettings?.stateActiveTool ?? ""
    readonly property bool   mirrorActive: pluginApi?.pluginSettings?.stateMirrorVisible ?? false
    readonly property bool   hasResult:    activeTool !== "" && !isRunning
    readonly property bool _isNiri:     (pluginApi?.pluginSettings?.detectedCompositor ?? "") === "niri"
    readonly property bool _isHyprland: (pluginApi?.pluginSettings?.detectedCompositor ?? "") === "hyprland"
    onActiveToolChanged: {
        if (activeTool === "ocr" || activeTool === "qr"
                || activeTool === "colorpicker" || activeTool === "palette")
            root.viewedTool = activeTool
    }
    Process { id: panelClipProc }
    Process {
        id: panelTranslateProc
        property bool isTranslating: false
        stdout: StdioCollector {}
        onExited: {
            isTranslating = false
            var result = panelTranslateProc.stdout.text.trim()
            if (pluginApi) {
                pluginApi.pluginSettings.translateResult = (result !== "")
                    ? result : pluginApi.tr("messages.translate-failed")
                pluginApi.saveSettings()
            }
        }
    }
    function copyToClipboard(text) {
        if (!text || text === "") return
        panelClipProc.exec({ command: ["bash", "-c", "printf '%s' " + _shellEscape(text) + " | wl-copy 2>/dev/null"] })
    }
    function runTranslate(text, targetLang) {
        if (!text || text === "" || panelTranslateProc.isTranslating) return
        panelTranslateProc.isTranslating = true
        if (pluginApi) { pluginApi.pluginSettings.translateResult = ""; pluginApi.saveSettings() }
        panelTranslateProc.exec({ command: ["bash", "-c", "trans -brief -to " + targetLang + " " + _shellEscape(text)] })
    }
    function _shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'"
    }
    readonly property var    installedLangs:    pluginApi?.pluginSettings?.installedLangs || ["eng"]
    readonly property bool   transAvailable:    pluginApi?.pluginSettings?.transAvailable || false
    property string          selectedOcrLang:   "eng"
    property string          selectedTransLang: "en"
    onSelectedOcrLangChanged: {
        if (pluginApi) {
            pluginApi.pluginSettings.selectedOcrLang = selectedOcrLang
            pluginApi.saveSettings()
        }
    }
    readonly property var ocrLangModel: {
        var out = []
        for (var i = 0; i < root.installedLangs.length; i++)
            out.push({ key: root.installedLangs[i], name: root.installedLangs[i].toUpperCase() })
        return out
    }
    readonly property var transLangs: [
        { code: "en", name: "English"    }, { code: "ar", name: "Arabic"     },
        { code: "fr", name: "French"     }, { code: "es", name: "Spanish"    },
        { code: "de", name: "German"     }, { code: "it", name: "Italian"    },
        { code: "pt", name: "Portuguese" }, { code: "ru", name: "Russian"    },
        { code: "zh", name: "Chinese"    }, { code: "ja", name: "Japanese"   },
        { code: "ko", name: "Korean"     }, { code: "tr", name: "Turkish"    },
        { code: "hi", name: "Hindi"      }, { code: "nl", name: "Dutch"      },
        { code: "pl", name: "Polish"     }, { code: "sv", name: "Swedish"    },
        { code: "fa", name: "Persian"    }, { code: "id", name: "Indonesian" },
        { code: "uk", name: "Ukrainian"  }, { code: "vi", name: "Vietnamese" }
    ]
    readonly property var transLangModel: {
        var out = []
        for (var i = 0; i < root.transLangs.length; i++)
            out.push({ key: root.transLangs[i].code, name: root.transLangs[i].name })
        return out
    }
    readonly property string pickedHex: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.resultHex
        return (typeof v === "string" && v.length === 7 && v.charAt(0) === "#") ? v : ""
    }
    readonly property string pickedRgb: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.resultRgb
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string pickedHsv: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.resultHsv
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string pickedHsl: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.resultHsl
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property string colorCapturePath: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.colorCapturePath
        return (typeof v === "string" && v !== "") ? v : ""
    }
    readonly property int colorCacheBust: pluginApi?.pluginSettings?.colorCacheBust ?? 0
    readonly property var colorHistory:   pluginApi?.pluginSettings?.colorHistory   || []
    readonly property var paletteColors:  pluginApi?.pluginSettings?.paletteColors  || []
    readonly property string ocrResult: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.ocrResult
        return (typeof v === "string") ? v : ""
    }
    readonly property string ocrCapturePath:  pluginApi?.pluginSettings?.ocrCapturePath || ""
    readonly property string translateResult: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.translateResult
        return (typeof v === "string") ? v : ""
    }
    readonly property string qrResult: {
        if (!pluginApi?.pluginSettings) return ""
        var v = pluginApi.pluginSettings.qrResult
        return (typeof v === "string") ? v : ""
    }
    readonly property string qrCapturePath: pluginApi?.pluginSettings?.qrCapturePath || ""
    readonly property string ocrUrl: {
        var m = root.ocrResult.match(/https?:\/\/[^\s]+/)
        if (m) return m[0]
        var m2 = root.ocrResult.match(/www\.[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}[^\s]*/)
        if (m2) return "https://" + m2[0]
        return ""
    }
    readonly property string ocrEmail: {
        var m = root.ocrResult.match(/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/)
        return m ? m[0] : ""
    }
    readonly property string ocrType: {
        if (root.ocrUrl   !== "") return "url"
        if (root.ocrEmail !== "") return "email"
        return "text"
    }
    readonly property string qrType: {
        var r = root.qrResult
        if (r.startsWith("http://") || r.startsWith("https://")) return "url"
        if (r.startsWith("WIFI:"))        return "wifi"
        if (r.startsWith("BEGIN:VCARD"))  return "contact"
        if (r.startsWith("mailto:"))      return "email"
        if (r.startsWith("otpauth://"))   return "otp"
        return "text"
    }
    readonly property string qrWifiName: {
        if (root.qrType !== "wifi") return ""
        var m = root.qrResult.match(/S:([^;]+)/)
        return m ? m[1] : ""
    }
    readonly property string qrWifiPass: {
        if (root.qrType !== "wifi") return ""
        var m = root.qrResult.match(/P:([^;]+)/)
        return m ? m[1] : ""
    }
    property int    focusedTool: 0
    property string viewedTool:  ""
    readonly property var toolDefs: pluginApi ? [
        { icon: "color-picker",  label: pluginApi.tr("tools.colorpicker"), tool: "colorpicker", tooltip: pluginApi.tr("tooltips.colorpicker") },
        { icon: "palette",       label: pluginApi.tr("tools.palette"),     tool: "palette",     tooltip: pluginApi.tr("tooltips.palette")     },
        { icon: "scan",          label: pluginApi.tr("tools.ocr"),         tool: "ocr",         tooltip: pluginApi.tr("tooltips.ocr")         },
        { icon: "world-search",  label: pluginApi.tr("tools.lens"),        tool: "lens",        tooltip: pluginApi.tr("tooltips.lens")        },
        { icon: "qrcode",        label: pluginApi.tr("tools.qr"),          tool: "qr",          tooltip: pluginApi.tr("tooltips.qr")          },
        { icon: "brush",         label: pluginApi.tr("tools.annotate"),    tool: "annotate",    tooltip: pluginApi.tr("tooltips.annotate")    },
        { icon: "video",         label: pluginApi.tr("tools.record"),      tool: "record",      tooltip: pluginApi.tr("tooltips.record")      },
        { icon: "pin",           label: pluginApi.tr("tools.pin"),         tool: "pin",         tooltip: pluginApi.tr("tooltips.pin")         },
        { icon: "ruler",         label: pluginApi.tr("tools.measure"),     tool: "measure",     tooltip: pluginApi.tr("tooltips.measure")     },
        { icon: "camera",        label: pluginApi.tr("tools.mirror"),      tool: "mirror",      tooltip: pluginApi.tr("tooltips.mirror")      }
    ] : []
    property string selectedRecordFormat: "gif"
    property bool   recordAudioOutput:    false
    property bool   recordAudioInput:     false
    property bool   recordCursor:         false
    function triggerFocused() {
        var t = root.toolDefs[root.focusedTool].tool
        Logger.i("ScreenToolkit", "triggerFocused: tool=" + t + " isRunning=" + root.isRunning)
        if (root.isRunning) { Logger.w("ScreenToolkit", "blocked: isRunning"); return }
        root.viewedTool = t
        if (t === "ocr" || t === "record" || t === "pin" || t === "annotate") return
        if      (t === "colorpicker") root.mainInstance?.runColorPicker()
        else if (t === "qr")          root.mainInstance?.runQr()
        else if (t === "lens")        root.mainInstance?.runLens()
        else if (t === "measure")     root.mainInstance?.runMeasure()
        else if (t === "palette")     root.mainInstance?.runPalette()
        else if (t === "mirror")      root.mainInstance?.runMirror()
        else Logger.e("ScreenToolkit", "unknown tool: " + t)
    }
    onActiveFocusChanged: if (activeFocus) toolBar.forceActiveFocus()
    onInstalledLangsChanged: {
        if (installedLangs.length > 0 && !installedLangs.includes(root.selectedOcrLang))
            root.selectedOcrLang = installedLangs[0]
    }
    Component.onCompleted: {
        Logger.i("ScreenToolkit", "Panel loaded — pluginApi=" + pluginApi)
    }
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"
        Column {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Style.marginL
            spacing: Style.marginM
            Row {
                width: parent.width; spacing: Style.marginS
                NIcon { icon: "crosshair"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                NText { text: pluginApi?.tr("panel.title"); pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle {
                id: toolBar
                width:  parent.width
                height: toolsCol.implicitHeight + Style.marginM * 2
                color:  Color.mSurfaceVariant
                radius: Style.radiusL
                focus:  true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left)       { root.focusedTool = (root.focusedTool + 9) % 10; event.accepted = true }
                    else if (event.key === Qt.Key_Right) { root.focusedTool = (root.focusedTool + 1) % 10; event.accepted = true }
                    else if (event.key === Qt.Key_Up)    { root.focusedTool = root.focusedTool >= 5 ? root.focusedTool - 5 : root.focusedTool; event.accepted = true }
                    else if (event.key === Qt.Key_Down)  { root.focusedTool = root.focusedTool < 5 ? root.focusedTool + 5 : root.focusedTool; event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.triggerFocused(); event.accepted = true }
                }
                Column {
                    id: toolsCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginM }
                    spacing: Style.marginS
                    readonly property int btnSize: Math.floor((width - Style.marginS * 4) / 5)
                    Row {
                        spacing: Style.marginS
                        Repeater {
                            model: root.toolDefs.slice(0, 5)
                            delegate: ToolBtn {
                                readonly property int myIdx: index
                                icon: modelData.icon; label: modelData.label; tooltip: modelData.tooltip
                                active:  root.activeTool === modelData.tool
                                focused: root.focusedTool === myIdx
                                running: root.isRunning
                                width: toolsCol.btnSize; height: toolsCol.btnSize + 18
                                onTriggered: { root.focusedTool = myIdx; root.viewedTool = modelData.tool; root.triggerFocused() }
                            }
                        }
                    }
                    Row {
                        spacing: Style.marginS
                        Repeater {
                            model: root.toolDefs.slice(5, 10)
                            delegate: ToolBtn {
                                readonly property int myIdx: index + 5
                                icon: modelData.icon; label: modelData.label; tooltip: modelData.tooltip
                                active:  root.activeTool === modelData.tool
                                focused: root.focusedTool === myIdx
                                running: root.isRunning
                                width: toolsCol.btnSize; height: toolsCol.btnSize + 18
                                onTriggered: { root.focusedTool = myIdx; root.viewedTool = modelData.tool; root.triggerFocused() }
                            }
                        }
                    }
                }
            }
            Rectangle {
                width:  parent.width; height: 56
                color:  Color.mSurfaceVariant; radius: Style.radiusL
                visible: root.isRunning
                Row {
                    anchors.centerIn: parent; spacing: Style.marginM
                    NIcon {
                        icon:  "loader"; color: Color.mPrimary
                        RotationAnimation on rotation {
                            running:  root.isRunning
                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                        }
                    }
                    NText { text: pluginApi?.tr("panel.running"); color: Color.mOnSurfaceVariant }
                }
            }
            Row {
                width: parent.width; spacing: Style.marginS
                visible: root.viewedTool === "annotate" && !root.isRunning
                Rectangle {
                    width:  (parent.width - Style.marginS * 2) / 3
                    height: 38; radius: Style.radiusM
                    color:        annotRegionBtn.containsMouse ? Color.mPrimary : Color.mSurface
                    border.color: Color.mPrimary
                    border.width: Style.capsuleBorderWidth
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon { icon: "crop"; color: annotRegionBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; scale: 0.85 }
                        NText { text: pluginApi?.tr("annotate.region"); color: annotRegionBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeXS }
                    }
                    MouseArea {
                        id: annotRegionBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runAnnotate()
                        onEntered: TooltipService.show(annotRegionBtn, pluginApi?.tr("annotate.regionTooltip"))
                        onExited:  TooltipService.hide()
                    }
                }
                Rectangle {
                    width:  (parent.width - Style.marginS * 2) / 3
                    height: 38; radius: Style.radiusM
                    enabled: root._isHyprland
                    color:        !enabled ? Color.mSurfaceVariant : (annotWinBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface)
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    opacity:      enabled ? 1.0 : 0.5
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon {
                            icon:  "app-window"
                            color: !parent.parent.enabled ? Color.mOnSurfaceVariant : (annotWinBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant)
                            scale: 0.85
                        }
                        NText {
                            text:       pluginApi?.tr("annotate.window")
                            color:      !parent.parent.enabled ? Color.mOnSurfaceVariant : (annotWinBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant)
                            font.weight: Font.Bold
                            pointSize:  Style.fontSizeXS
                        }
                    }
                    MouseArea {
                        id: annotWinBtn; anchors.fill: parent; hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { if (parent.enabled) root.mainInstance?.runAnnotateActiveWindow() }
                        onEntered: TooltipService.show(annotWinBtn, parent.enabled
                            ? pluginApi?.tr("annotate.windowTooltip")
                            : pluginApi?.tr("annotate.windowHyprlandOnly"))
                        onExited:  TooltipService.hide()
                    }
                }
                Rectangle {
                    width:  (parent.width - Style.marginS * 2) / 3
                    height: 38; radius: Style.radiusM
                    color:        annotFsBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                    border.color: Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon { icon: "maximize"; color: annotFsBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; scale: 0.85 }
                        NText { text: pluginApi?.tr("annotate.fullscreen"); color: annotFsBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeXS }
                    }
                    MouseArea {
                        id: annotFsBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runAnnotateFullscreen()
                        onEntered: TooltipService.show(annotFsBtn, pluginApi?.tr("annotate.fullscreenTooltip"))
                        onExited:  TooltipService.hide()
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginS
                visible: root.viewedTool === "ocr" && !root.isRunning
                Row {
                    width: parent.width; spacing: Style.marginS
                    visible: root.installedLangs.length > 0
                    NText {
                        id: langLabel
                        text:      pluginApi?.tr("panel.lang")
                        color:     Color.mOnSurface
                        pointSize: Style.fontSizeS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Flow {
                        visible: root.installedLangs.length <= 4
                        width:   parent.width - langLabel.implicitWidth - scanBtnInline.width - Style.marginS * 2
                        spacing: Style.marginXS
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: root.installedLangs
                            delegate: Rectangle {
                                height: 24
                                width:  chipLangText.implicitWidth + Style.marginM * 2
                                radius: Style.radiusS
                                color:  root.selectedOcrLang === modelData
                                    ? Color.mPrimary
                                    : (chipMA.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                                NText {
                                    id: chipLangText
                                    anchors.centerIn: parent
                                    text:       modelData.toUpperCase()
                                    color:      root.selectedOcrLang === modelData ? Color.mOnPrimary : Color.mOnSurface
                                    pointSize:  Style.fontSizeXS
                                    font.weight: root.selectedOcrLang === modelData ? Font.Bold : Font.Normal
                                }
                                MouseArea {
                                    id: chipMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedOcrLang = modelData
                                }
                            }
                        }
                    }
                    NComboBox {
                        visible:      root.installedLangs.length > 4
                        width:        parent.width - langLabel.implicitWidth - scanBtnInline.width - Style.marginS * 2
                        model:        root.ocrLangModel
                        currentKey:   root.selectedOcrLang
                        minimumWidth: 100
                        popupHeight:  220
                        onSelected:   (key) => { root.selectedOcrLang = key }
                    }
                    Rectangle {
                        id: scanBtnInline
                        height: 26
                        width:  _scanRow.implicitWidth + Style.marginM * 2
                        radius: Style.radiusS
                        color:  scanBtn.containsMouse ? Color.mPrimary : Color.mSurface
                        border.color: Color.mPrimary
                        border.width: Style.capsuleBorderWidth || 1
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: _scanRow
                            anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { icon: "scan"; color: scanBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; scale: 0.8 }
                            NText { text: pluginApi?.tr("panel.scan"); color: scanBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeXS }
                        }
                        MouseArea {
                            id: scanBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.mainInstance?.runOcr(root.selectedOcrLang)
                        }
                    }
                }
            }
            Row {
                width: parent.width; spacing: Style.marginS
                visible: root.viewedTool === "pin" && !root.isRunning
                Rectangle {
                    width:  (parent.width - Style.marginS) / 2
                    height: 38; radius: Style.radiusM
                    color:        pinScreenBtn.containsMouse ? Color.mPrimary : Color.mSurface
                    border.color: Color.mPrimary
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "crosshair"; color: pinScreenBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary }
                        NText { text: pluginApi.tr("panel.pinCapture"); color: pinScreenBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: pinScreenBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runPin()
                        onEntered: TooltipService.show(pinScreenBtn, pluginApi.tr("tooltips.pinRegion"))
                        onExited:  TooltipService.hide()
                    }
                }
                Rectangle {
                    width:  (parent.width - Style.marginS) / 2
                    height: 38; radius: Style.radiusM
                    color:        pinFileBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "folder-open"; color: pinFileBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant }
                        NText { text: pluginApi.tr("panel.pinFile"); color: pinFileBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: pinFileBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runPinFromFile()
                        onEntered: TooltipService.show(pinFileBtn, pluginApi.tr("tooltips.pinImage"))
                        onExited:  TooltipService.hide()
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginS
                visible: root.viewedTool === "record" && !root.isRunning
                Flow {
                    width: parent.width; spacing: Style.marginS
                    NText { text: pluginApi?.tr("panel.format"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; height: 26; verticalAlignment: Text.AlignVCenter }
                    Repeater {
                        model: [{ id: "gif", label: "GIF", hint: "· 30s" }, { id: "mp4", label: "MP4", hint: "" }]
                        delegate: Rectangle {
                            height: 26
                            width:  fmtLabel.implicitWidth + (modelData.hint !== "" ? fmtHint.implicitWidth + Style.marginXS : 0) + Style.marginM * 2 + Style.marginS
                            radius: Style.radiusS
                            color:  root.selectedRecordFormat === modelData.id ? Color.mPrimary : (fmtArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                            Row {
                                anchors.centerIn: parent; spacing: Style.marginXS
                                NText { id: fmtLabel; text: modelData.label; color: root.selectedRecordFormat === modelData.id ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS; font.weight: root.selectedRecordFormat === modelData.id ? Font.Bold : Font.Normal }
                                NText { id: fmtHint; visible: modelData.hint !== ""; text: modelData.hint; color: root.selectedRecordFormat === modelData.id ? Qt.rgba(1, 1, 1, 0.65) : Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                            }
                            MouseArea { id: fmtArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedRecordFormat = modelData.id }
                        }
                    }
                }
                Flow {
                    width: parent.width; spacing: Style.marginS
                    NText { text: pluginApi?.tr("panel.audio"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; height: 26; verticalAlignment: Text.AlignVCenter }
                    Rectangle {
                        height: 26; width: audioOutIcon.implicitWidth + audioOutLabel.implicitWidth + Style.marginM * 2 + Style.marginS + Style.marginXS; radius: Style.radiusS
                        color: root.recordAudioOutput ? Color.mPrimary : (audioOutArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                        Row { anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { id: audioOutIcon; icon: root.recordAudioOutput ? "volume" : "volume-off"; color: root.recordAudioOutput ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                            NText { id: audioOutLabel; text: pluginApi?.tr("panel.system"); color: root.recordAudioOutput ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS; font.weight: root.recordAudioOutput ? Font.Bold : Font.Normal }
                        }
                        MouseArea {
                            id: audioOutArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordAudioOutput = !root.recordAudioOutput
                            onEntered: TooltipService.show(audioOutArea, pluginApi?.tr("tooltips.systemAudio"))
                            onExited:  TooltipService.hide()
                        }
                    }
                    Rectangle {
                        height: 26; width: micIcon.implicitWidth + micLabel.implicitWidth + Style.marginM * 2 + Style.marginS + Style.marginXS; radius: Style.radiusS
                        color: root.recordAudioInput ? Color.mPrimary : (micArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                        Row { anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { id: micIcon; icon: root.recordAudioInput ? "microphone" : "microphone-off"; color: root.recordAudioInput ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                            NText { id: micLabel; text: pluginApi?.tr("panel.mic"); color: root.recordAudioInput ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS; font.weight: root.recordAudioInput ? Font.Bold : Font.Normal }
                        }
                        MouseArea {
                            id: micArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordAudioInput = !root.recordAudioInput
                            onEntered: TooltipService.show(micArea, pluginApi?.tr("tooltips.microphone"))
                            onExited:  TooltipService.hide()
                        }
                    }
                    Rectangle {
                        height: 26; width: cursorIcon.implicitWidth + cursorLabel.implicitWidth + Style.marginM * 2 + Style.marginS + Style.marginXS; radius: Style.radiusS
                        color: root.recordCursor ? Color.mPrimary : (cursorArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                        Row { anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { id: cursorIcon; icon: "pointer"; color: root.recordCursor ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                            NText { id: cursorLabel; text: pluginApi?.tr("panel.cursor"); color: root.recordCursor ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS; font.weight: root.recordCursor ? Font.Bold : Font.Normal }
                        }
                        MouseArea {
                            id: cursorArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordCursor = !root.recordCursor
                            onEntered: TooltipService.show(cursorArea, pluginApi?.tr("tooltips.cursor"))
                            onExited:  TooltipService.hide()
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 38; radius: Style.radiusM
                    color:        recStartBtn.containsMouse ? Color.mPrimary : Color.mSurface
                    border.color: Color.mPrimary
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "video"; color: recStartBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary }
                        NText { text: pluginApi?.tr("panel.record"); color: recStartBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: recStartBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runRecord(root.selectedRecordFormat, root.recordAudioOutput, root.recordAudioInput, root.recordCursor)
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginM
                visible: root.viewedTool === "mirror"
                Row {
                    width: parent.width; spacing: Style.marginS
                    NIcon { icon: "camera"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                    NText { text: pluginApi?.tr("mirror.title"); color: Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                }
                NText { width: parent.width; wrapMode: Text.WordWrap; text: pluginApi?.tr("mirror.hint"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                Rectangle {
                    width: parent.width; height: 38; radius: Style.radiusM
                    color:        root.mirrorActive ? Color.mError : (mirrorToggleBtn.containsMouse ? Color.mPrimary : Color.mSurface)
                    border.color: root.mirrorActive ? Color.mError : Color.mPrimary
                    border.width: Style.capsuleBorderWidth || 1
                    Row {
                        anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: root.mirrorActive ? "camera-off" : "camera"; color: root.mirrorActive ? Color.mOnError : (mirrorToggleBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary) }
                        NText { text: root.mirrorActive ? pluginApi?.tr("mirror.close") : pluginApi?.tr("mirror.open"); color: root.mirrorActive ? Color.mOnError : (mirrorToggleBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary); font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: mirrorToggleBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runMirror()
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginM
                visible: root.viewedTool === "colorpicker" && root.pickedHex !== ""
                Row {
                    width: parent.width; spacing: Style.marginM
                    Rectangle {
                        width: 110; height: 110; radius: Style.radiusM; color: Color.mSurfaceVariant; clip: true
                        border.color: Style.capsuleBorderColor || "transparent"
                        border.width: Style.capsuleBorderWidth || 1
                        Image {
                            id: pixelImg
                            anchors.fill: parent
                            source: root.colorCapturePath !== "" ? ("file://" + root.colorCapturePath) : ""
                            fillMode: Image.Stretch; smooth: false; cache: false
                            visible: status === Image.Ready
                            onStatusChanged: if (status === Image.Ready) visible = true
                        }
                        Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: "transparent"; border.color: "white"; border.width: Style.capsuleBorderWidth || 1; visible: pixelImg.status === Image.Ready }
                        NText { anchors.centerIn: parent; visible: pixelImg.status !== Image.Ready; text: "..."; color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeS }
                    }
                    Column {
                        width: parent.width - 110 - Style.marginM; spacing: Style.marginS
                        Rectangle {
                            id: colorSwatch
                            width: parent.width; height: 72; radius: Style.radiusM
                            color:        root.pickedHex !== "" ? root.pickedHex : "#888888"
                            border.color: Style.capsuleBorderColor || "transparent"
                            border.width: Style.capsuleBorderWidth || 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Connections {
                                target: root
                                function onPickedHexChanged() { if (root.pickedHex !== "") colorSwatch.color = root.pickedHex }
                            }
                        }
                        NText { width: parent.width; text: root.pickedHex.toUpperCase(); color: Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeM; horizontalAlignment: Text.AlignHCenter }
                    }
                }
                Repeater {
                    model: [
                        { label: "HEX", value: root.pickedHex },
                        { label: "RGB", value: root.pickedRgb },
                        { label: "HSL", value: root.pickedHsl },
                        { label: "HSV", value: root.pickedHsv }
                    ]
                    delegate: Rectangle {
                        width: mainCol.width; height: 36; radius: Style.radiusM
                        color:        rh.containsMouse ? Color.mHover : Color.mSurface
                        border.color: Style.capsuleBorderColor || "transparent"
                        border.width: Style.capsuleBorderWidth || 1
                        Row {
                            anchors.fill: parent; anchors.leftMargin: Style.marginS; anchors.rightMargin: Style.marginS; spacing: Style.marginS
                            NText { text: modelData.label; color: Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS; width: 36; height: parent.height; verticalAlignment: Text.AlignVCenter }
                            NText { text: modelData.value || "—"; color: Color.mOnSurface; pointSize: Style.fontSizeS; width: mainCol.width - 90; height: parent.height; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        }
                        NIcon { icon: "copy"; color: Color.mOnSurfaceVariant; anchors.right: parent.right; anchors.rightMargin: Style.marginS; anchors.verticalCenter: parent.verticalCenter }
                        MouseArea {
                            id: rh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.copyToClipboard(modelData.value); ToastService.showNotice(pluginApi?.tr("panel.formatCopied", { label: modelData.label })) }
                        }
                    }
                }
                Row {
                    width: parent.width; spacing: Style.marginS
                    Rectangle {
                        width: parent.width - 46; height: 36; radius: Style.radiusM
                        color:        cah.containsMouse ? Color.mPrimary : Color.mSurface
                        border.color: Color.mPrimary
                        border.width: Style.capsuleBorderWidth || 1
                        Row { anchors.centerIn: parent; spacing: Style.marginS
                            NIcon { icon: "copy"; color: cah.containsMouse ? Color.mOnPrimary : Color.mPrimary }
                            NText { text: pluginApi?.tr("panel.copyAll"); color: cah.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                        }
                        MouseArea {
                            id: cah; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.copyToClipboard(root.pickedHex + "\n" + root.pickedRgb + "\n" + root.pickedHsl + "\n" + root.pickedHsv)
                                ToastService.showNotice(pluginApi?.tr("panel.allFormatsCopied"))
                            }
                        }
                    }
                    Rectangle {
                        width: 38; height: 36; radius: Style.radiusM
                        color:        clrh.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurface
                        border.color: clrh.containsMouse ? Color.mError || "#f44336" : (Style.capsuleBorderColor || "transparent")
                        border.width: Style.capsuleBorderWidth || 1
                        NIcon { anchors.centerIn: parent; icon: "trash"; color: clrh.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant }
                        MouseArea {
                            id: clrh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pluginApi) {
                                    pluginApi.pluginSettings.resultHex       = ""
                                    pluginApi.pluginSettings.resultRgb       = ""
                                    pluginApi.pluginSettings.resultHsv       = ""
                                    pluginApi.pluginSettings.resultHsl       = ""
                                    pluginApi.pluginSettings.colorCapturePath = ""
                                    pluginApi.saveSettings()
                                }
                                root.viewedTool = ""
                            }
                            onEntered: TooltipService.show(clrh, pluginApi?.tr("panel.clearResult"))
                            onExited:  TooltipService.hide()
                        }
                    }
                }
                Column {
                    width: parent.width; spacing: Style.marginS
                    visible: root.colorHistory.length > 0
                    Row {
                        width: parent.width; spacing: Style.marginS
                        Rectangle { width: 40; height: 1; color: Color.mOnSurfaceVariant; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter }
                        NText { text: pluginApi?.tr("panel.history"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                        Rectangle { height: 1; color: Color.mOnSurfaceVariant; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 120 }
                        Rectangle {
                            width: 22; height: 22; radius: Style.radiusS || 4; anchors.verticalCenter: parent.verticalCenter
                            color: hhc.containsMouse ? Color.mErrorContainer || "#ffcdd2" : "transparent"
                            NIcon { anchors.centerIn: parent; icon: "trash"; color: hhc.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant; scale: 0.75 }
                            MouseArea {
                                id: hhc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (pluginApi) { pluginApi.pluginSettings.colorHistory = []; pluginApi.saveSettings() }
                                    ToastService.showNotice(pluginApi?.tr("panel.historyCleared"))
                                }
                            }
                        }
                    }
                    Row {
                        width: parent.width; spacing: Style.marginS
                        Repeater {
                            model: root.colorHistory
                            delegate: Rectangle {
                                width: 28; height: 28; radius: Style.radiusS || 6
                                border.color: hh.containsMouse ? Color.mPrimary : (Style.capsuleBorderColor || "transparent")
                                border.width: hh.containsMouse ? 2 : (Style.capsuleBorderWidth || 1)
                                Component.onCompleted: color = modelData
                                MouseArea {
                                    id: hh; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.copyToClipboard(modelData); ToastService.showNotice(pluginApi?.tr("panel.colorCopied", { color: modelData })) }
                                    onEntered: TooltipService.show(hh, modelData.toUpperCase() + " — " + pluginApi?.tr("panel.clickToCopy"))
                                    onExited:  TooltipService.hide()
                                }
                            }
                        }
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginS
                visible: root.viewedTool === "ocr" && root.ocrResult !== ""
                Rectangle {
                    width: parent.width
                    height: 160 * Style.uiScaleRatio
                    radius: Style.radiusM; color: Color.mSurfaceVariant; clip: true
                    visible: root.ocrCapturePath !== "" && root.ocrResult !== "" && ocrThumb.status === Image.Ready
                    Image {
                        id: ocrThumb; anchors.fill: parent
                        source: (root.ocrCapturePath !== "" && root.ocrResult !== "") ? ("file://" + root.ocrCapturePath) : ""
                        fillMode: Image.PreserveAspectCrop; smooth: true; cache: false
                    }
                }
                Rectangle {
                    width: parent.width; height: 220 * Style.uiScaleRatio
                    radius: Style.radiusM; color: Color.mSurface; clip: true
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    Flickable {
                        id: ocrFlick; anchors.fill: parent; anchors.margins: Style.marginS
                        contentHeight: ocrText.implicitHeight; clip: true
                        interactive: ocrText.implicitHeight > ocrFlick.height
                        TextEdit {
                            id: ocrText; width: ocrFlick.width; text: root.ocrResult
                            wrapMode: TextEdit.WordWrap
                            color: Color.mOnSurface; font.pointSize: Style.fontSizeS
                            horizontalAlignment: /[\u0600-\u06FF\u0590-\u05FF]/.test(root.ocrResult)
                                ? TextEdit.AlignRight : TextEdit.AlignLeft
                            selectByMouse: true; selectionColor: Color.mPrimary; selectedTextColor: Color.mOnPrimary
                            WheelHandler { onWheel: event => { ocrFlick.flick(0, event.angleDelta.y * 5); event.accepted = false } }
                        }
                    }
                }
                Row {
                    width: parent.width; spacing: Style.marginXS
                    Flow {
                        width: parent.width - _ocrClearBtn.width - Style.marginS
                        spacing: Style.marginXS
                        Rectangle {
                            visible: root.ocrType === "url" || root.ocrType === "email"
                            height: 26; width: _ocrOpenRow.implicitWidth + Style.marginS * 2; radius: Style.radiusS
                            color: _ocrOpenMA.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                            Row {
                                id: _ocrOpenRow; anchors.centerIn: parent; spacing: Style.marginXS
                                NIcon { icon: root.ocrType === "email" ? "mail" : "external-link"; color: _ocrOpenMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                                NText { text: root.ocrType === "email" ? pluginApi?.tr("panel.composeMail") : pluginApi?.tr("panel.openUrl"); color: _ocrOpenMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS }
                            }
                            MouseArea {
                                id: _ocrOpenMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.ocrType === "email" ? Qt.openUrlExternally("mailto:" + root.ocrEmail) : Qt.openUrlExternally(root.ocrUrl)
                            }
                        }
                        Rectangle {
                            height: 26; width: _ocrSearchRow.implicitWidth + Style.marginS * 2; radius: Style.radiusS
                            color: _ocrSearchMA.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                            Row {
                                id: _ocrSearchRow; anchors.centerIn: parent; spacing: Style.marginXS
                                NIcon { icon: "search"; color: _ocrSearchMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                                NText { text: pluginApi?.tr("panel.searchText"); color: _ocrSearchMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS }
                            }
                            MouseArea {
                                id: _ocrSearchMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://www.google.com/search?q=" + encodeURIComponent(root.ocrResult.trim()))
                            }
                        }
                        Rectangle {
                            height: 26; width: _ocrCopyRow.implicitWidth + Style.marginS * 2; radius: Style.radiusS
                            color: _ocrCopyMA.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                            Row {
                                id: _ocrCopyRow; anchors.centerIn: parent; spacing: Style.marginXS
                                NIcon { icon: "copy"; color: _ocrCopyMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8 }
                                NText { text: pluginApi?.tr("panel.copy"); color: _ocrCopyMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS }
                            }
                            MouseArea {
                                id: _ocrCopyMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.copyToClipboard(root.ocrResult); ToastService.showNotice(pluginApi?.tr("panel.copyText")) }
                            }
                        }
                    }
                    Rectangle {
                        id: _ocrClearBtn
                        height: 26; width: _ocrClearRow.implicitWidth + Style.marginM * 2; radius: Style.radiusS
                        color: _ocrClearMA.containsMouse
                            ? Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.15)
                            : Color.mSurfaceVariant
                        border.color: Color.mError
                        border.width: Style.capsuleBorderWidth || 1
                        Row {
                            id: _ocrClearRow; anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { icon: "trash"; color: _ocrClearMA.containsMouse ? Color.mError : Color.mOnSurfaceVariant; scale: 0.8 }
                            NText { text: pluginApi?.tr("panel.clearResult"); color: _ocrClearMA.containsMouse ? Color.mError : Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                        }
                        MouseArea {
                            id: _ocrClearMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pluginApi) {
                                    pluginApi.pluginSettings.ocrResult      = ""
                                    pluginApi.pluginSettings.ocrCapturePath = ""
                                    pluginApi.pluginSettings.stateActiveTool = ""
                                    pluginApi.saveSettings()
                                }
                            }
                            onEntered: TooltipService.show(_ocrClearMA, pluginApi?.tr("panel.clearResult"))
                            onExited:  TooltipService.hide()
                        }
                    }
                }
                Row {
                    width: parent.width; spacing: Style.marginS
                    Rectangle { width: 32; height: 1; color: Color.mOnSurfaceVariant; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter }
                    NIcon { icon: "world"; color: Color.mOnSurfaceVariant; scale: 0.75 }
                    NText { text: pluginApi?.tr("ocr.translateSection"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                    Rectangle {
                        height: 1; color: Color.mOnSurfaceVariant; opacity: 0.25; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 32 - Style.marginS * 3 - 16 - _transSecLabel.implicitWidth
                    }
                    NText { id: _transSecLabel; visible: false; text: pluginApi?.tr("ocr.translateSection") }
                }
                NText {
                    visible: !root.transAvailable; width: parent.width
                    text: pluginApi?.tr("ocr.noTranslateTool")
                    color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; wrapMode: Text.WordWrap
                }
                Column {
                    width: parent.width; spacing: Style.marginS
                    visible: root.transAvailable
                    Row {
                        width: parent.width; spacing: Style.marginS
                        NComboBox {
                            width:        parent.width - translateBtn.width - Style.marginS
                            label:        pluginApi?.tr("panel.translateTo")
                            model:        root.transLangModel
                            currentKey:   root.selectedTransLang
                            minimumWidth: 100; popupHeight: 220
                            onSelected:   (key) => { root.selectedTransLang = key }
                        }
                        Rectangle {
                            id: translateBtn
                            height: 34; width: 34; radius: Style.radiusM
                            color: transBtnMa.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                            NIcon { anchors.centerIn: parent; icon: "world"; color: transBtnMa.containsMouse ? Color.mOnPrimary : Color.mOnSurface }
                            MouseArea {
                                id: transBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.runTranslate(root.ocrResult, root.selectedTransLang)
                                onEntered: TooltipService.show(transBtnMa, pluginApi?.tr("panel.translate"))
                                onExited:  TooltipService.hide()
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 140 * Style.uiScaleRatio
                        radius: Style.radiusM; color: Color.mSurface; clip: true
                        border.color: Style.capsuleBorderColor || "transparent"
                        border.width: Style.capsuleBorderWidth || 1
                        visible: root.translateResult !== ""
                        Flickable {
                            id: trFlick; anchors.fill: parent; anchors.margins: Style.marginS
                            contentHeight: trText.implicitHeight; clip: true
                            interactive: trText.implicitHeight > trFlick.height
                            TextEdit {
                                id: trText; width: trFlick.width; text: root.translateResult
                                color: Color.mOnSurface; font.pointSize: Style.fontSizeS; wrapMode: TextEdit.WordWrap
                                horizontalAlignment: /[\u0600-\u06FF\u0590-\u05FF]/.test(root.translateResult)
                                    ? TextEdit.AlignRight : TextEdit.AlignLeft
                                selectByMouse: true; selectionColor: Color.mPrimary; selectedTextColor: Color.mOnPrimary
                                WheelHandler { onWheel: event => { trFlick.flick(0, event.angleDelta.y * 5); event.accepted = false } }
                            }
                        }
                        NIcon {
                            icon: "copy"; color: Color.mOnSurfaceVariant
                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.marginS
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.copyToClipboard(root.translateResult); ToastService.showNotice(pluginApi?.tr("panel.translationCopied")) }
                            }
                        }
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginM
                visible: root.viewedTool === "qr" && root.qrResult !== ""
                Row {
                    width: parent.width; spacing: Style.marginS
                    NIcon { icon: "qrcode"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                    NText { text: "QR"; color: Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle {
                    width: parent.width
                    height: Math.min(qrThumb.implicitHeight * (parent.width / Math.max(qrThumb.implicitWidth, 1)), 160 * Style.uiScaleRatio)
                    radius: Style.radiusM; color: "transparent"; clip: true
                    border.color: Style.capsuleBorderColor || "transparent"
                    border.width: Style.capsuleBorderWidth || 1
                    visible: root.qrCapturePath !== "" && root.qrResult !== "" && qrThumb.status === Image.Ready
                    Image { id: qrThumb; anchors.fill: parent; source: (root.qrCapturePath !== "" && root.qrResult !== "") ? ("file://" + root.qrCapturePath) : ""; fillMode: Image.PreserveAspectFit; smooth: true; cache: false }
                }
                Rectangle {
                    height: 26; width: qrBadge.implicitWidth + Style.marginM * 2; radius: Style.radiusS
                    color: Color.mPrimaryContainer || Color.mSurfaceVariant
                    NText {
                        id: qrBadge; anchors.centerIn: parent
                        text: root.qrType === "url"     ? "🔗 URL"
                            : root.qrType === "wifi"    ? "📶 WiFi"
                            : root.qrType === "contact" ? "👤 Contact"
                            : root.qrType === "email"   ? "✉️ Email"
                            : root.qrType === "otp"     ? "🔐 OTP"
                            :                             "📄 Text"
                        color: Color.mOnPrimaryContainer || Color.mOnSurface
                        font.weight: Font.Bold; pointSize: Style.fontSizeXS
                    }
                }
                Column {
                    width: parent.width; spacing: Style.marginS
                    visible: root.qrType === "wifi"
                    Rectangle {
                        width: parent.width; height: 38; radius: Style.radiusM; color: Color.mSurface
                        border.color: Style.capsuleBorderColor || "transparent"; border.width: Style.capsuleBorderWidth || 1
                        Row { anchors.fill: parent; anchors.margins: Style.marginS; spacing: Style.marginS
                            NIcon { icon: "wifi"; color: Color.mPrimary }
                            NText { text: root.qrWifiName || "Unknown"; color: Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 38; radius: Style.radiusM
                        color:        wph.containsMouse ? Color.mHover : Color.mSurface
                        border.color: Style.capsuleBorderColor || "transparent"; border.width: Style.capsuleBorderWidth || 1
                        Row { anchors.fill: parent; anchors.margins: Style.marginS; spacing: Style.marginS
                            NIcon { icon: "key"; color: Color.mOnSurfaceVariant }
                            NText { text: root.qrWifiPass ? "••••••••" : pluginApi?.tr("panel.noPassword"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeS }
                            NIcon { icon: "copy"; color: Color.mOnSurfaceVariant }
                        }
                        MouseArea {
                            id: wph; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.qrWifiPass !== ""
                            onClicked: { root.copyToClipboard(root.qrWifiPass); ToastService.showNotice(pluginApi?.tr("panel.passwordCopied")) }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 120 * Style.uiScaleRatio
                    radius: Style.radiusM; color: Color.mSurface; clip: true
                    border.color: Style.capsuleBorderColor || "transparent"; border.width: Style.capsuleBorderWidth || 1
                    visible: root.qrType !== "wifi"
                    Flickable {
                        id: qrFlick; anchors.fill: parent; anchors.margins: Style.marginS
                        contentHeight: qrText.implicitHeight; clip: true
                        interactive: qrText.implicitHeight > qrFlick.height
                        TextEdit {
                            id: qrText; width: qrFlick.width; text: root.qrResult; wrapMode: TextEdit.WordWrap
                            color: Color.mOnSurface; font.pointSize: Style.fontSizeS
                            selectByMouse: true; selectionColor: Color.mPrimary; selectedTextColor: Color.mOnPrimary
                            WheelHandler { onWheel: event => { qrFlick.flick(0, event.angleDelta.y * 5); event.accepted = false } }
                        }
                    }
                }
                Row {
                    width: parent.width; spacing: Style.marginS
                    Rectangle {
                        width: parent.width - 46; height: 38; radius: Style.radiusM
                        color:        qah.containsMouse ? Color.mPrimary : Color.mSurface
                        border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth || 1
                        Row { anchors.centerIn: parent; spacing: Style.marginS
                            NIcon { icon: root.qrType === "url" ? "external-link" : root.qrType === "email" ? "mail" : "copy"; color: qah.containsMouse ? Color.mOnPrimary : Color.mPrimary }
                            NText { text: root.qrType === "url" ? pluginApi?.tr("panel.openUrl") : root.qrType === "email" ? pluginApi?.tr("panel.composeEmail") : pluginApi?.tr("panel.copy"); color: qah.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                        }
                        MouseArea {
                            id: qah; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.qrType === "url" || root.qrType === "email")
                                    Qt.openUrlExternally(root.qrResult)
                                else {
                                    root.copyToClipboard(root.qrResult)
                                    ToastService.showNotice(pluginApi?.tr("panel.copied"))
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 38; height: 38; radius: Style.radiusM
                        color:        qch.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurface
                        border.color: qch.containsMouse ? Color.mError || "#f44336" : (Style.capsuleBorderColor || "transparent")
                        border.width: Style.capsuleBorderWidth || 1
                        NIcon { anchors.centerIn: parent; icon: "trash"; color: qch.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant }
                        MouseArea {
                            id: qch; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pluginApi) {
                                    pluginApi.pluginSettings.qrResult       = ""
                                    pluginApi.pluginSettings.stateActiveTool = ""
                                    pluginApi.saveSettings()
                                }
                            }
                        }
                    }
                }
            }
            Column {
                width: parent.width; spacing: Style.marginM
                visible: root.viewedTool === "palette" && root.paletteColors.length > 0
                Row {
                    width: parent.width; spacing: Style.marginS
                    NIcon { icon: "palette"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                    NText { text: pluginApi?.tr("palette.title"); color: Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                }
                Flow {
                    width: parent.width; spacing: Style.marginS
                    Repeater {
                        model: root.paletteColors
                        delegate: Rectangle {
                            width:  (mainCol.width - Style.marginS * 2) / 3 - Style.marginS
                            height: width * 0.7; radius: Style.radiusM; color: modelData
                            border.color: swatchBtn.containsMouse ? Color.mPrimary : (Style.capsuleBorderColor || "transparent")
                            border.width: swatchBtn.containsMouse ? 2 : (Style.capsuleBorderWidth || 1)
                            NText { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.toUpperCase(); pointSize: Style.fontSizeXS; color: "white"; style: Text.Outline; styleColor: "#00000066" }
                            MouseArea {
                                id: swatchBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.copyToClipboard(modelData); ToastService.showNotice(pluginApi?.tr("panel.colorCopied", { color: modelData })) }
                                onEntered: TooltipService.show(swatchBtn, modelData.toUpperCase() + " — " + pluginApi?.tr("panel.clickToCopy"))
                                onExited:  TooltipService.hide()
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 36; radius: Style.radiusM
                    color:        cssBtn.containsMouse ? Color.mPrimary : Color.mSurface
                    border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth || 1
                    Row { anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "copy"; color: cssBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary }
                        NText { text: pluginApi?.tr("palette.cssVars"); color: cssBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: cssBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var css = root.paletteColors.map(function(c, i) { return "--color-" + (i + 1) + ": " + c + ";" }).join("\n")
                            root.copyToClipboard(css)
                            ToastService.showNotice(pluginApi?.tr("panel.cssVarsCopied"))
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: 36; radius: Style.radiusM
                    color:        hexBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                    border.color: Style.capsuleBorderColor || "transparent"; border.width: Style.capsuleBorderWidth || 1
                    Row { anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "list"; color: hexBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant }
                        NText { text: pluginApi?.tr("palette.hexList"); color: hexBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: hexBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.copyToClipboard(root.paletteColors.join("\n")); ToastService.showNotice(pluginApi?.tr("panel.hexListCopied")) }
                    }
                }
                Rectangle {
                    width: parent.width; height: 36; radius: Style.radiusM
                    color:        palClr.containsMouse ? Color.mErrorContainer || "#ffcdd2" : Color.mSurface
                    border.color: palClr.containsMouse ? Color.mError || "#f44336" : (Style.capsuleBorderColor || "transparent")
                    border.width: Style.capsuleBorderWidth || 1
                    Row { anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "trash"; color: palClr.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant }
                        NText { text: pluginApi?.tr("panel.clear"); color: palClr.containsMouse ? Color.mError || "#f44336" : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: palClr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pluginApi) { pluginApi.pluginSettings.paletteColors = []; pluginApi.saveSettings() }
                            root.viewedTool = ""
                        }
                    }
                }
            }
        } // mainCol
    } // panelContainer
    component ToolBtn: Item {
        id: btn
        property string icon:    ""
        property string label:   ""
        property string tooltip: ""
        property bool   active:  false
        property bool   focused: false
        property bool   running: false
        signal triggered()
        Column {
            anchors.centerIn: parent; spacing: Style.marginXS
            Rectangle {
                width:  Math.min(btn.width - 4, 44)
                height: Math.min(btn.width - 4, 44)
                radius: Style.radiusM
                anchors.horizontalCenter: parent.horizontalCenter
                color:        ba.containsMouse ? Color.mHover : Color.mSurface
                border.color: btn.active  ? Color.mPrimary
                            : btn.focused ? Color.mSecondary || Color.mPrimary
                            :               Style.capsuleBorderColor || "transparent"
                border.width: (btn.active || btn.focused) ? 2 : (Style.capsuleBorderWidth || 1)
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color:   Color.mPrimary
                    opacity: btn.active ? 0.15 : btn.focused ? 0.08 : 0
                }
                NIcon {
                    anchors.centerIn: parent; icon: btn.icon
                    color: btn.active  ? Color.mPrimary
                         : btn.focused ? Color.mSecondary || Color.mPrimary
                         :               Color.mOnSurface
                }
                MouseArea {
                    id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !btn.running
                    onClicked:  btn.triggered()
                    onEntered:  TooltipService.show(btn, btn.tooltip !== "" ? btn.tooltip : btn.label)
                    onExited:   TooltipService.hide()
                }
            }
            NText {
                text:               btn.label
                pointSize:          Style.fontSizeXS
                color:              btn.active  ? Color.mPrimary
                                  : btn.focused ? Color.mSecondary || Color.mPrimary
                                  :               Color.mOnSurfaceVariant
                anchors.horizontalCenter: parent.horizontalCenter
                width:              btn.width
                horizontalAlignment: Text.AlignHCenter
                elide:              Text.ElideRight
            }
        }
    }
}
