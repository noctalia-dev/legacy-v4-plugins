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
            label: pluginApi?.tr("settings.updateInterval", "Update Interval") || "Update Interval"
            description: pluginApi?.tr("settings.updateIntervalDesc", "How often to check for new items (seconds)") || "How often to check for new items (seconds)"
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
                text: pluginApi?.tr("settings.seconds", "seconds") || "seconds"
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
            label: pluginApi?.tr("settings.maxItems", "Max Items Per Feed") || "Max Items Per Feed"
            description: pluginApi?.tr("settings.maxItemsDesc", "Maximum number of items to fetch from each feed") || "Maximum number of items to fetch from each feed"
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
            label: pluginApi?.tr("settings.showOnlyUnread", "Show Only Unread") || "Show Only Unread"
            description: pluginApi?.tr("settings.showOnlyUnreadDesc", "Display only unread items in the panel") || "Display only unread items in the panel"
        }

        NToggle {
            checked: showOnlyUnread
            onToggled: {
                showOnlyUnread = checked;
                saveSettings();
            }
        }
    }

    // Mark as Read on Click
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
            label: pluginApi?.tr("settings.markOnClick", "Mark as Read on Click") || "Mark as Read on Click"
            description: pluginApi?.tr("settings.markOnClickDesc", "Automatically mark items as read when opening them") || "Automatically mark items as read when opening them"
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
        text: pluginApi?.tr("settings.feeds", "RSS Feeds") || "RSS Feeds"
        font.pixelSize: Style.fontSizeL || 18
        font.bold: true
        color: Style.textColor || "#FFFFFF"
    }

    // Add New Feed
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        Text {
            text: pluginApi?.tr("settings.addFeed", "Add New Feed") || "Add New Feed"
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
                    text: pluginApi?.tr("settings.feedName", "Feed Name") || "Feed Name"
                    font.pixelSize: Style.fontSizeS || 12
                    color: Style.textColorSecondary || "#FFFFFF"
                }

                NTextInput {
                    Layout.fillWidth: true
                    placeholderText: "Example Blog"
                    text: newFeedName
                    onTextChanged: newFeedName = text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: pluginApi?.tr("settings.feedUrl", "Feed URL") || "Feed URL"
                    font.pixelSize: Style.fontSizeS || 12
                    color: Style.textColorSecondary || "#FFFFFF"
                }

                NTextInput {
                    Layout.fillWidth: true
                    placeholderText: "https://example.com/feed.xml"
                    text: newFeedUrl
                    onTextChanged: newFeedUrl = text
                }
            }

            NButton {
                text: pluginApi?.tr("settings.add", "Add") || "Add"
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
                        text: pluginApi?.tr("settings.remove", "Remove") || "Remove"
                        onClicked: removeFeed(index)
                    }
                }
            }

            Text {
                visible: feeds.length === 0
                anchors.centerIn: parent
                text: pluginApi?.tr("settings.noFeeds", "No feeds configured. Add one above!") || "No feeds configured. Add one above!"
                font.pixelSize: Style.fontSizeM || 14
                color: Style.textColorSecondary || "#888888"
            }
        }
    }
}
