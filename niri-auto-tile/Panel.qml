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
                            text: pluginApi?.tr("panel.title")
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
                                Layout.minimumHeight: Math.round(50 * Style.uiScaleRatio)

                                radius: Style.iRadiusM
                                color: isSelected ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant
                                border.color: isSelected ? Color.mPrimary : (optionMouse.containsMouse ? Color.mOutline : "transparent")
                                border.width: isSelected ? Style.borderM : Style.borderS

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
                                            spacing: Style.marginXXS

                                            Repeater {
                                                model: layoutOption.columnCount

                                                Rectangle {
                                                    width: {
                                                        const available = layoutOption.width - Style.marginS * 2 - (layoutOption.columnCount - 1) * Style.marginXXS;
                                                        return Math.max(Math.round(8 * Style.uiScaleRatio), available / layoutOption.columnCount);
                                                    }
                                                    height: layoutOption.height * 0.45
                                                    radius: Style.iRadiusXXXS
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
                                            ? pluginApi?.tr("panel.single")
                                            : pluginApi?.tr("panel.columns", {"count": layoutOption.columnCount})
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
                            width: Math.round(8 * Style.uiScaleRatio)
                            height: Math.round(8 * Style.uiScaleRatio)
                            radius: Math.round(4 * Style.uiScaleRatio)
                            color: {
                                if (!root.isEnabled) return Color.mOutline;
                                if (root.isRunning) return Color.mPrimary;
                                return Color.mSecondary;
                            }
                        }

                        NText {
                            text: {
                                if (!root.isEnabled) return pluginApi?.tr("panel.status-disabled");
                                if (root.isRunning) {
                                    if (root.perWorkspace && root.currentWorkspaceId > 0) {
                                        return pluginApi?.tr("panel.status-active-ws", {"count": root.currentMaxVisible, "ws": root.currentWorkspaceId});
                                    }
                                    return pluginApi?.tr("panel.status-active", {"count": root.currentMaxVisible});
                                }
                                return pluginApi?.tr("panel.status-starting");
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
