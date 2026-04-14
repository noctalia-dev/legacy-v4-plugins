import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: 550 * Style.uiScaleRatio
    readonly property bool allowAttach: true

    anchors.fill: parent

    readonly property var main: pluginApi?.mainInstance
    readonly property var messages: main ? main.messages : []
    readonly property string errorMessage: main ? main.errorMessage : ""
    readonly property bool isLoading: main ? main.isLoading : false
    readonly property string topics: main ? main.topics : ""

    // Priority colors
    function priorityColor(priority) {
        switch (priority) {
            case 1: return Color.mOnSurfaceVariant  // min
            case 2: return Color.mOnSurfaceVariant  // low
            case 3: return Color.mOnSurface         // default
            case 4: return Color.mWarning ?? "#FB8C00" // high
            case 5: return Color.mError             // urgent
            default: return Color.mOnSurface
        }
    }

    function priorityLabel(priority) {
        switch (priority) {
            case 1: return pluginApi?.tr("priority.min")
            case 2: return pluginApi?.tr("priority.low")
            case 3: return pluginApi?.tr("priority.default")
            case 4: return pluginApi?.tr("priority.high")
            case 5: return pluginApi?.tr("priority.urgent")
            default: return ""
        }
    }

    function formatRelativeTime(unixTime) {
        if (!unixTime) return "";
        var now = Math.floor(Date.now() / 1000);
        var diff = now - unixTime;

        if (diff < 60) return pluginApi?.tr("panel.timeNow");
        if (diff < 3600) {
            var mins = Math.floor(diff / 60);
            return pluginApi?.tr("panel.timeMinutes", { count: mins });
        }
        if (diff < 86400) {
            var hours = Math.floor(diff / 3600);
            return pluginApi?.tr("panel.timeHours", { count: hours });
        }
        var days = Math.floor(diff / 86400);
        return pluginApi?.tr("panel.timeDays", { count: days });
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            // --- Header ---
            NBox {
                Layout.fillWidth: true
                Layout.preferredHeight: headerContent.implicitHeight + Style.marginL

                RowLayout {
                    id: headerContent
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    NIcon {
                        icon: "bell"
                        width: Style.fontSizeXXL
                        height: width
                        color: Color.mPrimary
                    }

                    NText {
                        text: pluginApi?.tr("panel.title")
                        pointSize: Style.fontSizeL
                        font.weight: Style.fontWeightBold
                        color: Color.mOnSurface
                        Layout.fillWidth: true
                    }

                    NIconButton {
                        icon: "circle-check"
                        tooltipText: pluginApi?.tr("panel.markAllRead")
                        baseSize: Style.baseWidgetSize * 0.8
                        onClicked: {
                            if (main) main.markAllAsRead();
                        }
                    }

                    NIconButton {
                        icon: "refresh"
                        tooltipText: pluginApi?.tr("panel.refresh")
                        baseSize: Style.baseWidgetSize * 0.8
                        onClicked: {
                            if (main) main.pollMessages();
                        }
                    }

                    NIconButton {
                        icon: "x"
                        tooltipText: pluginApi?.tr("panel.close")
                        baseSize: Style.baseWidgetSize * 0.8
                        onClicked: {
                            if (pluginApi)
                                pluginApi.withCurrentScreen(s => pluginApi.closePanel(s));
                        }
                    }
                }
            }

            // --- Error banner ---
            NBox {
                visible: errorMessage.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: errorRow.implicitHeight + Style.marginL

                Rectangle {
                    anchors.fill: parent
                    radius: Style.radiusS
                    color: Qt.alpha(Color.mError, 0.1)
                    border.width: Style.borderS
                    border.color: Color.mError
                }

                RowLayout {
                    id: errorRow
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    NIcon {
                        icon: "alert-triangle"
                        width: Style.fontSizeL
                        height: width
                        color: Color.mError
                    }

                    NText {
                        text: errorMessage
                        color: Color.mError
                        pointSize: Style.fontSizeS
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            // --- Content ---
            NScrollView {
                id: contentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalPolicy: ScrollBar.AlwaysOff
                verticalPolicy: ScrollBar.AsNeeded
                reserveScrollbarSpace: false
                gradientColor: Color.mSurface

                ColumnLayout {
                    width: contentScroll.availableWidth
                    spacing: Style.marginS

                    // Loading state
                    NBox {
                        visible: isLoading && messages.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: loadingCol.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: loadingCol
                            anchors.centerIn: parent
                            spacing: Style.marginL

                            NBusyIndicator {
                                running: true
                                color: Color.mPrimary
                                size: Style.baseWidgetSize
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.loading")
                                pointSize: Style.fontSizeM
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // No topics configured
                    NBox {
                        visible: !isLoading && topics.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: noTopicsCol.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: noTopicsCol
                            anchors.centerIn: parent
                            spacing: Style.marginL
                            width: parent.width - Style.marginXL

                            NIcon {
                                icon: "bell-off"
                                width: 48
                                height: 48
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.noTopics")
                                pointSize: Style.fontSizeL
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.noTopicsHint")
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Empty state (topics set but no messages)
                    NBox {
                        visible: !isLoading && topics.length > 0 && messages.length === 0 && errorMessage.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: emptyCol.implicitHeight + Style.marginXL

                        ColumnLayout {
                            id: emptyCol
                            anchors.centerIn: parent
                            spacing: Style.marginL
                            width: parent.width - Style.marginXL

                            NIcon {
                                icon: "inbox"
                                width: 48
                                height: 48
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.empty")
                                pointSize: Style.fontSizeL
                                color: Color.mOnSurfaceVariant
                                Layout.alignment: Qt.AlignHCenter
                            }

                            NText {
                                text: pluginApi?.tr("panel.emptyHint")
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurfaceVariant
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // --- Message list ---
                    Repeater {
                        model: messages

                        NBox {
                            id: messageItem
                            Layout.fillWidth: true
                            Layout.leftMargin: Style.marginXS
                            Layout.rightMargin: Style.marginXS
                            implicitHeight: messageCol.implicitHeight + Style.marginL

                            readonly property bool isRead: main ? main.isMessageRead(modelData.id) : false
                            readonly property real itemOpacity: isRead ? 0.6 : 1.0

                            ColumnLayout {
                                id: messageCol
                                anchors.fill: parent
                                anchors.margins: Style.marginM
                                spacing: Style.marginXS

                                // Top row: topic badge + time + priority
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginS

                                    // Unread dot
                                    Rectangle {
                                        visible: !messageItem.isRead
                                        width: 8
                                        height: 8
                                        radius: width / 2
                                        color: Color.mPrimary
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    // Topic badge
                                    Rectangle {
                                        color: Qt.alpha(Color.mPrimary, 0.15)
                                        radius: Style.radiusS
                                        width: topicText.implicitWidth + Style.marginS * 2
                                        height: topicText.implicitHeight + Style.marginXXS * 2
                                        Layout.alignment: Qt.AlignVCenter

                                        NText {
                                            id: topicText
                                            anchors.centerIn: parent
                                            text: modelData.topic || ""
                                            pointSize: Style.fontSizeXXS
                                            color: Color.mPrimary
                                            font.weight: Style.fontWeightMedium
                                            opacity: messageItem.itemOpacity
                                        }
                                    }

                                    // Priority indicator (only for non-default)
                                    Rectangle {
                                        visible: modelData.priority !== 3 && modelData.priority !== undefined
                                        color: Qt.alpha(priorityColor(modelData.priority), 0.15)
                                        radius: Style.radiusS
                                        width: prioText.implicitWidth + Style.marginS * 2
                                        height: prioText.implicitHeight + Style.marginXXS * 2
                                        Layout.alignment: Qt.AlignVCenter

                                        NText {
                                            id: prioText
                                            anchors.centerIn: parent
                                            text: priorityLabel(modelData.priority)
                                            pointSize: Style.fontSizeXXS
                                            color: priorityColor(modelData.priority)
                                            font.weight: Style.fontWeightMedium
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Timestamp
                                    NText {
                                        text: formatRelativeTime(modelData.time)
                                        pointSize: Style.fontSizeXXS
                                        color: Color.mOnSurfaceVariant
                                        opacity: messageItem.itemOpacity
                                    }
                                }

                                // Title (if present)
                                NText {
                                    visible: modelData.title && modelData.title.length > 0
                                    text: modelData.title || ""
                                    pointSize: Style.fontSizeM
                                    font.weight: Style.fontWeightBold
                                    color: Color.mOnSurface
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    opacity: messageItem.itemOpacity
                                }

                                // Message body
                                NText {
                                    visible: modelData.message && modelData.message.length > 0
                                    text: modelData.message || ""
                                    pointSize: Style.fontSizeS
                                    color: Color.mOnSurface
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    opacity: messageItem.itemOpacity
                                }

                                // Tags (if present)
                                Flow {
                                    visible: modelData.tags && modelData.tags.length > 0
                                    Layout.fillWidth: true
                                    spacing: Style.marginXXS

                                    Repeater {
                                        model: modelData.tags || []

                                        Rectangle {
                                            color: Qt.alpha(Color.mSecondary, 0.1)
                                            radius: Style.radiusS
                                            width: tagLabel.implicitWidth + Style.marginXS * 2
                                            height: tagLabel.implicitHeight + 2

                                            NText {
                                                id: tagLabel
                                                anchors.centerIn: parent
                                                text: modelData
                                                pointSize: Style.fontSizeXXS
                                                color: Color.mSecondary
                                            }
                                        }
                                    }
                                }

                                // Action buttons row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Style.marginS

                                    NButton {
                                        visible: modelData.click && modelData.click.length > 0
                                        text: pluginApi?.tr("panel.openLink")
                                        onClicked: Qt.openUrlExternally(modelData.click)
                                    }

                                    Item { Layout.fillWidth: true }

                                    NButton {
                                        visible: !messageItem.isRead
                                        text: pluginApi?.tr("panel.markRead")
                                        onClicked: {
                                            if (main) main.markAsRead(modelData.id);
                                        }
                                    }
                                }
                            }

                            // Hover effect
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onEntered: parent.color = Qt.lighter(Color.mSurface, 1.05)
                                onExited: parent.color = Color.mSurface
                                onClicked: mouse => mouse.accepted = false
                                onPressed: mouse => mouse.accepted = false
                                onReleased: mouse => mouse.accepted = false
                            }
                        }
                    }
                }
            }
        }
    }
}
