import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "overlays"
import "widgets"
import "utils/utils.js" as U
Item {
    id: root
    property var pluginApi: null
    readonly property var  geometryPlaceholder:  panelContainer
    readonly property bool allowAttach:          true
    property real contentPreferredWidth:         340 * Style.uiScaleRatio
    property real contentPreferredHeight:        mainCol.implicitHeight + Style.marginL * 2
    anchors.fill: parent
    property bool _settingsLoading: false
    onPluginApiChanged: {
        if (pluginApi) {
            _settingsLoading = true
            var saved = pluginApi.pluginSettings.selectedOcrLang
            if (saved && saved !== "") root.selectedOcrLang = saved
            _settingsLoading = false
            _resolveMainInstance()
            mainInstancePoller.start()
        } else {
            mainInstancePoller.stop()
            root.mainInstance = null
        }
    }
    property var mainInstance: null
    Connections {
        target: pluginApi
        ignoreUnknownSignals: true
        function onMainInstanceChanged() { root._resolveMainInstance() }
    }
    function _resolveMainInstance() {
        if (!pluginApi) { mainInstancePoller.stop(); return }
        if (pluginApi?.mainInstance) {
            root.mainInstance = pluginApi.mainInstance
            mainInstancePoller.stop()
            Logger.i("ScreenToolkit", "mainInstance resolved: " + root.mainInstance)
        }
    }
    Timer {
        id: mainInstancePoller
        interval: 200; repeat: true
        property int _attempts: 0
        readonly property int _maxAttempts: 25
        onTriggered: {
            _attempts++
            root._resolveMainInstance()
            if (_attempts >= _maxAttempts && root.mainInstance === null) {
                Logger.w("ScreenToolkit", "mainInstance not resolved after 5s")
                stop()
            }
        }
        onRunningChanged: if (!running) _attempts = 0
    }
    readonly property bool   isRunning:    mainInstance?.isRunning    ?? false
    readonly property string activeTool:   mainInstance?.activeTool   ?? ""
    readonly property bool   mirrorActive: mainInstance?.mirrorVisible ?? false
    readonly property string recordState:  mainInstance?.recordState   ?? ""
    readonly property bool   isRecording:  recordState === "recording"
    readonly property bool   isConverting: recordState === "converting"
    readonly property bool   isDone:       recordState === "done"
    readonly property string recordFormat: mainInstance?.recordFormat  ?? "gif"
    property string          recordPath:   ""
    property string          _thumbBust:   ""
    readonly property bool   hasResult:    activeTool !== "" && !isRunning
    readonly property bool   _isNiri:      mainInstance?.isNiri     ?? false
    readonly property bool   _isHyprland:  mainInstance?.isHyprland ?? false
    readonly property string _savedHex:     mainInstance?.resultHex     ?? ""
    readonly property string _savedOcr:     mainInstance?.ocrResult     ?? ""
    readonly property string _savedQr:      mainInstance?.qrResult      ?? ""
    readonly property var    _savedPalette: mainInstance?.paletteColors  ?? []
    readonly property var    installedLangs:  mainInstance?.installedLangs  ?? ["eng"]
    property string          selectedOcrLang: "eng"
    onSelectedOcrLangChanged: {
        if (_settingsLoading) return
        if (pluginApi) {
            pluginApi.pluginSettings.selectedOcrLang = selectedOcrLang
            pluginApi.saveSettings()
        }
    }
    onInstalledLangsChanged: {
        if (installedLangs.length > 0 && !installedLangs.includes(root.selectedOcrLang))
            root.selectedOcrLang = installedLangs[0]
    }
    readonly property var ocrLangModel: {
        var out = []
        for (var i = 0; i < root.installedLangs.length; i++)
            out.push({ key: root.installedLangs[i], name: root.installedLangs[i].toUpperCase() })
        return out
    }
    onActiveToolChanged: {
        if (activeTool === "ocr" || activeTool === "qr"
                || activeTool === "colorpicker" || activeTool === "palette")
            root.viewedTool = activeTool
        if (activeTool === "record" && root.isRecording)
            root.viewedTool = "record"
    }
    onRecordStateChanged: {
        if (recordState !== "") {
            viewedTool = "record"
            if (mainInstance) root.recordPath = mainInstance.recordPath
            if (recordState === "done" && recordFormat === "mp4")
                root._thumbBust = Date.now().toString()
        } else if (viewedTool === "record") {
            viewedTool  = "record"
            viewedTool = ""
            root.recordPath = ""
            root._thumbBust = ""
            root._panelWasShown = false
        }
    }
    onVisibleChanged: {
        if (visible) {
            root._panelWasShown = true
            if (isDone && viewedTool === "record") {
                root.viewedTool = ""
                if (mainInstance) mainInstance.activeTool = ""
            }
        } else {
            if (viewedTool !== "record") {
                root.viewedTool  = ""
                root.focusedTool = -1
                if (mainInstance) mainInstance.activeTool = ""
                } else if (recordState === "" && !isRunning) {
                    root.viewedTool  = ""
                    root.focusedTool = -1
                    if (mainInstance) mainInstance.activeTool = ""
            }
        }
    }
    property bool _panelWasShown: false
    property int    focusedTool: -1
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
        if (root.focusedTool < 0 || root.focusedTool >= root.toolDefs.length) return
        var t = root.toolDefs[root.focusedTool].tool
        if (root.isRunning) { Logger.w("ScreenToolkit", "blocked: isRunning"); return }
        root.viewedTool = t
        if (t === "colorpicker" && root._savedHex !== "")         return
        if (t === "palette"     && root._savedPalette.length > 0) return
        if (t === "qr"          && root._savedQr !== "")          return
        if (t === "mirror" && root.mirrorActive) return
        if (t === "record") { if (root.isRecording) root.mainInstance?.runRecordStop(); return }
        if (t === "ocr" || t === "pin" || t === "annotate") return
        if      (t === "colorpicker") root.mainInstance?.runColorPicker()
        else if (t === "qr")          root.mainInstance?.runQr()
        else if (t === "lens")        root.mainInstance?.runLens()
        else if (t === "measure")     root.mainInstance?.runMeasure()
        else if (t === "palette")     root.mainInstance?.runPalette()
        else if (t === "mirror")      root.mainInstance?.runMirror()
    }
    onActiveFocusChanged: if (activeFocus) toolBar.forceActiveFocus()
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
                width: parent.width
                height: toolsCol.implicitHeight + Style.marginM * 2
                color: Color.mSurfaceVariant; radius: Style.radiusL; focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Left)       { root.focusedTool = root.focusedTool < 0 ? 0 : (root.focusedTool + 9) % 10; event.accepted = true }
                    else if (event.key === Qt.Key_Right) { root.focusedTool = root.focusedTool < 0 ? 0 : (root.focusedTool + 1) % 10; event.accepted = true }
                    else if (event.key === Qt.Key_Up)    { root.focusedTool = root.focusedTool >= 5 ? root.focusedTool - 5 : (root.focusedTool < 0 ? 0 : root.focusedTool); event.accepted = true }
                    else if (event.key === Qt.Key_Down)  { root.focusedTool = root.focusedTool < 0 ? 0 : (root.focusedTool < 5 ? root.focusedTool + 5 : root.focusedTool); event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.triggerFocused(); event.accepted = true }
                }
                Column {
                    id: toolsCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.marginM }
                    spacing: Style.marginS
                    readonly property int btnSize: Math.floor((width - Style.marginS * 4) / 5)
                    Row {
                        spacing: Style.marginS
                        anchors.horizontalCenter: parent.horizontalCenter
                        Repeater {
                            model: root.toolDefs.slice(0, 5)
                            delegate: ToolBtn {
                                readonly property int myIdx: index
                                icon: modelData.icon; label: modelData.label; tooltip: modelData.tooltip
                                active:    root.activeTool  === modelData.tool
                                focused:   root.focusedTool === myIdx
                                running:   root.isRunning
                                recording: root.isRecording && modelData.tool === "record"
                                hasResult: modelData.tool === "colorpicker" ? root._savedHex !== ""
                                         : modelData.tool === "palette"     ? root._savedPalette.length > 0
                                         : modelData.tool === "ocr"         ? root._savedOcr !== ""
                                         : modelData.tool === "qr"          ? root._savedQr !== ""
                                         : false
                                width: toolsCol.btnSize; height: toolsCol.btnSize + 18
                                onTriggered: { root.focusedTool = myIdx; root.viewedTool = modelData.tool; root.triggerFocused() }
                            }
                        }
                    }
                    Row {
                        spacing: Style.marginS
                        anchors.horizontalCenter: parent.horizontalCenter
                        Repeater {
                            model: root.toolDefs.slice(5, 10)
                            delegate: ToolBtn {
                                readonly property int myIdx: index + 5
                                icon: modelData.icon; label: modelData.label; tooltip: modelData.tooltip
                                active:    root.activeTool  === modelData.tool
                                focused:   root.focusedTool === myIdx
                                running:   root.isRunning
                                recording: root.isRecording && modelData.tool === "record"
                                hasResult: modelData.tool === "record" ? root.isDone
                                         : modelData.tool === "mirror" ? root.mirrorActive
                                         : modelData.tool === "pin"    ? (mainInstance?.hasPins ?? false)
                                         : false
                                width: toolsCol.btnSize; height: toolsCol.btnSize + 18
                                onTriggered: { root.focusedTool = myIdx; root.viewedTool = modelData.tool; root.triggerFocused() }
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 56
                color: Color.mSurfaceVariant; radius: Style.radiusL
                visible: root.isRunning
                Row {
                    anchors.centerIn: parent; spacing: Style.marginM
                    NIcon {
                        icon: "loader"; color: Color.mPrimary
                        RotationAnimation on rotation {
                            running: root.isRunning
                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                        }
                    }
                    NText { text: pluginApi?.tr("panel.running"); color: Color.mOnSurfaceVariant }
                }
            }
            Rectangle {
                property bool _shown: root.viewedTool === "record" && root.isRecording
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; height: 38; radius: Style.radiusM
                color: recPanelStopBtn.containsMouse ? Color.mError : Color.mSurfaceVariant
                Row {
                    anchors.centerIn: parent; spacing: Style.marginS
                    Rectangle {
                        width: Style.marginM; height: Style.marginM; radius: Style.radiusXXXS
                        color: recPanelStopBtn.containsMouse ? "white" : Color.mError
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    NText { text: pluginApi?.tr("record.stop"); color: recPanelStopBtn.containsMouse ? "white" : Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                }
                MouseArea { id: recPanelStopBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mainInstance?.runRecordStop() }
            }
            Rectangle {
                property bool _shown: root.viewedTool === "record" && root.isConverting
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; height: 38; radius: Style.radiusM
                color: Color.mSurfaceVariant
                Row {
                    anchors.centerIn: parent; spacing: Style.marginS
                    NIcon { icon: "loader"; color: Color.mOnSurface; anchors.verticalCenter: parent.verticalCenter
                        RotationAnimation on rotation { running: root.isConverting; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                    }
                    NText {
                        text: root.recordFormat === "mp4" ? pluginApi?.tr("record.savingMp4") : pluginApi?.tr("record.convertingGif")
                        color: Color.mOnSurface; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            Column {
                property bool _shown: root.viewedTool === "record" && root.isDone
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; spacing: Style.marginS
                Rectangle {
                    width: parent.width; height: Math.round(parent.width * 9 / 16)
                    radius: Style.radiusM; color: Color.mSurfaceVariant; clip: true
                    AnimatedImage {
                        anchors.fill: parent
                        visible: root.recordFormat === "gif" && root.recordPath !== ""
                        source:  root.recordFormat === "gif" && root.recordPath !== "" ? "file://" + root.recordPath : ""
                        fillMode: Image.PreserveAspectFit; smooth: true; cache: false; playing: true
                    }
                    Image {
                        anchors.fill: parent; visible: root.recordFormat === "mp4"
                        source: root.recordFormat === "mp4" && root._thumbBust !== ""
                            ? "file:///tmp/screen-toolkit-record-thumb.png?" + root._thumbBust : ""
                        fillMode: Image.PreserveAspectFit; smooth: true; cache: false
                    }
                }
                Row {
                    width: parent.width; spacing: Style.marginS
                    Rectangle {
                        height: 38; radius: Style.radiusM; width: parent.width - 44 - Style.marginS
                        color: recSaveBtn.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                        Row {
                            anchors.centerIn: parent; spacing: Style.marginS
                            NIcon { icon: "device-floppy"; color: recSaveBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface; anchors.verticalCenter: parent.verticalCenter }
                            NText {
                                text: root.recordFormat === "mp4" ? pluginApi?.tr("record.saveMp4") : pluginApi?.tr("record.saveGif")
                                color: recSaveBtn.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                                font.weight: Font.Bold; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { id: recSaveBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mainInstance?.runRecordSave() }
                    }
                    Rectangle {
                        width: 38; height: 38; radius: Style.radiusM
                        color: recDiscardBtn.containsMouse ? Color.mError : Color.mSurface
                        border.color: recDiscardBtn.containsMouse ? Color.mError : Style.capsuleBorderColor
                        border.width: Style.capsuleBorderWidth
                        NIcon { anchors.centerIn: parent; icon: "trash"; color: recDiscardBtn.containsMouse ? Color.mError : Color.mOnSurfaceVariant }
                        MouseArea {
                            id: recDiscardBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mainInstance?.runRecordDiscard()
                            onEntered: TooltipService.show(recDiscardBtn, pluginApi?.tr("record.discard"))
                            onExited: TooltipService.hide()
                        }
                    }
                }
            }
            Row {
                property bool _shown: root.viewedTool === "annotate" && !root.isRunning
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; spacing: Style.marginS
                Rectangle {
                    width: (parent.width - Style.marginS * 2) / 3; height: 38; radius: Style.radiusM
                    color: annotRegionBtn.containsMouse ? Color.mPrimary : Color.mSurface
                    border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth
                    Row { anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon { icon: "crop"; color: annotRegionBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; scale: 0.85 }
                        NText { text: pluginApi?.tr("annotate.region"); color: annotRegionBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeXS }
                    }
                    MouseArea {
                        id: annotRegionBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runAnnotate()
                        onEntered: TooltipService.show(annotRegionBtn, pluginApi?.tr("annotate.regionTooltip"))
                        onExited: TooltipService.hide()
                    }
                }
                Rectangle {
                    width: (parent.width - Style.marginS * 2) / 3; height: 38; radius: Style.radiusM
                    enabled: root._isHyprland
                    color: !enabled ? Color.mSurfaceVariant : (annotWinBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface)
                    border.color: Style.capsuleBorderColor; border.width: Style.capsuleBorderWidth; opacity: enabled ? 1.0 : 0.5
                    Row { anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon {
                            icon: "app-window"
                            color: !parent.parent.enabled ? Color.mOnSurfaceVariant : (annotWinBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant)
                            scale: 0.85
                        }
                        NText {
                            text: pluginApi?.tr("annotate.window")
                            color: !parent.parent.enabled ? Color.mOnSurfaceVariant : (annotWinBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant)
                            font.weight: Font.Bold; pointSize: Style.fontSizeXS
                        }
                    }
                    MouseArea {
                        id: annotWinBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (parent.enabled) root.mainInstance?.runAnnotateActiveWindow()
                        onEntered: TooltipService.show(annotWinBtn, parent.enabled ? pluginApi?.tr("annotate.windowTooltip") : pluginApi?.tr("annotate.windowHyprlandOnly"))
                        onExited: TooltipService.hide()
                    }
                }
                Rectangle {
                    width: (parent.width - Style.marginS * 2) / 3; height: 38; radius: Style.radiusM
                    color: annotFsBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                    border.color: Style.capsuleBorderColor; border.width: Style.capsuleBorderWidth
                    Row { anchors.centerIn: parent; spacing: Style.marginXS
                        NIcon { icon: "maximize"; color: annotFsBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; scale: 0.85 }
                        NText { text: pluginApi?.tr("annotate.fullscreen"); color: annotFsBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeXS }
                    }
                    MouseArea {
                        id: annotFsBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runAnnotateFullscreen()
                        onEntered: TooltipService.show(annotFsBtn, pluginApi?.tr("annotate.fullscreenTooltip"))
                        onExited: TooltipService.hide()
                    }
                }
            }
            Column {
                property bool _shown: root.viewedTool === "ocr" && !root.isRunning
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; spacing: Style.marginS
                Row {
                    width: parent.width; spacing: Style.marginS
                    visible: root.installedLangs.length > 0
                    NText { id: langLabel; text: pluginApi?.tr("panel.lang"); color: Color.mOnSurface; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                    Flow {
                        visible: root.installedLangs.length <= 4
                        width: parent.width - langLabel.implicitWidth - scanBtnInline.width - Style.marginS * 2
                        spacing: Style.marginXS; anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: root.installedLangs
                            delegate: Rectangle {
                                height: 24; width: chipLangText.implicitWidth + Style.marginM * 2; radius: Style.radiusS
                                color: root.selectedOcrLang === modelData ? Color.mPrimary : (chipMA.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                                NText { id: chipLangText; anchors.centerIn: parent; text: modelData.toUpperCase(); color: root.selectedOcrLang === modelData ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS; font.weight: root.selectedOcrLang === modelData ? Font.Bold : Font.Normal }
                                MouseArea { id: chipMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedOcrLang = modelData }
                            }
                        }
                    }
                    NComboBox {
                        visible: root.installedLangs.length > 4
                        width: parent.width - langLabel.implicitWidth - scanBtnInline.width - Style.marginS * 2
                        model: root.ocrLangModel; currentKey: root.selectedOcrLang; minimumWidth: 100; popupHeight: 220
                        onSelected: function(key) { root.selectedOcrLang = key }
                    }
                    Rectangle {
                        id: scanBtnInline; height: 26; width: _scanRow.implicitWidth + Style.marginM * 2; radius: Style.radiusS
                        color: scanBtn.containsMouse ? Color.mPrimary : Color.mSurface
                        border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth
                        anchors.verticalCenter: parent.verticalCenter
                        Row { id: _scanRow; anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { icon: "scan"; color: scanBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; scale: 0.8 }
                            NText { text: pluginApi?.tr("panel.scan"); color: scanBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeXS }
                        }
                        MouseArea { id: scanBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mainInstance?.runOcr(root.selectedOcrLang) }
                    }
                }
            }
            Row {
                property bool _shown: root.viewedTool === "pin" && !root.isRunning
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; spacing: Style.marginS
                Rectangle {
                    width: (parent.width - Style.marginS) / 2; height: 38; radius: Style.radiusM
                    color: pinScreenBtn.containsMouse ? Color.mPrimary : Color.mSurface
                    border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth
                    Row { anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "crosshair"; color: pinScreenBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary }
                        NText { text: pluginApi?.tr("panel.pinCapture"); color: pinScreenBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: pinScreenBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runPin()
                        onEntered: TooltipService.show(pinScreenBtn, pluginApi?.tr("tooltips.pinRegion"))
                        onExited: TooltipService.hide()
                    }
                }
                Rectangle {
                    width: (parent.width - Style.marginS) / 2; height: 38; radius: Style.radiusM
                    color: pinFileBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                    border.color: Style.capsuleBorderColor; border.width: Style.capsuleBorderWidth
                    Row { anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: "folder-open"; color: pinFileBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant }
                        NText { text: pluginApi?.tr("panel.pinFile"); color: pinFileBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea {
                        id: pinFileBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mainInstance?.runPinFromFile()
                        onEntered: TooltipService.show(pinFileBtn, pluginApi?.tr("tooltips.pinImage"))
                        onExited: TooltipService.hide()
                    }
                }
            }
            Column {
                property bool _shown: root.viewedTool === "record" && !root.isRunning && !root.isRecording && !root.isConverting && !root.isDone
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; spacing: Style.marginS
                Flow {
                    width: parent.width; spacing: Style.marginS
                    NText { text: pluginApi?.tr("panel.format"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS; height: 26; verticalAlignment: Text.AlignVCenter }
                    Repeater {
                        model: [
                            { id: "gif", label: "GIF", hint: "· " + (pluginApi?.pluginSettings?.gifMaxSeconds ?? 30) + "s" },
                            { id: "mp4", label: "MP4", hint: "" }
                        ]
                        delegate: Rectangle {
                            height: 26; width: fmtLabel.implicitWidth + (modelData.hint !== "" ? fmtHint.implicitWidth + Style.marginXS : 0) + Style.marginM * 2 + Style.marginS; radius: Style.radiusS
                            color: root.selectedRecordFormat === modelData.id ? Color.mPrimary : (fmtArea.containsMouse ? Color.mHover : Color.mSurfaceVariant)
                            Row { anchors.centerIn: parent; spacing: Style.marginXS
                                NText { id: fmtLabel; text: modelData.label; color: root.selectedRecordFormat === modelData.id ? Color.mOnPrimary : Color.mOnSurface; pointSize: Style.fontSizeXS; font.weight: root.selectedRecordFormat === modelData.id ? Font.Bold : Font.Normal }
                                NText { id: fmtHint; visible: modelData.hint !== ""; text: modelData.hint; color: root.selectedRecordFormat === modelData.id ? Qt.rgba(1,1,1,0.65) : Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
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
                            id: audioOutArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordAudioOutput = !root.recordAudioOutput
                            onEntered: TooltipService.show(audioOutArea, pluginApi?.tr("tooltips.systemAudio"))
                            onExited: TooltipService.hide()
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
                            id: micArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordAudioInput = !root.recordAudioInput
                            onEntered: TooltipService.show(micArea, pluginApi?.tr("tooltips.microphone"))
                            onExited: TooltipService.hide()
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
                            id: cursorArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.recordCursor = !root.recordCursor
                            onEntered: TooltipService.show(cursorArea, pluginApi?.tr("tooltips.cursor"))
                            onExited: TooltipService.hide()
                        }
                    }
                }
                Row {
                    width: parent.width; spacing: Style.marginS
                    Rectangle {
                        width: (parent.width - Style.marginS) / 2; height: 38; radius: Style.radiusM
                        color: recRegionBtn.containsMouse ? Color.mPrimary : Color.mSurface
                        border.color: Color.mPrimary; border.width: Style.capsuleBorderWidth
                        Row { anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { icon: "crop"; color: recRegionBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; scale: 0.85 }
                            NText { text: pluginApi?.tr("record.region"); color: recRegionBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                        }
                        MouseArea {
                            id: recRegionBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mainInstance?.runRecord(root.selectedRecordFormat, root.recordAudioOutput, root.recordAudioInput, root.recordCursor)
                            onEntered: TooltipService.show(recRegionBtn, pluginApi?.tr("tooltips.record"))
                            onExited: TooltipService.hide()
                        }
                    }
                    Rectangle {
                        width: (parent.width - Style.marginS) / 2; height: 38; radius: Style.radiusM
                        color: recFsBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                        border.color: Style.capsuleBorderColor; border.width: Style.capsuleBorderWidth
                        Row { anchors.centerIn: parent; spacing: Style.marginXS
                            NIcon { icon: "maximize"; color: recFsBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; scale: 0.85 }
                            NText { text: pluginApi?.tr("annotate.fullscreen"); color: recFsBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant; font.weight: Font.Bold; pointSize: Style.fontSizeS }
                        }
                        MouseArea {
                            id: recFsBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.mainInstance?.runRecordFullscreen(root.selectedRecordFormat, root.recordAudioOutput, root.recordAudioInput, root.recordCursor)
                            onEntered: TooltipService.show(recFsBtn, pluginApi?.tr("tooltips.recordfs"))
                            onExited: TooltipService.hide()
                        }
                    }
                }
            }
            Column {
                property bool _shown: root.viewedTool === "mirror"
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width; spacing: Style.marginM
                Row {
                    width: parent.width; spacing: Style.marginS
                    NIcon { icon: "camera"; color: Color.mPrimary; anchors.verticalCenter: parent.verticalCenter }
                    NText { text: pluginApi?.tr("mirror.title"); color: Color.mOnSurface; font.weight: Font.Bold; pointSize: Style.fontSizeS; anchors.verticalCenter: parent.verticalCenter }
                }
                NText { width: parent.width; wrapMode: Text.WordWrap; text: pluginApi?.tr("mirror.hint"); color: Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                Rectangle {
                    width: parent.width; height: 38; radius: Style.radiusM
                    color: root.mirrorActive ? Color.mError : (mirrorToggleBtn.containsMouse ? Color.mPrimary : Color.mSurface)
                    border.color: root.mirrorActive ? Color.mError : Color.mPrimary; border.width: Style.capsuleBorderWidth
                    Row { anchors.centerIn: parent; spacing: Style.marginS
                        NIcon { icon: root.mirrorActive ? "camera-off" : "camera"; color: root.mirrorActive ? Color.mOnError : (mirrorToggleBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary) }
                        NText { text: root.mirrorActive ? pluginApi?.tr("mirror.close") : pluginApi?.tr("mirror.open"); color: root.mirrorActive ? Color.mOnError : (mirrorToggleBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary); font.weight: Font.Bold; pointSize: Style.fontSizeS }
                    }
                    MouseArea { id: mirrorToggleBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mainInstance?.runMirrorClose() }
                }
            }
            ResultColor {
                property bool _shown: root.viewedTool === "colorpicker"
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width
                pluginApi:    root.pluginApi
                mainInstance: root.mainInstance
            }
            ResultOcr {
                property bool _shown: root.viewedTool === "ocr" && (mainInstance?.ocrResult ?? "") !== ""
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width
                pluginApi:    root.pluginApi
                mainInstance: root.mainInstance
            }
            ResultQr {
                property bool _shown: root.viewedTool === "qr" && (mainInstance?.qrResult ?? "") !== ""
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width
                pluginApi:    root.pluginApi
                mainInstance: root.mainInstance
            }
            ResultPalette {
                property bool _shown: root.viewedTool === "palette"
                visible: _shown
                opacity: _shown ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                width: parent.width
                pluginApi:    root.pluginApi
                mainInstance: root.mainInstance
            }
        }
    }
    component ToolBtn: Item {
        id: btn
        property string icon:      ""
        property string label:     ""
        property string tooltip:   ""
        property bool   active:    false
        property bool   focused:   false
        property bool   running:   false
        property bool   recording: false
        property bool   hasResult: false
        readonly property bool  _accented:    recording || active || focused
        readonly property color _accentColor: recording ? Color.mError
                                            : active    ? Color.mPrimary
                                            :             Color.mSecondary
        signal triggered()
        Column {
            anchors.centerIn: parent; spacing: Style.marginXS
            Rectangle {
                width:  Math.min(btn.width - 8, 42)
                height: Math.min(btn.width - 8, 42)
                radius: Style.radiusM
                anchors.horizontalCenter: parent.horizontalCenter
                color:        ba.containsMouse ? Color.mHover : Color.mSurface
                border.color: btn._accented ? btn._accentColor
                            : ba.containsMouse ? Color.mOnSurfaceVariant
                            : "transparent"
                border.width: btn._accented ? 2 : ba.containsMouse ? 1 : 0
                clip: true
                scale: ba.containsMouse && !btn.running ? 1.04 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
                Rectangle {
                    anchors.fill: parent; radius: parent.radius; color: btn._accentColor
                    opacity: btn.recording ? 0 : btn.active ? 0.15 : btn.focused ? 0.08 : 0
                }
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: Color.mError; visible: btn.recording; opacity: 0
                    SequentialAnimation on opacity {
                        running: btn.recording; loops: Animation.Infinite
                        NumberAnimation { to: 0.05; duration: 600 }
                        NumberAnimation { to: 0.2;  duration: 600 }
                    }
                }
                Rectangle {
                    id: ripple
                    width: 0; height: 0
                    radius: width / 2
                    color: btn._accentColor
                    opacity: 0
                    property real cx: 0; property real cy: 0
                    x: cx - width  / 2
                    y: cy - height / 2
                    ParallelAnimation {
                        id: rippleAnim
                        NumberAnimation { target: ripple; property: "width";   to: 80; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ripple; property: "height";  to: 80; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ripple; property: "opacity"; to: 0;  duration: 350; easing.type: Easing.OutCubic }
                    }
                }
                NIcon {
                    anchors.centerIn: parent; icon: btn.icon
                    color: btn._accented ? btn._accentColor
                         : ba.containsMouse ? Color.mOnHover
                         : Color.mOnSurface
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: btn._accentColor
                    border.color: Color.mSurface
                    border.width: Style.borderM
                    anchors.top:         parent.top
                    anchors.right:       parent.right
                    anchors.topMargin:   3
                    anchors.rightMargin: 3
                    visible: btn.hasResult && !btn.active && !btn.running
                }
                MouseArea {
                    id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    enabled: !btn.running || btn.recording
                    onClicked: (mouse) => {
                        ripple.cx      = mouse.x
                        ripple.cy      = mouse.y
                        ripple.width   = 0
                        ripple.height  = 0
                        ripple.opacity = 0.3
                        rippleAnim.restart()
                        btn.triggered()
                    }
                    onEntered:  TooltipService.show(btn, btn.tooltip !== "" ? btn.tooltip : btn.label)
                    onExited:   TooltipService.hide()
                }
            }
            NText {
                text: btn.label; pointSize: Style.fontSizeXS
                color:   (ba.containsMouse || btn._accented) ? Color.mOnSurface : Color.mOnSurfaceVariant
                font.weight: btn.active ? Font.Bold : Font.Normal
                anchors.horizontalCenter: parent.horizontalCenter
                width: btn.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                opacity: (ba.containsMouse || btn._accented) ? 1.0 : 0.35
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
        }
    }
}
