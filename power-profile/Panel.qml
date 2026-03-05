pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance

    readonly property Rectangle geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    readonly property int contentPreferredWidth: 300 * Style.uiScaleRatio
    readonly property int contentPreferredHeight: contentColumn.implicitHeight + Style.marginM * 2

    anchors.fill: parent

    component ProfileButton: Rectangle {
        id: profileButton

        required property var profileData  // { name: string, degraded: bool }

        readonly property string profile: profileData.name
        readonly property bool degraded: profileData.degraded ?? false

        readonly property bool isCurrent: profile === root.mainInstance?.currentProfile
        readonly property bool isInteractive: (root.mainInstance?.available ?? false)
            && !(root.mainInstance?.busy ?? false)
            && !isCurrent

        readonly property bool hovered: hoverHandler.hovered

        readonly property color bgColor: {
            if (isCurrent) return Color.mPrimary;
            if (hovered && isInteractive) return Qt.alpha(Color.mPrimary, 0.12);
            return "transparent";
        }

        readonly property color borderColor: {
            if (isCurrent || (hovered && isInteractive)) return Color.mPrimary;
            return Qt.alpha(Color.mOnSurface, 0.2);
        }

        readonly property color fgColor: {
            if (isCurrent) return Color.mOnPrimary;
            if (hovered && isInteractive) return Color.mPrimary;
            return Color.mOnSurface;
        }

        Layout.fillWidth: true
        implicitHeight: buttonRow.implicitHeight + Style.marginM * 2
        radius: Style.radiusM
        color: bgColor
        border.width: Style.borderM
        border.color: borderColor
        opacity: 1.0

        Behavior on color { ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }

        RowLayout {
            id: buttonRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Style.marginL
                rightMargin: Style.marginL
            }
            spacing: Style.marginM

            NIcon {
                icon: root.mainInstance?.getProfileIcon(profileButton.profile) ?? "cpu"
                pointSize: Style.fontSizeL
                color: profileButton.fgColor
                Behavior on color { ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }
            }

            NText {
                Layout.fillWidth: true
                text: root.mainInstance?.getProfileLabel(profileButton.profile) ?? profileButton.profile
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: profileButton.fgColor
                Behavior on color { ColorAnimation { duration: Style.animationFast; easing.type: Easing.OutCubic } }
            }

            NIcon {
                visible: profileButton.isCurrent
                icon: "check"
                pointSize: Style.fontSizeM
                color: profileButton.fgColor
            }

            NIcon {
                visible: profileButton.degraded
                icon: "alert-triangle"
                pointSize: Style.fontSizeM
                color: profileButton.isCurrent ? Color.mOnPrimary : Color.mError
            }
        }

        TapHandler {
            enabled: profileButton.isInteractive
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.mainInstance?.setProfile(profileButton.profile)
        }

        HoverHandler {
            id: hoverHandler
            enabled: profileButton.isInteractive
            cursorShape: Qt.PointingHandCursor
        }
    }

    Rectangle {
        id: panelContainer
        x: Style.marginM
        y: Style.marginM
        color: "transparent"

        ColumnLayout {
            id: contentColumn
            width: root.contentPreferredWidth - Style.marginM * 2
            spacing: Style.marginM

            NBox {
                Layout.fillWidth: true
                Layout.preferredHeight: headerRow.implicitHeight + Style.marginM * 2

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    NIcon {
                        icon: root.mainInstance?.getProfileIcon(root.mainInstance?.currentProfile ?? "") ?? "cpu"
                        pointSize: Style.fontSizeXXL
                        color: Color.mPrimary
                    }

                    NText {
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.title") || "Power Profile"
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                    }

                    NIconButton {
                        icon: "refresh"
                        tooltipText: pluginApi?.tr("context.refresh") || "Refresh"
                        baseSize: Style.baseWidgetSize * 0.8
                        enabled: !(root.mainInstance?.busy ?? false)
                        onClicked: root.mainInstance?.refresh()
                    }
                }
            }

            NBox {
                Layout.fillWidth: true
                Layout.preferredHeight: profilesColumn.implicitHeight + Style.marginM * 2

                ColumnLayout {
                    id: profilesColumn
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Style.marginM
                    }
                    spacing: Style.marginS

                    NText {
                        text: pluginApi?.tr("panel.choose") || "Choose a profile"
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                    }

                    Repeater {
                        model: root.mainInstance?.profiles ?? []

                        delegate: ProfileButton {
                            required property var modelData
                            profileData: modelData
                        }
                    }

                    NText {
                        visible: !(root.mainInstance?.available ?? false)
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: pluginApi?.tr("panel.unavailable") || "power-profiles-daemon not available"
                        pointSize: Style.fontSizeS
                        color: Color.mOnSurfaceVariant
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
