import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 500 * Style.uiScaleRatio
    property real contentPreferredHeight: 650 * Style.uiScaleRatio
    readonly property bool allowAttach: true
    
    anchors.fill: parent

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property var feeds: cfg.feeds || defaults.feeds || []
    readonly property int updateInterval: cfg.updateInterval ?? defaults.updateInterval ?? 600
    readonly property int maxItemsPerFeed: cfg.maxItemsPerFeed ?? defaults.maxItemsPerFeed ?? 10
    readonly property bool showOnlyUnread: cfg.showOnlyUnread ?? defaults.showOnlyUnread ?? false
    readonly property bool markAsReadOnClick: cfg.markAsReadOnClick ?? defaults.markAsReadOnClick ?? true
    property var readItems: cfg.readItems || defaults.readItems || []

    property var allItems: []
    property var displayItems: []
    property bool loading: false
    property int unreadCount: 0
    property int _prevUnreadCount: 0
    property bool _seenInitialUnreadSet: false

    // Timer to reload settings after save
    Timer {
        id: settingsReloadTimer
        interval: 200
        running: false
        repeat: false
        onTriggered: {
            if (pluginApi && pluginApi.pluginSettings) {
                cfg = pluginApi.pluginSettings;
                readItems = cfg.readItems || defaults.readItems || [];
                Logger.d("RSS", "Settings reloaded, readItems count:", readItems.length);
                updateDisplayItems();
            }
        }
    }

    // Process for fetching feeds directly in Panel
    Process {
        id: fetchProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        
        property bool isFetching: false
        property var tempItems: []
        property int currentFeedIndex: 0
        property string currentFeedUrl: ""
        
        onExited: exitCode => {
            if (exitCode === 0 && stdout.text) {
                const items = parseRSSFeed(stdout.text, currentFeedUrl);
                tempItems = tempItems.concat(items);
                Logger.d("RSS", "Fetched", items.length, "items from", currentFeedUrl);
            }
            
            fetchNextFeed();
        }
    }

    Component.onCompleted: {
        Logger.d("RSS", "Component loaded");
        Logger.d("RSS", "Feeds configured:", feeds.length);

        // Start fetching immediately
        if (feeds.length > 0) {
            Qt.callLater(fetchAllFeeds);
        }
    }




    onVisibleChanged: {
        if (visible) {
            Logger.d("RSS", "Opened");
            // Refresh on open
            if (feeds.length > 0 && !loading) {
                fetchAllFeeds();
            }
        }
    }

    function fetchAllFeeds() {
        if (feeds.length === 0) {
            Logger.d("RSS", "No feeds configured");
            return;
        }
        
        if (fetchProcess.isFetching) {
            Logger.d("RSS", "Already fetching");
            return;
        }
        
        Logger.d("RSS", "Starting fetch for", feeds.length, "feeds");
        loading = true;
        fetchProcess.tempItems = [];
        fetchProcess.currentFeedIndex = 0;
        fetchNextFeed();
    }

    function fetchNextFeed() {
        if (fetchProcess.currentFeedIndex >= feeds.length) {
            // Done fetching all feeds
            fetchProcess.isFetching = false;
            loading = false;
            
            // Sort by date and update
            let sorted = fetchProcess.tempItems.sort((a, b) => {
                return new Date(b.pubDate) - new Date(a.pubDate);
            });
            
            allItems = sorted;
            Logger.d("RSS", "Total items:", allItems.length);
            updateDisplayItems();
            return;
        }
        
        const feed = feeds[fetchProcess.currentFeedIndex];
        fetchProcess.currentFeedUrl = feed.url;
        fetchProcess.currentFeedIndex++;
        
        Logger.d("RSS", "Fetching", fetchProcess.currentFeedUrl);
        
        fetchProcess.command = [
            "curl", "-s", "-L",
            "-H", "User-Agent: Mozilla/5.0",
            "--max-time", "10",
            fetchProcess.currentFeedUrl
        ];
        fetchProcess.isFetching = true;
        fetchProcess.running = true;
    }

    function parseRSSFeed(xml, feedUrl) {
        const items = [];
        const feedName = feeds.find(f => f.url === feedUrl)?.name || feedUrl;
        
        // Extract <item> or <entry> elements
        const itemRegex = /<(?:item|entry)[^>]*>([\s\S]*?)<\/(?:item|entry)>/gi;
        let match;
        
        let count = 0;
        while ((match = itemRegex.exec(xml)) !== null && count < maxItemsPerFeed) {
            const itemXml = match[1];
            
            const title = extractTag(itemXml, 'title') || 'Untitled';
            const link = extractTag(itemXml, 'link') || extractAttr(itemXml, 'link', 'href') || '';
            const description = extractTag(itemXml, 'description') || extractTag(itemXml, 'summary') || extractTag(itemXml, 'content') || '';
            const pubDate = extractTag(itemXml, 'pubDate') || extractTag(itemXml, 'published') || extractTag(itemXml, 'updated') || new Date().toISOString();
            const guid = extractTag(itemXml, 'guid') || extractTag(itemXml, 'id') || link;
            
            items.push({
                feedName: feedName,
                title: cleanHTML(title),
                description: cleanHTML(description).substring(0, 200),
                link: link,
                pubDate: pubDate,
                guid: guid
            });
            
            count++;
        }
        
        return items;
    }

    function extractTag(xml, tag) {
        const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i');
        const match = regex.exec(xml);
        return match ? match[1].trim() : '';
    }

    function extractAttr(xml, tag, attr) {
        const regex = new RegExp(`<${tag}[^>]*${attr}=["']([^"']+)["']`, 'i');
        const match = regex.exec(xml);
        return match ? match[1] : '';
    }

    function cleanHTML(text) {
        if (!text) return '';
        // Remove CDATA
        text = text.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
        // Remove HTML tags
        text = text.replace(/<[^>]+>/g, ' ');
        // Decode numeric HTML entities (&#8220; etc)
        text = text.replace(/&#(\d+);/g, function(match, dec) {
            return String.fromCharCode(dec);
        });
        // Decode hex HTML entities (&#x201C; etc)
        text = text.replace(/&#x([0-9A-Fa-f]+);/g, function(match, hex) {
            return String.fromCharCode(parseInt(hex, 16));
        });
        // Decode common HTML entities
        text = text.replace(/&lt;/g, '<');
        text = text.replace(/&gt;/g, '>');
        text = text.replace(/&amp;/g, '&');
        text = text.replace(/&quot;/g, '"');
        text = text.replace(/&#39;/g, "'");
        text = text.replace(/&apos;/g, "'");
        text = text.replace(/&nbsp;/g, ' ');
        text = text.replace(/&mdash;/g, '\u2014');
        text = text.replace(/&ndash;/g, '\u2013');
        text = text.replace(/&ldquo;/g, '\u201C');
        text = text.replace(/&rdquo;/g, '\u201D');
        text = text.replace(/&lsquo;/g, '\u2018');
        text = text.replace(/&rsquo;/g, '\u2019');
        text = text.replace(/&hellip;/g, '\u2026');
        // Clean whitespace
        text = text.replace(/\s+/g, ' ').trim();
        return text;
    }

    // Remove the Timer that tries to sync with BarWidget
    onAllItemsChanged: updateDisplayItems()
    onShowOnlyUnreadChanged: updateDisplayItems()
    onReadItemsChanged: {
        Logger.d("RSS", "readItems changed, count:", readItems.length);
        updateDisplayItems();
    }

    function updateDisplayItems() {
        Logger.d("RSS", "updateDisplayItems called, allItems.length:", allItems.length);
        if (showOnlyUnread) {
            displayItems = allItems.filter(item => {
                return !readItems.includes(item.guid || item.link);
            });
        } else {
            displayItems = allItems.slice();
        }
        Logger.d("RSS", "displayItems.length:", displayItems.length);
        updateUnreadCount();
    }

    function updateUnreadCount() {  
        var newCount = 0;
        try {
            newCount = allItems.filter(function(item) { return !readItems.includes(item.guid || item.link); }).length;
        } catch (e) {
            newCount = 0;
        }
        
        if (!_seenInitialUnreadSet) {
            _prevUnreadCount = newCount;
            _seenInitialUnreadSet = true;
        } else if (typeof _prevUnreadCount === 'number' && newCount > _prevUnreadCount) {
            try {
                headerPulseDebounce.restart();
            } catch (e) {}
        }

        unreadCount = newCount;

        if (pluginApi) {
            try {
                pluginApi.unreadCount = unreadCount;
            } catch (e) {
                
            }
        }

        _prevUnreadCount = unreadCount;
        Logger.d("RSS", "unreadCount:", unreadCount);
    }

    function markAsRead(guid) {
        if (!guid) {
            return;
        }
        
        Logger.d("RSS", "Marking as read:", guid);
        
        // Use current local readItems if available to update UI immediately
        const currentReadItems = readItems || cfg.readItems || defaults.readItems || [];
        
        if (currentReadItems.includes(guid)) {
            Logger.d("RSS", "Already marked as read");
            return;
        }
        
        // Add to readItems array - create new array
        let newReadItems = currentReadItems.slice();
        newReadItems.push(guid);
        
        Logger.d("RSS", "New readItems array:", JSON.stringify(newReadItems));
        
        // Update local state immediately so the badge updates without waiting for reload
        readItems = newReadItems;
        updateDisplayItems();
        updateUnreadCount();
        
        // Save to settings using the same pattern as Settings.qml
        if (pluginApi) {
            if (!pluginApi.pluginSettings) {
                pluginApi.pluginSettings = {};
            }
            pluginApi.pluginSettings.readItems = newReadItems;
            pluginApi.saveSettings();
            Logger.d("RSS", "Settings saved, readItems count:", newReadItems.length);
            
            // Trigger reload timer for consistency
            settingsReloadTimer.restart();
        }
    }

    function markAllAsRead() {
        if (allItems.length === 0) {
            return;
        }
        
        Logger.d("RSS", "Marking all as read, count:", allItems.length);
        
        // Use local readItems to update UI immediately
        const currentReadItems = readItems || cfg.readItems || defaults.readItems || [];
        
        // Collect all guids - create new array
        let newReadItems = currentReadItems.slice();
        
        for (let i = 0; i < allItems.length; i++) {
            const guid = allItems[i].guid || allItems[i].link;
            if (guid && !newReadItems.includes(guid)) {
                newReadItems.push(guid);
            }
        }
        
        Logger.d("RSS", "New readItems array length:", newReadItems.length);
        
        // Update local state immediately so badge updates
        readItems = newReadItems;
        updateDisplayItems();
        updateUnreadCount();
        
        // Save to settings using the same pattern as Settings.qml
        if (pluginApi) {
            if (!pluginApi.pluginSettings) {
                pluginApi.pluginSettings = {};
            }
            pluginApi.pluginSettings.readItems = newReadItems;
            pluginApi.saveSettings();
            Logger.d("RSS", "All marked as read, readItems count:", newReadItems.length);
            
            // Trigger reload timer
            settingsReloadTimer.restart();
        }
    }

    function refresh() {
        if (pluginApi?.triggerRefresh) {
            pluginApi.triggerRefresh();
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"


        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                NText {
                    text: pluginApi?.tr("widget.title", "RSS Feeds") || "RSS Feeds"
                    pointSize: Style.fontSizeL
                    font.bold: true
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }


                Rectangle {
                    id: headerBadge
                    visible: unreadCount > 0
                    width: unreadCount > 0 ? (badgeText.implicitWidth + 12) : 0
                    height: unreadCount > 0 ? (badgeText.implicitHeight + 8) : 0
                    radius: height * 0.5
                    color: Color.mPrimary
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: width
                    Layout.preferredHeight: height
                    anchors.leftMargin: Style.marginS

                    transform: Scale { id: headerBadgeScale; xScale: 1; yScale: 1 }

                    NText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: unreadCount > 99 ? "99+" : unreadCount.toString()
                        pointSize: Style.fontSizeS
                        color: Color.mOnPrimary
                    }

                    SequentialAnimation {
                        id: headerPulse
                        running: false
                        PropertyAnimation { target: headerBadgeScale; property: "xScale"; to: 1.15; duration: 140; easing.type: Easing.InOutQuad }
                        PropertyAnimation { target: headerBadgeScale; property: "yScale"; to: 1.15; duration: 140; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 80 }
                        PropertyAnimation { target: headerBadgeScale; property: "xScale"; to: 1.0; duration: 160; easing.type: Easing.InOutQuad }
                        PropertyAnimation { target: headerBadgeScale; property: "yScale"; to: 1.0; duration: 160; easing.type: Easing.InOutQuad }
                    }

                    Timer {
                        id: headerPulseDebounce
                        interval: 250
                        running: false
                        repeat: false
                        onTriggered: {
                            if (headerPulse) headerPulse.restart();
                        }
                    }
                }

                NButton {
                    text: pluginApi?.tr("widget.markAllRead", "Mark all as read") || "Mark all as read"
                    enabled: displayItems.length > 0
                    onClicked: markAllAsRead()
                }

                // Settings button
                Rectangle {
                    id: panelSettingsBtn
                    width: 28
                    height: 28
                    radius: 6
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    NIcon {
                        anchors.centerIn: parent
                        icon: "settings"
                        pointSize: 14
                        color: Color.mOnSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!pluginApi) return;
                            var screen = pluginApi?.panelOpenScreen;
                            if (screen) {
                                pluginApi.closePanel(screen);
                                Qt.callLater(function() {
                                    BarService.openPluginSettings(screen, pluginApi.manifest);
                                });
                            } else if (pluginApi && pluginApi.withCurrentScreen) {
                                // Fallback for contexts where panelOpenScreen isn't available
                                pluginApi.withCurrentScreen(function(s) {
                                    pluginApi.closePanel(s);
                                    Qt.callLater(function() {
                                        BarService.openPluginSettings(s, pluginApi.manifest);
                                    });
                                });
                            } else {
                                // Last-resort fallback to older API
                                try {
                                    pluginApi.openSettings(root.screen, root);
                                } catch (e) {
                                    try {
                                        pluginApi.openSettings();
                                    } catch (err) {
                                        Logger.w("RSS", "openSettings failed:", err);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            NDivider {
                Layout.fillWidth: true
            }

            // Content
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    model: displayItems
                    spacing: Style.marginS

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: itemLayout.implicitHeight + 16
                        color: Color.mSurfaceVariant
                        radius: Style.radiusM

                        readonly property bool isUnread: !readItems.includes(modelData.guid || modelData.link)

                        Rectangle {
                            visible: isUnread
                            width: 3
                            height: parent.height
                            color: isUnread ? Color.mPrimary : "transparent"
                        }

                        ColumnLayout {
                            id: itemLayout
                            anchors.fill: parent
                            anchors.margins: 12
                            anchors.leftMargin: isUnread ? 18 : 12
                            spacing: 6

                            // Feed name
                            NText {
                                text: modelData.feedName || "Unknown Feed"
                                pointSize: Style.fontSizeS
                                font.bold: true
                                color: Color.mPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Title
                            NText {
                                text: modelData.title || "Untitled"
                                pointSize: Style.fontSizeM 
                                font.bold: isUnread
                                color: Color.mOnSurface
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Description
                            NText {
                                visible: modelData.description && modelData.description.length > 0
                                text: modelData.description || ""
                                pointSize: Style.fontSizeS
                                color: Color.mSecondary
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Date
                            NText {
                                text: formatDate(modelData.pubDate)
                                pointSize: Style.fontSizeS 
                                color: Color.mSecondary
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.link) {
                                    Qt.openUrlExternally(modelData.link);
                                    if (markAsReadOnClick) {
                                        markAsRead(modelData.guid || modelData.link);
                                    }
                                }
                            }
                        }
                    }

                    NText {
                        visible: displayItems.length === 0
                        anchors.centerIn: parent
                        text: pluginApi?.tr("widget.noItems", "No items to display") || "No items to display"
                        pointSize: Style.fontSizeM
                        color: Color.mSecondary
                    }
                }
            }

            // Footer
            NDivider {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true

                NText {
                    text: allItems.length + " total items"
                    pointSize: Style.fontSizeS
                    color: Color.mSecondary
                    Layout.fillWidth: true
                }
            }
        }
    }

    function formatDate(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return pluginApi?.tr("widget.timeNow", "now") || "now";
        if (diffMins < 60) return (pluginApi?.tr("widget.timeMinutes", "%1min ago") || "%1min ago").replace("%1", diffMins);
        if (diffHours < 24) return (pluginApi?.tr("widget.timeHours", "%1h ago") || "%1h ago").replace("%1", diffHours);
        if (diffDays < 7) return (pluginApi?.tr("widget.timeDays", "%1d ago") || "%1d ago").replace("%1", diffDays);
        
        return date.toLocaleDateString();
    }
}
