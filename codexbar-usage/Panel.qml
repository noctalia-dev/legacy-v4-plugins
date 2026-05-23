import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import "codexbar.js" as CodexBar

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 380 * Style.uiScaleRatio
    property real contentPreferredHeight: Math.min(520 * Style.uiScaleRatio, panelContent.implicitHeight + Style.marginL * 2)

    anchors.fill: parent

    property bool loading: false
    property string errorText: ""
    property string sourceName: ""
    property string providerName: "Codex"
    property string versionText: ""
    property string updatedAt: ""
    property string accountEmail: ""
    property string loginMethod: ""
    property string providerId: ""
    property int primaryPercent: -1
    property int secondaryPercent: -1
    property int primaryWindowMinutes: 0
    property int secondaryWindowMinutes: 0
    property string primaryResetAt: ""
    property string secondaryResetAt: ""
    property string primaryReset: ""
    property string secondaryReset: ""
    property int creditsRemaining: 0
    property int creditEventsCount: 0

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

    Process {
        id: codexbarProcess
        command: CodexBar.command(root.pluginApi)
        running: false
        stdout: StdioCollector { id: codexbarStdout }
        stderr: StdioCollector { id: codexbarStderr }
        onRunningChanged: root.loading = running
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                var err = String(codexbarStderr.text || "").trim()
                root.errorText = err !== "" ? err : "codexbar exited " + exitCode
                return
            }
            root.parseOutput(codexbarStdout.text)
        }
    }

    function refresh() {
        if (codexbarProcess.running)
            return
        errorText = ""
        codexbarProcess.running = true
    }

    function parseOutput(output) {
        var parsed = CodexBar.parseUsage(output)
        if (parsed.error !== "") {
            errorText = parsed.error
            return
        }

        sourceName = parsed.sourceName
        providerName = parsed.providerName
        versionText = parsed.versionText
        updatedAt = parsed.updatedAt
        accountEmail = parsed.accountEmail
        loginMethod = parsed.loginMethod
        providerId = parsed.providerId
        primaryPercent = parsed.primaryPercent
        secondaryPercent = parsed.secondaryPercent
        primaryWindowMinutes = parsed.primaryWindowMinutes
        secondaryWindowMinutes = parsed.secondaryWindowMinutes
        primaryResetAt = parsed.primaryResetAt
        secondaryResetAt = parsed.secondaryResetAt
        primaryReset = parsed.primaryReset
        secondaryReset = parsed.secondaryReset
        creditsRemaining = parsed.creditsRemaining
        creditEventsCount = parsed.creditEventsCount
        errorText = ""
    }

    function clampPercent(value) {
        return CodexBar.clampPercent(value)
    }

    function ratio(value) {
        return CodexBar.clampPercent(value) / 100
    }

    function percentLabel(value) {
        return CodexBar.percentLabel(value)
    }

    function windowLabel(minutes) {
        return CodexBar.windowLabel(minutes)
    }

    function formatDateTime(isoText) {
        if (isoText === "")
            return ""
        var d = new Date(isoText)
        if (isNaN(d.getTime()))
            return isoText
        return d.toLocaleString(Qt.locale(), Locale.ShortFormat)
    }

    function updatedLabel() {
        var formatted = formatDateTime(updatedAt)
        return formatted !== "" ? formatted : "—"
    }

    function usageColor(value) {
        if (errorText !== "")
            return Color.mError
        if (value < 0 || isNaN(value))
            return Color.mOutline
        if (value >= 85)
            return Color.mError
        if (value >= 60)
            return Color.mSecondary
        return Color.mPrimary
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            id: panelContent
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginM

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                    icon: root.errorText !== "" ? "alert-circle" : "ai"
                    color: root.errorText !== "" ? Color.mError : Color.mPrimary
                    pointSize: Style.fontSizeXL
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXXS

                    NText {
                        text: "Codex usage"
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NText {
                        text: root.accountEmail !== "" ? root.accountEmail : root.sourceName
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: Style.radiusM
                    color: refreshMouse.containsMouse ? Color.mPrimary : Color.mSurfaceVariant
                    border.color: refreshMouse.containsMouse ? Color.mPrimary : Style.capsuleBorderColor
                    border.width: Style.capsuleBorderWidth

                    NIcon {
                        anchors.centerIn: parent
                        icon: root.loading ? "loader" : "refresh"
                        color: refreshMouse.containsMouse ? Color.mOnPrimary : Color.mOnSurfaceVariant
                        RotationAnimation on rotation {
                            running: root.loading
                            from: 0
                            to: 360
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }

                    MouseArea {
                        id: refreshMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }

            Rectangle {
                visible: root.errorText !== ""
                Layout.fillWidth: true
                implicitHeight: errorTextItem.implicitHeight + Style.marginL * 2
                radius: Style.radiusM
                color: Qt.alpha(Color.mError, 0.12)

                NText {
                    id: errorTextItem
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Style.marginL
                    }
                    text: root.errorText
                    wrapMode: Text.WordWrap
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mError
                }
            }

            LimitCard {
                Layout.fillWidth: true
                title: "5h limit"
                subtitle: root.windowLabel(root.primaryWindowMinutes)
                percent: root.primaryPercent
                resetShort: root.primaryReset
                resetFull: root.formatDateTime(root.primaryResetAt)
                barColor: root.usageColor(root.primaryPercent)
            }

            LimitCard {
                Layout.fillWidth: true
                title: "Weekly limit"
                subtitle: root.windowLabel(root.secondaryWindowMinutes)
                percent: root.secondaryPercent
                resetShort: root.secondaryReset
                resetFull: root.formatDateTime(root.secondaryResetAt)
                barColor: root.usageColor(root.secondaryPercent)
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: metaGrid.implicitHeight + Style.marginL * 2
                radius: Style.radiusL
                color: Color.mSurfaceVariant

                GridLayout {
                    id: metaGrid
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Style.marginL
                    }
                    columns: 2
                    rowSpacing: Style.marginS
                    columnSpacing: Style.marginL

                    MetaItem { label: "Login"; value: root.loginMethod !== "" ? root.loginMethod : "—" }
                    MetaItem { label: "Provider"; value: root.providerId !== "" ? root.providerId : root.providerName }
                    MetaItem { label: "Source"; value: root.sourceName !== "" ? root.sourceName : "—" }
                    MetaItem { label: "CodexBar"; value: root.versionText !== "" ? "v" + root.versionText : "—" }
                    MetaItem { label: "Credits"; value: String(root.creditsRemaining) + " remaining" }
                    MetaItem { label: "Credit events"; value: String(root.creditEventsCount) }
                }
            }

            NText {
                Layout.fillWidth: true
                text: "Updated " + root.updatedLabel()
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component LimitCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        property int percent: -1
        property string resetShort: ""
        property string resetFull: ""
        property color barColor: Color.mPrimary

        radius: Style.radiusL
        color: Color.mSurfaceVariant
        implicitHeight: limitLayout.implicitHeight + Style.marginL * 2

        ColumnLayout {
            id: limitLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginL
            }
            spacing: Style.marginS

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXXS

                    NText {
                        text: card.title
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NText {
                        text: card.subtitle
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                        Layout.fillWidth: true
                    }
                }

                NText {
                    text: root.percentLabel(card.percent)
                    pointSize: Style.fontSizeXXL
                    font.weight: Style.fontWeightBold
                    color: card.barColor
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 10
                radius: Style.radiusXXS
                color: Qt.alpha(Color.mOutline, 0.22)
                clip: true

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    radius: parent.radius
                    color: card.barColor
                    width: parent.width * root.ratio(card.percent)

                    Behavior on width {
                        NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: "Resets"
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                }

                Item { Layout.fillWidth: true }

                NText {
                    text: card.resetShort !== "" ? card.resetShort : (card.resetFull !== "" ? card.resetFull : "—")
                    pointSize: Style.fontSizeXS
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    Layout.maximumWidth: 210 * Style.uiScaleRatio
                }
            }

            NText {
                visible: card.resetFull !== "" && card.resetFull !== card.resetShort
                text: card.resetFull
                pointSize: Style.fontSizeXXS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }
    }

    component MetaItem: ColumnLayout {
        property string label: ""
        property string value: ""
        spacing: Style.marginXXS
        Layout.fillWidth: true

        NText {
            text: parent.label
            pointSize: Style.fontSizeXXS
            color: Color.mOnSurfaceVariant
            Layout.fillWidth: true
        }

        NText {
            text: parent.value
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnSurface
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
