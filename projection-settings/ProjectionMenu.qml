import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null

    property string activeProfile: ""
    readonly property bool hasProfiles: itemsModel.count > 0

    readonly property var geometryPlaceholder: root
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: 350 * Style.uiScaleRatio

    implicitWidth: contentPreferredWidth
    implicitHeight: contentPreferredHeight
    width: parent && parent.width > 0 ? parent.width : contentPreferredWidth
    height: parent && parent.height > 0 ? parent.height : contentPreferredHeight

    ListModel { id: itemsModel }


    Process {
        id: statusChecker
        command: ["kanshictl", "status"]
        running: true 
        stdout: StdioCollector {
            onTextChanged: {
                if (text.includes(": ")) {
                    root.activeProfile = text.split(": ")[1].trim()
                }
            }
        }
    }

    Process {
        id: kanshiReader
        command: ["sh", "-c", "grep 'profile' ${XDG_CONFIG_HOME:-$HOME/.config}/kanshi/config | cut -d '{' -f 1 | sed 's/profile//g' | tr -d '\"'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                itemsModel.clear();
                lines.forEach(profile => {
                    let cleanName = profile.trim();
                    if (cleanName) itemsModel.append({ "title": cleanName });
                });
            }
        }
    }

    Process {
        id: switchProcess
        onRunningChanged: {
            if (!running) {
                statusChecker.running = true 
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (pluginApi) {
                pluginApi.closePanel(pluginApi.panelOpenScreen);
            }
        }
    }


    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Color.mSurface
        radius: Style.radiusL
        border.color: Color.mOutline
        border.width: 1

        ColumnLayout {
            anchors { fill: parent; margins: Style.marginL }
            spacing: Style.marginM

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: Style.radiusM
                    color: Qt.alpha(Color.mPrimary, 0.16)
                    border.color: Qt.alpha(Color.mPrimary, 0.35)
                    border.width: 1

                    NIcon {
                        anchors.centerIn: parent
                        icon: "devices"
                        width: 18
                        height: 18
                        color: Color.mPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    NText {
                        text: "Projection"
                        pointSize: Style.fontSizeL
                        font.weight: Font.Bold
                        color: Color.mOnSurface
                    }

                    NText {
                        text: "Switch monitor layout quickly"
                        font.pixelSize: 11
                        color: Qt.alpha(Color.mOnSurface, 0.68)
                    }
                }

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 22
                    radius: 11
                    color: Color.mSurfaceVariant
                    border.color: Color.mOutline
                    border.width: 1

                    NText {
                        anchors.centerIn: parent
                        text: String(itemsModel.count)
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Color.mOnSurface
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Style.radiusM
                color: Color.mSurfaceVariant
                border.color: Qt.alpha(Color.mOutline, 0.65)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    spacing: Style.marginS

                    NIcon {
                        icon: switchProcess.running ? "refresh" : "circle-check"
                        width: 16
                        height: 16
                        color: switchProcess.running ? Color.mSecondary : Color.mPrimary
                    }

                    NText {
                        Layout.fillWidth: true
                        text: switchProcess.running
                            ? "Applying profile..."
                            : (root.activeProfile ? "Active: " + root.activeProfile : "No active profile detected")
                        color: Color.mOnSurface
                        font.weight: switchProcess.running ? Font.Normal : Font.Medium
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Color.mOutline
                opacity: 0.35
            }

            NScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    anchors.fill: parent
                    visible: root.hasProfiles
                    model: itemsModel
                    spacing: Style.marginS
                    clip: true

                    delegate: Rectangle {
                        id: profileCard
                        width: ListView.view.width
                        height: 58 * Style.uiScaleRatio
                        radius: Style.radiusM

                        property bool isActive: model.title === root.activeProfile
                        property bool isHovered: mouseHandler.hovered

                        color: isActive
                            ? Qt.alpha(Color.mPrimary, 0.14)
                            : (isHovered ? Color.mSurfaceVariant : Qt.alpha(Color.mSurfaceVariant, 0.32))
                        border.color: isActive ? Color.mPrimary : (isHovered ? Color.mOutline : Qt.alpha(Color.mOutline, 0.5))
                        border.width: isActive ? 2 : 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Style.marginS
                            spacing: Style.marginXS

                            NIcon {
                                width: 48
                                height: 48
                                color: profileCard.isActive ? Color.mPrimary : Color.mOnSurface
                                icon: {
                                    let t = model.title.toLowerCase();
                                    if (t.includes("triple") || t.includes("3")) return "columns-3";
                                    if (t.includes("dual") || t.includes("2")) return "columns-2";
                                    if (t.includes("solo") || t.includes("single")) return "device-laptop";
                                    return "device-imac";
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                NText {
                                    text: model.title
                                    font.weight: profileCard.isActive ? Font.Bold : Font.Medium
                                    color: Color.mOnSurface
                                }

                                NText {
                                    text: profileCard.isActive ? "Currently active" : "Click to apply"
                                    font.pixelSize: 10
                                    color: profileCard.isActive ? Color.mPrimary : Qt.alpha(Color.mOnSurface, 0.62)
                                }
                            }

                            NIcon {
                                visible: profileCard.isActive
                                icon: "check"
                                width: 16
                                height: 16
                                color: Color.mPrimary
                            }
                        }

                        HoverHandler {
                            id: mouseHandler
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                switchProcess.command = ["kanshictl", "switch", model.title];
                                switchProcess.running = true;
                                root.activeProfile = model.title;
                                closeTimer.start();
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: !root.hasProfiles

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - (Style.marginL * 2)
                        spacing: Style.marginS

                        NIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: "monitor-off"
                            width: 24
                            height: 24
                            color: Qt.alpha(Color.mOnSurface, 0.65)
                        }

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No profiles found"
                            font.weight: Font.Bold
                            color: Color.mOnSurface
                        }

                        NText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Add profiles to ~/.config/kanshi/config, then reopen this panel."
                            font.pixelSize: 10
                            color: Qt.alpha(Color.mOnSurface, 0.68)
                        }
                    }
                }
            }
        }
    }
}