import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property var feeds: cfg.feeds || defaults.feeds || []
    property bool showOnlyWhenUnread: cfg.showOnlyWhenUnread ?? defaults.showOnlyWhenUnread ?? false
    property int updateInterval: (cfg.updateInterval ?? defaults.updateInterval ?? 600)
    property int maxItemsPerFeed: cfg.maxItemsPerFeed ?? defaults.maxItemsPerFeed ?? 10
    property bool showOnlyUnread: cfg.showOnlyUnread ?? defaults.showOnlyUnread ?? false
    property bool markAsReadOnClick: cfg.markAsReadOnClick ?? defaults.markAsReadOnClick ?? true

    // Temporary fields for adding new feed
    property string newFeedName: ""
    property string newFeedUrl: ""

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("RSS Feed: Cannot save settings - pluginApi is null");
            return;
        }
        
        if (!pluginApi.pluginSettings) {
            pluginApi.pluginSettings = {};
        }

        pluginApi.pluginSettings.feeds = feeds;
        pluginApi.pluginSettings.showOnlyWhenUnread = showOnlyWhenUnread;
        pluginApi.pluginSettings.updateInterval = updateInterval;
        pluginApi.pluginSettings.maxItemsPerFeed = maxItemsPerFeed;
        pluginApi.pluginSettings.showOnlyUnread = showOnlyUnread;
        pluginApi.pluginSettings.markAsReadOnClick = markAsReadOnClick;
        
        Logger.d("RSS Feed", "RSS Feed Settings: Saving - updateInterval:", updateInterval, 
                    "maxItems:", maxItemsPerFeed, "showOnlyUnread:", showOnlyUnread, 
                    "markAsReadOnClick:", markAsReadOnClick, "feeds:", feeds.length);
        
        pluginApi.saveSettings();
        Logger.d("RSS Feed", "RSS Feed: Settings saved successfully");
    }

    function addFeed() {
        if (newFeedName.trim() === "" || newFeedUrl.trim() === "") {
            Logger.e("RSS Feed: Name and URL are required");
            return;
        }
        
        const newFeeds = feeds.slice();
        newFeeds.push({
            name: newFeedName.trim(),
            url: newFeedUrl.trim()
        });
        feeds = newFeeds;
        
        newFeedName = "";
        newFeedUrl = "";
        
        saveSettings();
    }

    function removeFeed(index) {
        const newFeeds = feeds.slice();
        newFeeds.splice(index, 1);
        feeds = newFeeds;
        saveSettings();
    }




    // Update Interval
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.updateInterval")
            description: pluginApi?.tr("settings.updateIntervalDesc")
        }

        RowLayout {
            spacing: Style.marginM

            NSpinBox {
                from: 60
                to: 3600
                value: updateInterval
                onValueChanged: {
                    updateInterval = value;
                    saveSettings();
                }
            }

            Text {
                text: pluginApi?.tr("settings.seconds")
                color: Style.textColorSecondary || "#FFFFFF"
                font.pixelSize: Style.fontSizeM || 14
            }
        }
    }

    // Max Items Per Feed
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.maxItems")
            description: pluginApi?.tr("settings.maxItemsDesc")
        }

        NSpinBox {
            from: 5
            to: 50
            value: maxItemsPerFeed
            onValueChanged: {
                maxItemsPerFeed = value;
                saveSettings();
            }
        }
    }

    // Show Only Unread
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.showOnlyUnread")
            description: pluginApi?.tr("settings.showOnlyUnreadDesc")
        }

        NToggle {
            checked: showOnlyUnread
            onToggled: {
                showOnlyUnread = checked;
                saveSettings();
            }
        }
    }

    // Show When Unread Only
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.showOnlyWhenUnread")
            description: pluginApi?.tr("settings.showOnlyWhenUnreadDesc")
        }

        NToggle {
            checked: showOnlyWhenUnread
            onToggled: {
                showOnlyWhenUnread = checked;
                saveSettings();
            }
        }
    }

    // Mark as Read on Click
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.markOnClick")
            description: pluginApi?.tr("settings.markOnClickDesc")
        }

        NToggle {
            checked: markAsReadOnClick
            onToggled: {
                markAsReadOnClick = checked;
                saveSettings();
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Style.borderColor || "#333333"
    }

    // Feeds Management
    Text {
        text: pluginApi?.tr("settings.feeds")
        font.pixelSize: Style.fontSizeL || 18
        font.bold: true
        color: Style.textColor || "#FFFFFF"
    }

    // Add New Feed
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Text {
            text: pluginApi?.tr("settings.addFeed")
            font.bold: true
            color: Style.textColor || "#FFFFFF"
            font.pixelSize: Style.fontSizeM || 14
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: pluginApi?.tr("settings.feedName")
                    font.pixelSize: Style.fontSizeS || 12
                    color: Style.textColorSecondary || "#FFFFFF"
                }

                NTextInput {
                    Layout.fillWidth: true
                    placeholderText: pluginApi?.tr("settings.feedNamePlaceholder")
                    text: newFeedName
                    onTextChanged: newFeedName = text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: pluginApi?.tr("settings.feedUrl")
                    font.pixelSize: Style.fontSizeS || 12
                    color: Style.textColorSecondary || "#FFFFFF"
                }

                NTextInput {
                    Layout.fillWidth: true
                    placeholderText: pluginApi?.tr("settings.feedUrlPlaceholder")
                    text: newFeedUrl
                    onTextChanged: newFeedUrl = text
                }
            }

            NButton {
                text: pluginApi?.tr("settings.add")
                enabled: newFeedName.trim() !== "" && newFeedUrl.trim() !== ""
                onClicked: addFeed()
            }
        }
    }

    // Feed List
    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: 300
        clip: true

        ListView {
            model: feeds
            spacing: Style.marginS

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: ListView.view.width
                height: feedItemLayout.implicitHeight + 16
                color: Style.fillColorSecondary || "#2A2A2A"
                radius: Style.radiusM || 8

                RowLayout {
                    id: feedItemLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: Style.marginM

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: modelData.name
                            font.pixelSize: Style.fontSizeM || 14
                            font.bold: true
                            color: Style.textColor || "#FFFFFF"
                            Layout.fillWidth: true
                        }

                        Text {
                            text: modelData.url
                            font.pixelSize: Style.fontSizeS || 12
                            color: Style.textColorSecondary || "#AAAAAA"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    NButton {
                        text: pluginApi?.tr("settings.remove")
                        onClicked: removeFeed(index)
                    }
                }
            }

            Text {
                visible: feeds.length === 0
                anchors.centerIn: parent
                text: pluginApi?.tr("settings.noFeeds")
                font.pixelSize: Style.fontSizeM || 14
                color: Style.textColorSecondary || "#888888"
            }
        }
    }
}
