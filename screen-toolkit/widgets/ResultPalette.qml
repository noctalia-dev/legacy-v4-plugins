import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import "../utils/utils.js" as U
Item {
    id: root
    property var pluginApi: null
    property var mainInstance: null
    implicitWidth: parent?.width ?? 0
    implicitHeight: contentCol.implicitHeight
    readonly property var paletteColors: mainInstance?.paletteColors ?? []
    Process { id: clipProc }
    function _copy(text) {
        if (!text || text === "") return
        clipProc.exec({
            command: ["bash", "-c", "printf '%s' " + U.shellEscape(text) + " | wl-copy 2>/dev/null"]
        })
    }
    function clear() {
        if (mainInstance) {
            mainInstance.clearPaletteResult()
            mainInstance.activeTool = ""
        }
    }
    Column {
        id: contentCol
        width: parent.width
        spacing: Style.marginM
        Rectangle {
            visible: root.paletteColors.length === 0
            width: parent.width
            height: 36
            radius: Style.radiusM
            color: emptyPalBtn.containsMouse ? Color.mPrimary : Color.mSurface
            border.color: Color.mPrimary
            border.width: Style.capsuleBorderWidth
            Row {
                anchors.centerIn: parent
                spacing: Style.marginS
                NIcon {
                    icon: "palette"
                    color: emptyPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
                }
                NText {
                    text: pluginApi?.tr("panel.pickAgain")
                    color: emptyPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
                    pointSize: Style.fontSizeS
                }
            }
            MouseArea {
                id: emptyPalBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mainInstance?.runPalette()
            }
        }
        Column {
            visible: root.paletteColors.length > 0
            width: parent.width
            spacing: Style.marginM
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: pickAgainPalBtn.containsMouse ? Color.mPrimary : Color.mSurface
                border.color: Color.mPrimary
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "palette"
                        color: pickAgainPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
                    }
                    NText {
                        text: pluginApi?.tr("panel.pickAgain")
                        color: pickAgainPalBtn.containsMouse ? Color.mOnPrimary : Color.mPrimary
                        pointSize: Style.fontSizeS
                    }
                }
                MouseArea {
                    id: pickAgainPalBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mainInstance?.runPalette()
                }
            }
            Flow {
                width: parent.width
                spacing: Style.marginS
                Repeater {
                    model: root.paletteColors
                    delegate: Rectangle {
                        width: (root.width - Style.marginS * 2) / 3 - Style.marginS
                        height: width * 0.7
                        radius: Style.radiusM
                        color: modelData
                        border.color: swatchBtn.containsMouse ? Color.mPrimary : Style.capsuleBorderColor
                        border.width: swatchBtn.containsMouse ? 2 : Style.capsuleBorderWidth
                        NText {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Style.marginXS
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.toUpperCase()
                            pointSize: Style.fontSizeXS
                            color: "white"
                            style: Text.Outline
                            styleColor: "#00000066"
                        }
                        MouseArea {
                            id: swatchBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._copy(modelData)
                                ToastService.showNotice(pluginApi?.tr("panel.colorCopied", { color: modelData }))
                            }
                            onEntered: TooltipService.show(swatchBtn, modelData.toUpperCase() + " — " + pluginApi?.tr("panel.clickToCopy"))
                            onExited: TooltipService.hide()
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: cssBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "copy"
                        color: cssBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
                    }
                    NText {
                        text: pluginApi?.tr("palette.cssVars")
                        color: cssBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
                MouseArea {
                    id: cssBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var css = root.paletteColors.map(function(c, i) {
                            return "--color-" + (i + 1) + ": " + c + ";"
                        }).join("\n")
                        root._copy(css)
                        ToastService.showNotice(pluginApi?.tr("panel.cssVarsCopied"))
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: hexBtn.containsMouse ? Color.mSurfaceVariant : Color.mSurface
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "list"
                        color: hexBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
                    }
                    NText {
                        text: pluginApi?.tr("palette.hexList")
                        color: hexBtn.containsMouse ? Color.mOnSurface : Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
                MouseArea {
                    id: hexBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root._copy(root.paletteColors.join("\n"))
                        ToastService.showNotice(pluginApi?.tr("panel.hexListCopied"))
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Style.radiusM
                color: palClr.containsMouse ? Qt.alpha(Color.mError, 0.15) : Color.mSurface
                border.color: palClr.containsMouse ? Color.mError : Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth
                Row {
                    anchors.centerIn: parent
                    spacing: Style.marginS
                    NIcon {
                        icon: "trash"
                        color: palClr.containsMouse ? Color.mError : Color.mOnSurfaceVariant
                    }
                    NText {
                        text: pluginApi?.tr("panel.clearResult")
                        color: palClr.containsMouse ? Color.mError : Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }
                }
                MouseArea {
                    id: palClr
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clear()
                    onEntered: TooltipService.show(palClr, pluginApi?.tr("panel.clearResult"))
                    onExited: TooltipService.hide()
                }
            }
        }
    }
}
