import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
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
    property int _prevUnreadCount: 0
    property bool _seenInitialUnreadSet: false
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

            // Read unreadCount exposed by Panel (if provided) so badge updates promptly
            if (pluginApi && typeof pluginApi.unreadCount === 'number') {
                if (unreadCount !== pluginApi.unreadCount) {
                    // Use update function so pulse logic runs
                    _prevUnreadCount = unreadCount;
                    unreadCount = pluginApi.unreadCount;
                    updateUnreadCount();
                }
            }
        }
    }

    Component.onCompleted: {
        // Adopt unread count from Panel immediately if available
        if (pluginApi && typeof pluginApi.unreadCount === 'number') {
            unreadCount = pluginApi.unreadCount;
            _prevUnreadCount = unreadCount; // don't pulse on initial load
            _seenInitialUnreadSet = true;
        } else {
            updateUnreadCount();
        }
    }

    onPluginApiChanged: {
        if (pluginApi && typeof pluginApi.unreadCount === 'number') {
            unreadCount = pluginApi.unreadCount;
            _prevUnreadCount = unreadCount; // don't pulse on injection
            _seenInitialUnreadSet = true;
        }
    }

    // Expose state to pluginApi for Panel access
    onAllItemsChanged: {
        if (pluginApi) {
            try {
                // Only write if sharedData object already exists to avoid creating non-configurable properties
                if (pluginApi.sharedData !== undefined && pluginApi.sharedData !== null) {
                    pluginApi.sharedData.allItems = allItems;
                    Logger.d("RSS Feed", "RSS Feed BarWidget: Shared", allItems.length, "items to Panel");
                } else {
                    Logger.d("RSS Feed", "RSS Feed BarWidget: sharedData not available, skipping share");
                }
            } catch (e) {
                Logger.w("RSS Feed", "BarWidget: Error sharing data:", e);
            }
            updateUnreadCount();
        }
    }

    function updateUnreadCount() {
        var previous = _prevUnreadCount || 0;

        // Prefer value provided by Panel via pluginApi when available
        if (pluginApi && typeof pluginApi.unreadCount === 'number') {
            var newVal = Number(pluginApi.unreadCount) || 0;
            if (newVal !== unreadCount) {
                if (_seenInitialUnreadSet && newVal > previous) {
                    if (badgePulseDebounce) badgePulseDebounce.restart();
                }
                unreadCount = newVal;
            }
            _prevUnreadCount = unreadCount;
            return;
        }

        let count = 0;
        for (let i = 0; i < allItems.length; i++) {
            const item = allItems[i];
            if (!readItems.includes(item.guid || item.link)) {
                count++;
            }
        }

        if (count !== unreadCount) {
            if (_seenInitialUnreadSet && count > previous) {
                if (badgePulseDebounce) badgePulseDebounce.restart();
            }
            unreadCount = count;
        }
        _prevUnreadCount = unreadCount;
        _seenInitialUnreadSet = true;
    }

    readonly property real visualContentWidth: rowLayout.implicitWidth + (unreadCount > 0 ? Style.marginM * 2 : Style.marginS)
    readonly property real visualContentHeight: rowLayout.implicitHeight + (unreadCount > 0 ? Style.marginM * 2 : Style.marginS)

    readonly property real contentWidth: Math.max(48, isVertical ? Style.capsuleHeight : visualContentWidth)
    readonly property real contentHeight: Math.max(28, isVertical ? visualContentHeight : Style.capsuleHeight)

    implicitWidth: contentWidth
    implicitHeight: contentHeight

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
                Logger.e("RSS Feed: curl failed for", currentFeedUrl, "with code", exitCode);
                fetchNextFeed();
                return;
            }
            
            if (!stdout.text || stdout.text.trim() === "") {
                Logger.e("RSS Feed: Empty response for", currentFeedUrl);
                fetchNextFeed();
                return;
            }
            
            try {
                const items = parseRSSFeed(stdout.text, currentFeedUrl);
                Logger.d("RSS Feed", "RSS Feed: Parsed", items.length, "items from", currentFeedUrl);
                tempItems = tempItems.concat(items);
                fetchNextFeed();
            } catch (e) {
                Logger.e("RSS Feed: Parse error for", currentFeedUrl, ":", e);
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
            if (!pluginApi.pluginSettings) {
                pluginApi.pluginSettings = {};
            }
            pluginApi.pluginSettings.readItems = newReadItems;
            pluginApi.saveSettings();
            updateUnreadCount();
        }
    }

    function markAllAsRead() {
        if (!pluginApi) return;
        
        const newReadItems = allItems.map(item => item.guid || item.link);
        if (!pluginApi.pluginSettings) {
            pluginApi.pluginSettings = {};
        }
        pluginApi.pluginSettings.readItems = newReadItems;
        pluginApi.saveSettings();
        updateUnreadCount();
    } 




    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusM
        color: Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: unreadCount > 0 ? Style.marginS : 0

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
                id: badgeRect
                visible: unreadCount > 0
                width: unreadCount > 0 ? (badgeText.implicitWidth + 8) : 0
                height: unreadCount > 0 ? (badgeText.implicitHeight + 6) : 0
                radius: height * 0.5
                color: error ? Color.mError : Color.mPrimary
                Layout.preferredWidth: width
                Layout.preferredHeight: height

                transform: Scale { id: badgeScale; xScale: 1; yScale: 1 }

                NText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: unreadCount > 99 ? "99+" : unreadCount.toString()
                    pointSize: Style.barFontSize
                    color: error ? Color.mOnError : Color.mOnPrimary
                }

                SequentialAnimation {
                    id: badgePulse
                    running: false
                    PropertyAnimation { target: badgeScale; property: "xScale"; to: 1.15; duration: 140; easing.type: Easing.InOutQuad }
                    PropertyAnimation { target: badgeScale; property: "yScale"; to: 1.15; duration: 140; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 80 }
                    PropertyAnimation { target: badgeScale; property: "xScale"; to: 1.0; duration: 160; easing.type: Easing.InOutQuad }
                    PropertyAnimation { target: badgeScale; property: "yScale"; to: 1.0; duration: 160; easing.type: Easing.InOutQuad }
                }

                Timer {
                    id: badgePulseDebounce
                    interval: 250
                    running: false
                    repeat: false
                    onTriggered: {
                        if (badgePulse) badgePulse.restart();
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!pluginApi) return;
            try {
                pluginApi.openPanel(root.screen, root);
            } catch (e) {
                // Fallback to older/other signatures if available
                try {
                    pluginApi.openPanel(screen);
                } catch (err) {
                    Logger.w("RSS Feed", "openPanel failed:", err);
                }
            }
        }
    }
}
