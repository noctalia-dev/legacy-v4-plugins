import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 300 * Style.uiScaleRatio
    property real contentPreferredHeight: 280 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property bool isRunning: mainInstance?.running ?? false
    readonly property bool isEnabled: mainInstance?.enabled ?? false
    readonly property bool perWorkspace: mainInstance?.perWorkspace ?? false
    readonly property int globalMaxVisible: mainInstance?.maxVisible ?? 4

    // Current workspace detection
    property int currentWorkspaceId: -1
    property int currentMaxVisible: {
        if (perWorkspace && currentWorkspaceId > 0 && mainInstance) {
            return mainInstance.getMaxVisibleForWorkspace(currentWorkspaceId);
        }
        return globalMaxVisible;
    }

    // Query current workspace when panel becomes visible
    Component.onCompleted: queryWorkspace()
    onVisibleChanged: { if (visible) queryWorkspace(); }

    function queryWorkspace() {
        wsQueryProcess.running = true;
    }

    Process {
        id: wsQueryProcess
        command: ["niri", "msg", "-j", "focused-window"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data && typeof data === "object" && data.workspace_id) {
                        root.currentWorkspaceId = data.workspace_id;
                    }
                } catch (e) {}
            }
        }
    }

    function selectColumns(count) {
        if (!mainInstance) return;
        if (perWorkspace && currentWorkspaceId > 0) {
            mainInstance.setWorkspaceMaxVisible(currentWorkspaceId, count);
        } else {
            mainInstance.setMaxVisible(count);
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginL

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM
                    clip: true

                    // ─── Header ───
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NIcon {
                            icon: "barrier-block"
                            pointSize: Style.fontSizeL
                            color: Color.mPrimary
                        }

                        NText {
                            text: pluginApi?.tr("panel.title") ?? "Column Layout"
                            pointSize: Style.fontSizeL
                            font.bold: true
                            color: Color.mOnSurface
                            Layout.fillWidth: true
                        }

                        NToggle {
                            checked: root.isEnabled
                            onToggled: checked => {
                                if (pluginApi?.pluginSettings) {
                                    pluginApi.pluginSettings.enabled = checked;
                                    pluginApi.saveSettings();
                                }
                            }
                        }
                    }

                    // ─── Layout Options Grid ───
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        rowSpacing: Style.marginM
                        columnSpacing: Style.marginM

                        Repeater {
                            model: [1, 2, 3, 4]

                            delegate: Rectangle {
                                id: layoutOption

                                required property int modelData
                                readonly property int columnCount: modelData
                                readonly property bool isSelected: columnCount === root.currentMaxVisible

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 50

                                radius: Style.iRadiusM
                                color: isSelected ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant
                                border.color: isSelected ? Color.mPrimary : (optionMouse.containsMouse ? Color.mOutline : "transparent")
                                border.width: isSelected ? 2 : 1

                                Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                Behavior on border.color { ColorAnimation { duration: Style.animationFast } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Style.marginS
                                    spacing: Style.marginS

                                    // ─── Visual column representation ───
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Repeater {
                                                model: layoutOption.columnCount

                                                Rectangle {
                                                    width: {
                                                        const available = layoutOption.width - Style.marginS * 2 - (layoutOption.columnCount - 1) * 3;
                                                        return Math.max(8, available / layoutOption.columnCount);
                                                    }
                                                    height: layoutOption.height * 0.45
                                                    radius: 3
                                                    color: layoutOption.isSelected
                                                        ? Color.mPrimary
                                                        : (optionMouse.containsMouse ? Qt.alpha(Color.mOnSurface, 0.4) : Qt.alpha(Color.mOnSurface, 0.25))

                                                    Behavior on color { ColorAnimation { duration: Style.animationFast } }
                                                }
                                            }
                                        }
                                    }

                                    // ─── Label ───
                                    NText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: layoutOption.columnCount === 1
                                            ? (pluginApi?.tr("panel.single") ?? "Single")
                                            : (pluginApi?.tr("panel.columns") ?? "%1 Columns").arg(layoutOption.columnCount)
                                        pointSize: Style.fontSizeS
                                        font.bold: layoutOption.isSelected
                                        color: layoutOption.isSelected ? Color.mPrimary : Color.mOnSurface
                                    }
                                }

                                MouseArea {
                                    id: optionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.selectColumns(layoutOption.columnCount);
                                    }
                                }
                            }
                        }
                    }

                    // ─── Status bar ───
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: {
                                if (!root.isEnabled) return Color.mOutline;
                                if (root.isRunning) return Color.mPrimary;
                                return Color.mSecondary;
                            }
                        }

                        NText {
                            text: {
                                if (!root.isEnabled) return pluginApi?.tr("panel.status-disabled") ?? "Disabled";
                                if (root.isRunning) {
                                    const label = (pluginApi?.tr("panel.status-active") ?? "Active — %1 columns").arg(root.currentMaxVisible);
                                    if (root.perWorkspace && root.currentWorkspaceId > 0) {
                                        return label + " (WS " + root.currentWorkspaceId + ")";
                                    }
                                    return label;
                                }
                                return pluginApi?.tr("panel.status-starting") ?? "Starting...";
                            }
                            pointSize: Style.fontSizeS
                            color: Qt.alpha(Color.mOnSurface, 0.6)
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
