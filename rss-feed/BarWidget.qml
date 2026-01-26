import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
    id: root

    property var pluginApi: null

    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    readonly property bool isVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

    // Configuration
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property var feeds: cfg.feeds || defaults.feeds || []
    readonly property int updateInterval: cfg.updateInterval ?? defaults.updateInterval ?? 600
    readonly property int maxItemsPerFeed: cfg.maxItemsPerFeed ?? defaults.maxItemsPerFeed ?? 10
    readonly property bool showOnlyUnread: cfg.showOnlyUnread ?? defaults.showOnlyUnread ?? false
    readonly property bool markAsReadOnClick: cfg.markAsReadOnClick ?? defaults.markAsReadOnClick ?? true
    readonly property var readItems: cfg.readItems || defaults.readItems || []

    // Watch for changes in readItems and cfg to update unread count
    onCfgChanged: {
        Logger.d("RSS Feed", "RSS Feed BarWidget: Config changed");
        updateUnreadCount();
    }
    
    onReadItemsChanged: {
        Logger.d("RSS Feed", "RSS Feed BarWidget: readItems changed, count:", readItems.length);
        updateUnreadCount();
    }

    // State
    property var allItems: []
    property int unreadCount: 0
    property bool loading: false
    property bool error: false

    // Timer to periodically reload settings (to catch changes from Panel)
    Timer {
        id: settingsReloadTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (pluginApi && pluginApi.pluginSettings) {
                const newCfg = pluginApi.pluginSettings;
                const newReadItems = newCfg.readItems || defaults.readItems || [];
                if (JSON.stringify(readItems) !== JSON.stringify(newReadItems)) {
                    cfg = newCfg;
                    Logger.d("RSS Feed", "RSS Feed BarWidget: Settings updated, readItems count:", newReadItems.length);
                }
            }
        }
    }

    // Expose state to pluginApi for Panel access
    onAllItemsChanged: {
        if (pluginApi) {
            try {
                if (!pluginApi.sharedData) {
                    pluginApi.sharedData = {};
                }
                pluginApi.sharedData.allItems = allItems;
                Logger.d("RSS Feed", "RSS Feed BarWidget: Shared", allItems.length, "items to Panel");
            } catch (e) {
                Logger.w("RSS Feed", "BarWidget: Error sharing data:", e);
            }
            updateUnreadCount();
        }
    }

    function updateUnreadCount() {
        let count = 0;
        for (let i = 0; i < allItems.length; i++) {
            const item = allItems[i];
            if (!readItems.includes(item.guid || item.link)) {
                count++;
            }
        }
        unreadCount = count;
    }

    implicitWidth: Math.max(60, isVertical ? Style.capsuleHeight : contentWidth)
    implicitHeight: Math.max(32, isVertical ? contentHeight :Style.capsuleHeight)
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    readonly property real contentWidth: rowLayout.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: rowLayout.implicitHeight + Style.marginM * 2

    // Timer for periodic updates
    Timer {
        id: updateTimer
        interval: updateInterval * 1000
        running: feeds.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Logger.d("RSS Feed", "RSS Feed: Timer triggered, fetching feeds");
            fetchAllFeeds();
        }
    }

    // Process for fetching feeds
    Process {
        id: fetchProcess
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        
        property bool isFetching: false
        property string currentFeedUrl: ""
        property int currentFeedIndex: 0
        property var tempItems: []
        
        onExited: exitCode => {
            if (!isFetching) return;
            
            if (exitCode !== 0) {
                console.error("RSS Feed: curl failed for", currentFeedUrl, "with code", exitCode);
                fetchNextFeed();
                return;
            }
            
            if (!stdout.text || stdout.text.trim() === "") {
                console.error("RSS Feed: Empty response for", currentFeedUrl);
                fetchNextFeed();
                return;
            }
            
            try {
                const items = parseRSSFeed(stdout.text, currentFeedUrl);
                Logger.d("RSS Feed", "RSS Feed: Parsed", items.length, "items from", currentFeedUrl);
                tempItems = tempItems.concat(items);
                fetchNextFeed();
            } catch (e) {
                console.error("RSS Feed: Parse error for", currentFeedUrl, ":", e);
                fetchNextFeed();
            }
        }
    }

    function fetchAllFeeds() {
        if (feeds.length === 0) {
            Logger.d("RSS Feed", "RSS Feed: No feeds configured");
            return;
        }
        
        if (fetchProcess.isFetching) {
            Logger.d("RSS Feed", "RSS Feed: Already fetching");
            return;
        }
        
        Logger.d("RSS Feed", "RSS Feed: Starting fetch for", feeds.length, "feeds");
        loading = true;
        error = false;
        fetchProcess.tempItems = [];
        fetchProcess.currentFeedIndex = 0;
        fetchNextFeed();
    }

    function fetchNextFeed() {
        if (fetchProcess.currentFeedIndex >= feeds.length) {
            // Done fetching all feeds
            fetchProcess.isFetching = false;
            loading = false;
            
            // Sort by date and limit
            let sorted = fetchProcess.tempItems.sort((a, b) => {
                return new Date(b.pubDate) - new Date(a.pubDate);
            });
            
            allItems = sorted;
            Logger.d("RSS Feed", "RSS Feed: Total items:", allItems.length);
            updateUnreadCount();
            return;
        }
        
        const feed = feeds[fetchProcess.currentFeedIndex];
        fetchProcess.currentFeedUrl = feed.url;
        fetchProcess.currentFeedIndex++;
        
        Logger.d("RSS Feed", "RSS Feed: Fetching", fetchProcess.currentFeedUrl);
        
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
        
        // Simple RSS/Atom parser
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
                feedUrl: feedUrl,
                title: cleanText(title),
                link: link,
                description: cleanText(description).substring(0, 200),
                pubDate: pubDate,
                guid: guid
            });
            count++;
        }
        
        return items;
    }

    function extractTag(xml, tag) {
        const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\/${tag}>`, 'i');
        const match = xml.match(regex);
        return match ? match[1] : '';
    }

    function extractAttr(xml, tag, attr) {
        const regex = new RegExp(`<${tag}[^>]*${attr}="([^"]*)"`, 'i');
        const match = xml.match(regex);
        return match ? match[1] : '';
    }

    function cleanText(text) {
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

    function markItemAsRead(guid) {
        if (!pluginApi) return;
        
        if (!readItems.includes(guid)) {
            const newReadItems = readItems.slice();
            newReadItems.push(guid);
            pluginApi.pluginSettings.readItems = newReadItems;
            pluginApi.saveSettings();
            updateUnreadCount();
        }
    }

    function markAllAsRead() {
        if (!pluginApi) return;
        
        const newReadItems = allItems.map(item => item.guid || item.link);
        pluginApi.pluginSettings.readItems = newReadItems;
        pluginApi.saveSettings();
        updateUnreadCount();
    } 

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Style.marginS

        NIcon {
            icon: "rss"
            pointSize: Style.barFontSize
            color: error ? Color.mOnError : loading ? Color.mPrimary : Color.mOnSurface
            
            NumberAnimation on opacity {
                running: loading
                from: 0.3
                to: 1.0
                duration: 1000
                loops: Animation.Infinite
                easing.type: Easing.InOutQuad
            }
        }

        Rectangle {
            visible: unreadCount > 0
            Layout.preferredWidth: badgeText.implicitWidth + 8
            Layout.preferredHeight: width
            radius: width * 0.5
            color: error ? Color.mError : Color.mPrimary

            NText {
                id: badgeText
                anchors.centerIn: parent
                text: unreadCount > 99 ? "99+" : unreadCount.toString()
                pointSize: Style.barFontSize
                color: error ? Color.mOnError : Color.mOnPrimary
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (pluginApi) {
                pluginApi.openPanel(screen);
            }
        }
    }
}
