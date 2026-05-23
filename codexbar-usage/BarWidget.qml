import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "codexbar.js" as CodexBar

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen ? screen.name : ""
    readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
    readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

    property int primaryPercent: -1
    property int secondaryPercent: -1
    property string primaryReset: ""
    property string secondaryReset: ""
    property string accountEmail: ""
    property string statusText: "…"
    property string errorText: ""
    property bool loading: false

    readonly property string displayText: {
        if (loading && primaryPercent < 0)
            return "…";
        if (errorText !== "")
            return "ERR";
        if (primaryPercent >= 0 && secondaryPercent >= 0)
            return primaryPercent + "%·" + secondaryPercent + "%";
        if (primaryPercent >= 0)
            return primaryPercent + "%";
        return "—";
    }

    readonly property string tooltipText: {
        if (errorText !== "")
            return "CodexBar: " + errorText;
        var tip = "CodexBar";
        if (accountEmail !== "")
            tip += " — " + accountEmail;
        if (primaryPercent >= 0)
            tip += "\n5h: " + primaryPercent + "%" + (primaryReset !== "" ? " · resets " + primaryReset : "");
        if (secondaryPercent >= 0)
            tip += "\nWeekly: " + secondaryPercent + "%" + (secondaryReset !== "" ? " · resets " + secondaryReset : "");
        return tip;
    }

    readonly property real contentWidth: isBarVertical ? capsuleHeight : content.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: isBarVertical ? content.implicitHeight + Style.marginM * 2 : capsuleHeight
    readonly property real gaugeWidth: Math.max(4, Math.round(capsuleHeight * 0.16))
    readonly property real gaugeHeight: Math.max(16, Math.round(capsuleHeight * 0.56))
    readonly property real meterFontSize: Math.max(7, barFontSize - 3)
    readonly property int refreshIntervalMs: CodexBar.refreshIntervalMs(pluginApi)

    anchors.centerIn: parent
    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Component.onCompleted: refresh()

    Timer {
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: codexbarProcess
        command: CodexBar.command(root.pluginApi)
        running: false
        stdout: StdioCollector {
            id: codexbarStdout
            onStreamFinished: root.parseOutput(text)
        }
        stderr: StdioCollector {
            id: codexbarStderr
        }
        onRunningChanged: root.loading = running
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                var err = String(codexbarStderr.text || "").trim();
                root.errorText = err !== "" ? err : "codexbar exited " + exitCode;
            }
        }
    }

    function refresh() {
        if (codexbarProcess.running)
            return;
        errorText = "";
        codexbarProcess.running = true;
    }

    function parseOutput(output) {
        var usage = CodexBar.parseUsage(output);
        if (usage.error !== "") {
            errorText = usage.error;
            return;
        }
        accountEmail = usage.accountEmail;
        primaryPercent = usage.primaryPercent;
        secondaryPercent = usage.secondaryPercent;
        primaryReset = usage.primaryReset;
        secondaryReset = usage.secondaryReset;
        statusText = displayText;
        errorText = "";
    }

    function clampPercent(value) {
        return CodexBar.clampPercent(value);
    }

    function usageColor(value) {
        if (errorText !== "")
            return Color.mError;
        if (value < 0 || isNaN(value))
            return Color.mOutline;
        if (value >= 85)
            return Color.mError;
        if (value >= 60)
            return Color.mSecondary;
        return Color.mPrimary;
    }

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Item {
            id: content
            anchors.centerIn: parent
            implicitWidth: rowLayout.visible ? rowLayout.implicitWidth : colLayout.implicitWidth
            implicitHeight: rowLayout.visible ? rowLayout.implicitHeight : colLayout.implicitHeight

            RowLayout {
                id: rowLayout
                visible: !root.isBarVertical
                spacing: Style.marginS

                NIcon {
                    icon: root.errorText !== "" ? "alert-circle" : "ai"
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: root.errorText !== "" ? Color.mError : Color.mPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                RowLayout {
                    spacing: Style.marginXS
                    Layout.alignment: Qt.AlignVCenter

                    NText {
                        text: "5h"
                        pointSize: root.meterFontSize
                        applyUiScale: false
                        font.weight: Style.fontWeightSemiBold
                        color: Qt.alpha(Color.mOnSurface, 0.78)
                        Layout.alignment: Qt.AlignVCenter
                    }

                    NLinearGauge {
                        orientation: Qt.Vertical
                        ratio: root.clampPercent(root.primaryPercent) / 100
                        fillColor: root.usageColor(root.primaryPercent)
                        width: root.gaugeWidth
                        height: root.gaugeHeight
                        Layout.alignment: Qt.AlignVCenter
                    }

                    NText {
                        text: "W"
                        pointSize: root.meterFontSize
                        applyUiScale: false
                        font.weight: Style.fontWeightSemiBold
                        color: Qt.alpha(Color.mOnSurface, 0.78)
                        Layout.leftMargin: Style.marginXS
                        Layout.alignment: Qt.AlignVCenter
                    }

                    NLinearGauge {
                        orientation: Qt.Vertical
                        ratio: root.clampPercent(root.secondaryPercent) / 100
                        fillColor: root.usageColor(root.secondaryPercent)
                        width: root.gaugeWidth
                        height: root.gaugeHeight
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            ColumnLayout {
                id: colLayout
                visible: root.isBarVertical
                spacing: Style.marginXS

                NIcon {
                    icon: root.errorText !== "" ? "alert-circle" : "ai"
                    pointSize: root.barFontSize
                    applyUiScale: false
                    color: root.errorText !== "" ? Color.mError : Color.mPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    spacing: Style.marginXS
                    Layout.alignment: Qt.AlignHCenter

                    NText {
                        text: "5h"
                        pointSize: root.meterFontSize
                        applyUiScale: false
                        font.weight: Style.fontWeightSemiBold
                        color: Qt.alpha(Color.mOnSurface, 0.78)
                    }

                    NLinearGauge {
                        orientation: Qt.Vertical
                        ratio: root.clampPercent(root.primaryPercent) / 100
                        fillColor: root.usageColor(root.primaryPercent)
                        width: root.gaugeWidth
                        height: root.gaugeHeight
                    }
                }

                RowLayout {
                    spacing: Style.marginXS
                    Layout.alignment: Qt.AlignHCenter

                    NText {
                        text: "W"
                        pointSize: root.meterFontSize
                        applyUiScale: false
                        font.weight: Style.fontWeightSemiBold
                        color: Qt.alpha(Color.mOnSurface, 0.78)
                    }

                    NLinearGauge {
                        orientation: Qt.Vertical
                        ratio: root.clampPercent(root.secondaryPercent) / 100
                        fillColor: root.usageColor(root.secondaryPercent)
                        width: root.gaugeWidth
                        height: root.gaugeHeight
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            TooltipService.hide();
            if (mouse.button === Qt.LeftButton && pluginApi)
                pluginApi.togglePanel(root.screen, visualCapsule);
            else if (mouse.button === Qt.RightButton)
                root.refresh();
        }
        onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screenName))
        onExited: TooltipService.hide()
    }
}
