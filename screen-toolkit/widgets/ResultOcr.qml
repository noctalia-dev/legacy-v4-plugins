import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "../utils/utils.js" as U
Item {
    id: root
    property var    pluginApi:    null
    property var    mainInstance: null
    implicitWidth:  parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    readonly property string ocrResult:       mainInstance?.ocrResult       ?? ""
    readonly property string ocrCapturePath:  mainInstance?.ocrCapturePath  ?? ""
    readonly property string translateResult: mainInstance?.translateResult  ?? ""
    readonly property bool   transAvailable:  mainInstance?.transAvailable  ?? false
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
    property string selectedTransLang: "en"
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
        for (var i = 0; i < transLangs.length; i++)
            out.push({ key: transLangs[i].code, name: transLangs[i].name })
        return out
    }
    // Reads from plugin settings — user can set a custom engine (DDG, Brave, etc.)
    // Falls back to Google if left empty.
    readonly property string searchEngineUrl: {
        var custom = pluginApi?.pluginSettings?.searchEngineUrl ?? ""
        return custom.trim() !== "" ? custom : "https://www.google.com/search?q="
    }
    Process { id: clipProc }
    function _copy(text) {
        if (!text || text === "") return
        clipProc.exec({ command: ["bash", "-c",
            "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"] })
    }
    function _translate(text, lang) {
        if (mainInstance) mainInstance.runTranslate(text, lang)
    }
    function clear() {
        if (mainInstance) {
            mainInstance.clearOcrResult()
            mainInstance.activeTool = ""
        }
    }
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginS
        Rectangle {
            width: parent.width; height: 160 * Style.uiScaleRatio
            radius: Style.radiusM; color: Color.mSurfaceVariant; clip: true
            visible: root.ocrCapturePath !== "" && root.ocrResult !== "" && ocrThumb.status === Image.Ready
            Image {
                id: ocrThumb; anchors.fill: parent
                source: (root.ocrCapturePath !== "" && root.ocrResult !== "")
                    ? ("file://" + root.ocrCapturePath) : ""
                fillMode: Image.PreserveAspectCrop; smooth: true; cache: false
            }
        }
        Rectangle {
            width: parent.width; height: 220 * Style.uiScaleRatio
            radius: Style.radiusM; color: Color.mSurface; clip: true
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth
            Flickable {
                id: ocrFlick; anchors.fill: parent; anchors.margins: Style.marginS
                contentHeight: ocrText.implicitHeight; clip: true
                interactive: ocrText.implicitHeight > ocrFlick.height
                TextEdit {
                    id: ocrText; width: ocrFlick.width; text: root.ocrResult
                    wrapMode: TextEdit.WordWrap; color: Color.mOnSurface
                    font.pointSize: Style.fontSizeS
                    horizontalAlignment: /[\u0600-\u06FF\u0590-\u05FF]/.test(root.ocrResult)
                        ? TextEdit.AlignRight : TextEdit.AlignLeft
                    selectByMouse: true; selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    WheelHandler {
                        onWheel: event => { ocrFlick.flick(0, event.angleDelta.y * 5); event.accepted = false }
                    }
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
                        NIcon {
                            icon: root.ocrType === "email" ? "mail" : "external-link"
                            color: _ocrOpenMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface; scale: 0.8
                        }
                        NText {
                            text: root.ocrType === "email"
                                ? pluginApi?.tr("panel.composeMail") : pluginApi?.tr("panel.openUrl")
                            color: _ocrOpenMA.containsMouse ? Color.mOnPrimary : Color.mOnSurface
                            pointSize: Style.fontSizeXS
                        }
                    }
                    MouseArea {
                        id: _ocrOpenMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.ocrType === "email"
                            ? Qt.openUrlExternally("mailto:" + root.ocrEmail)
                            : Qt.openUrlExternally(root.ocrUrl)
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
                        onClicked: Qt.openUrlExternally(root.searchEngineUrl + encodeURIComponent(root.ocrResult.trim()))
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
                        onClicked: { root._copy(root.ocrResult); ToastService.showNotice(pluginApi?.tr("panel.copyText")) }
                    }
                }
            }
            Rectangle {
                id: _ocrClearBtn; height: 26; width: _ocrClearRow.implicitWidth + Style.marginM * 2; radius: Style.radiusS
                color: _ocrClearMA.containsMouse
                    ? Qt.rgba(Color.mError.r, Color.mError.g, Color.mError.b, 0.15) : Color.mSurfaceVariant
                border.color: Color.mError; border.width: Style.capsuleBorderWidth
                Row {
                    id: _ocrClearRow; anchors.centerIn: parent; spacing: Style.marginXS
                    NIcon { icon: "trash"; color: _ocrClearMA.containsMouse ? Color.mError : Color.mOnSurfaceVariant; scale: 0.8 }
                    NText { text: pluginApi?.tr("panel.clearResult"); color: _ocrClearMA.containsMouse ? Color.mError : Color.mOnSurfaceVariant; pointSize: Style.fontSizeXS }
                }
                MouseArea {
                    id: _ocrClearMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.clear()
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
                height: 1; color: Color.mOnSurfaceVariant; opacity: 0.25
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - Style.marginS * 3 - 16 - _transLabel.implicitWidth
            }
            NText { id: _transLabel; visible: false; text: pluginApi?.tr("ocr.translateSection") }
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
                    width: parent.width - translateBtn.width - Style.marginS
                    label: pluginApi?.tr("panel.translateTo")
                    model: root.transLangModel
                    currentKey: root.selectedTransLang
                    minimumWidth: 100; popupHeight: 220
                    onSelected: (key) => { root.selectedTransLang = key }
                }
                Rectangle {
                    id: translateBtn; height: 34; width: 34; radius: Style.radiusM
                    color: transBtnMa.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    NIcon { anchors.centerIn: parent; icon: "world"; color: transBtnMa.containsMouse ? Color.mOnPrimary : Color.mOnSurface }
                    MouseArea {
                        id: transBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root._translate(root.ocrResult, root.selectedTransLang)
                        onEntered: TooltipService.show(transBtnMa, pluginApi?.tr("panel.translateLabel"))
                        onExited:  TooltipService.hide()
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 140 * Style.uiScaleRatio
                radius: Style.radiusM; color: Color.mSurface; clip: true
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                visible: root.translateResult !== ""
                Flickable {
                    id: trFlick; anchors.fill: parent; anchors.margins: Style.marginS
                    contentHeight: trText.implicitHeight; clip: true
                    interactive: trText.implicitHeight > trFlick.height
                    TextEdit {
                        id: trText; width: trFlick.width; text: root.translateResult
                        color: Color.mOnSurface; font.pointSize: Style.fontSizeS
                        wrapMode: TextEdit.WordWrap
                        horizontalAlignment: /[\u0600-\u06FF\u0590-\u05FF]/.test(root.translateResult)
                            ? TextEdit.AlignRight : TextEdit.AlignLeft
                        selectByMouse: true; selectionColor: Color.mPrimary
                        selectedTextColor: Color.mOnPrimary
                        WheelHandler {
                            onWheel: event => { trFlick.flick(0, event.angleDelta.y * 5); event.accepted = false }
                        }
                    }
                }
                NIcon {
                    icon: "copy"; color: Color.mOnSurfaceVariant
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.marginS
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._copy(root.translateResult)
                            ToastService.showNotice(pluginApi?.tr("panel.translationCopied"))
                        }
                    }
                }
            }
        }
    }
}

