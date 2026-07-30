import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Effects

Item {
    id: root

    // ── Shell integration interface ───────────────────────────────────────────
    // Wrapper provides these; Carousel is fully shell-agnostic.

    property string defaultWallpaperFolder: ""
    property string currentWallpaperPath: ""   // full path; used to highlight current item on open
    property var extraDirectories: []           // other directories to pre-scan/cache (Noctalia multi-monitor)
    property string wlrNamespace: "plugins:wallpaperCarousel"
    property var cfg: ({})                      // raw settings object from the host shell
    property var getFocusedScreen: () => null   // () => Screen | null
    property bool hasWallpaperConfigured: true
    property string shellSettingsHint: "Open your shell settings → Wallpaper to configure a wallpaper directory."

    signal wallpaperPicked(string fullPath, string screenName)

    readonly property var overlayScreen: overlay.screen  // wrappers can bind against this

    // ── Derived settings with defaults ────────────────────────────────────────
    readonly property string wallpaperFolder: {
        const ov = (cfg.wallpaperDirectory ?? "").trim();
        return ov || defaultWallpaperFolder;
    }

    readonly property string _carouselMode: cfg.carouselMode ?? "wrap"
    readonly property bool _isInfinite: _carouselMode === "infinite"
    readonly property bool _wrapsIndex: _carouselMode !== "standard"
    on_CarouselModeChanged: if (_initialSyncDone) Qt.callLater(_syncStableModel)

    readonly property var _currentView: _isInfinite ? pathView : listView
    readonly property string wallpaperFolderUrl: "file://" + wallpaperFolder

    // ── Folder cache ──────────────────────────────────────────────────────────
    property var _folderCache: ({})
    property bool _initialSyncDone: false

    readonly property var _nameFilters: [
        "*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif",
        "*.bmp", "*.jxl", "*.avif", "*.heif", "*.exr"
    ]

    onWallpaperFolderUrlChanged: {
        modelSyncTimer.stop();
        const cached = _folderCache[wallpaperFolder];
        if (cached) {
            _populateStableModel(cached);
            carousel.tryFocus();
        } else {
            stableModel.clear();
        }
        root._initialSyncDone = false;
    }

    ListModel { id: stableModel }

    Timer {
        id: modelSyncTimer
        interval: 1500
        onTriggered: root._syncStableModel()
    }

    FolderListModel {
        id: folderModel
        folder: root.wallpaperFolderUrl
        nameFilters: root._nameFilters
        showDirs: false
        sortField: FolderListModel.Name

        onStatusChanged: {
            if (status === FolderListModel.Ready && !root._initialSyncDone) {
                root._syncStableModel();
                root._initialSyncDone = true;
            }
        }
        onCountChanged: {
            if (root._initialSyncDone)
                modelSyncTimer.restart();
        }
    }

    function _readFolderModel(model) {
        var entries = [];
        for (var i = 0; i < model.count; i++)
            entries.push({
                fileName: model.get(i, "fileName"),
                fileUrl:  model.get(i, "fileUrl").toString()
            });
        return entries;
    }

    function _populateStableModel(entries) {
        const activeView = root._currentView;
        const savedIndex = activeView.currentIndex;
        const savedFile = (savedIndex >= 0 && savedIndex < stableModel.count)
            ? stableModel.get(savedIndex).fileName : "";

        stableModel.clear();
        for (let i = 0; i < entries.length; i++)
            stableModel.append(entries[i]);

        if (root._isInfinite && entries.length > 0) {
            const viewWidth = pathView.width > 0 ? pathView.width : 2560;
            const minCount = Math.ceil(viewWidth / carousel.itemWidth) + 6;
            const baseCount = entries.length;
            const targetCount = baseCount * Math.ceil(minCount / baseCount);
            while (stableModel.count < targetCount) {
                for (let i = 0; i < baseCount && stableModel.count < targetCount; i++)
                    stableModel.append(entries[i]);
            }
        }

        if (savedFile) {
            for (let i = 0; i < stableModel.count; i++) {
                if (stableModel.get(i).fileName === savedFile) {
                    activeView.currentIndex = i;
                    break;
                }
            }
        }
    }

    function _syncStableModel() {
        const entries = _readFolderModel(folderModel);
        root._folderCache[root.wallpaperFolder] = entries;
        _populateStableModel(entries);
        carousel.tryFocus();
    }

    // ── Public API ────────────────────────────────────────────────────────────
    function toggle() {
        if (overlay.visible) close(); else open();
    }

    function open() {
        carousel.initialFocusSet = false;
        const focusedScreen = root.getFocusedScreen();
        if (focusedScreen)
            overlay.screen = focusedScreen;
        overlay.visible = true;
        carousel.tryFocus();
        root._currentView.forceActiveFocus();
        Qt.callLater(() => root._currentView.forceActiveFocus());
    }

    function close() {
        overlay.visible = false;
    }

    function cycle(direction: int): string {
        const v = root._currentView;
        if (!overlay.visible) {
            open();
            return "opened:" + v.currentIndex;
        }
        if (direction > 0) v.incrementCurrentIndex();
        else v.decrementCurrentIndex();
        return "index:" + v.currentIndex;
    }

    // ── IPC (Quickshell — available on both DMS and Noctalia) ─────────────────
    IpcHandler {
        target: "wallpaperCarousel"
        function toggle(): string   { root.toggle(); return overlay.visible ? "opened" : "closed"; }
        function open(): string     { if (!overlay.visible) root.open(); return "opened"; }
        function close(): string    { if (overlay.visible) root.close(); return "closed"; }
        function cycleNext(): string     { return root.cycle(+1); }
        function cyclePrevious(): string { return root.cycle(-1); }
    }

    // ── Fullscreen overlay window ─────────────────────────────────────────────
    PanelWindow {
        id: overlay
        visible: false
        color: "transparent"

        WlrLayershell.namespace: root.wlrNamespace
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors { top: true; left: true; right: true; bottom: true }

        Rectangle {
            anchors.fill: parent
            color: "#CC000000"
            opacity: overlay.visible ? carousel.overlayOpacity / 100 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: overlay.visible && carousel.confirmingIndex < 0
            onClicked: root.close()
        }

        // ── Carousel ──────────────────────────────────────────────────────────
        Item {
            id: carousel
            anchors.fill: parent
            opacity: overlay.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            property bool initialFocusSet: false

            function tryFocus() {
                if (initialFocusSet) return;

                let targetIndex = 0;
                const currentFile = (root.currentWallpaperPath || "").split('/').pop();
                if (currentFile && stableModel.count > 0) {
                    for (let i = 0; i < stableModel.count; i++) {
                        if (stableModel.get(i).fileName === currentFile) {
                            targetIndex = i;
                            break;
                        }
                    }
                }

                const v = root._currentView;
                if (v.count > 0) {
                    const safeIndex = Math.min(targetIndex, v.count - 1);
                    v.currentIndex = safeIndex;
                    if (!root._isInfinite)
                        v.positionViewAtIndex(safeIndex, ListView.Center);
                    initialFocusSet = true;
                }

                carousel.heldIndex = -1;
                holdTimer.start();
            }

            readonly property int itemWidth:    parseInt(root.cfg.itemWidth)  || 300
            readonly property int itemHeight:   parseInt(root.cfg.itemHeight) || 420
            readonly property int borderWidth:  (root.cfg.borderWidth  !== undefined) ? parseInt(root.cfg.borderWidth)  : 3
            readonly property int overlayOpacity: (root.cfg.overlayOpacity !== undefined) ? parseInt(root.cfg.overlayOpacity) : 80
            readonly property int cornerRadius: (root.cfg.cornerRadius !== undefined) ? parseInt(root.cfg.cornerRadius) : 0
            readonly property bool enableRounding: cornerRadius > 0
            readonly property real skewFactor: -0.35
            readonly property int _baseWallpaperCount: folderModel.count

            readonly property real selectedScale: {
                let val = (root.cfg.selectedScale !== undefined) ? parseFloat(root.cfg.selectedScale) : 108;
                return val > 10 ? val / 100.0 : val;
            }
            readonly property bool expandSelected: !!(root.cfg.expandSelected === true || root.cfg.expandSelected === "true")
            readonly property real expandMultiplier: ((root.cfg.expandMultiplier !== undefined) ? parseInt(root.cfg.expandMultiplier) : 120) / 100.0
            readonly property bool enableHoldExpand: !!(root.cfg.enableHoldExpand === true || root.cfg.enableHoldExpand === "true")
            readonly property real holdExpandRatio: ((root.cfg.holdExpandRatio !== undefined) ? parseFloat(root.cfg.holdExpandRatio) : 35.0) / 100.0
            readonly property int holdDelay: (root.cfg.holdDelay !== undefined) ? parseInt(root.cfg.holdDelay) : 1500

            property int heldIndex: -1

            Timer {
                id: holdTimer
                interval: carousel.holdDelay
                onTriggered: {
                    if (carousel.enableHoldExpand)
                        carousel.heldIndex = root._currentView.currentIndex;
                }
            }

            property int confirmingIndex: -1

            function confirmPick(idx, path) {
                confirmingIndex = idx;
                confirmTimer.start();
                if (path) {
                    const screenName = overlay.screen ? overlay.screen.name : "";
                    root.wallpaperPicked(path, screenName);
                }
            }

            Timer {
                id: confirmTimer
                interval: 300
                onTriggered: {
                    carousel.confirmingIndex = -1;
                    root.close();
                }
            }

            // ── Shared delegate ───────────────────────────────────────────────
            Component {
                id: carouselDelegate

                Item {
                    id: delegateRoot
                    width: carousel.itemWidth
                    height: carousel.itemHeight
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                    required property int index
                    required property string fileName
                    required property string fileUrl

                    readonly property bool isCurrent: root._isInfinite ? PathView.isCurrentItem : ListView.isCurrentItem

                    readonly property int distFromCenter: {
                        if (root._isInfinite) {
                            const n = stableModel.count;
                            if (n <= 1) return 0;
                            const d = Math.abs(index - pathView.currentIndex);
                            return Math.min(d, n - d);
                        }
                        return Math.abs(index - listView.currentIndex);
                    }

                    readonly property real falloff: 1.0 / (1.0 + distFromCenter * distFromCenter)

                    readonly property real _dupeFade: {
                        if (!root._isInfinite) return 1.0;
                        const base = carousel._baseWallpaperCount;
                        if (base <= 0 || base >= stableModel.count) return 1.0;
                        const n = stableModel.count;
                        const cur = pathView.currentIndex;
                        const wpOffset = ((index % base) - (cur % base) + base) % base;
                        const leftCount  = Math.floor(base / 2);
                        const rightCount = Math.floor((base - 1) / 2);
                        let target;
                        if (wpOffset === 0)
                            target = cur;
                        else if (wpOffset <= rightCount)
                            target = (cur + wpOffset) % n;
                        else if (base - wpOffset <= leftCount)
                            target = (cur - (base - wpOffset) + n) % n;
                        else
                            return 0.0;
                        return index === target ? 1.0 : 0.0;
                    }

                    z: carousel.confirmingIndex === index ? 100 : isCurrent ? 10 : Math.max(1, 10 - distFromCenter)

                    function pickWallpaper() {
                        if (carousel.confirmingIndex >= 0) return;
                        carousel.confirmPick(index, root.wallpaperFolder + "/" + fileName);
                    }

                    MouseArea {
                        id: delegateMouseArea
                        x: carousel.skewFactor * carousel.itemHeight / 2
                        width: parent.width
                        height: parent.height
                        hoverEnabled: true
                        onClicked: delegateRoot.pickWallpaper()
                    }

                    readonly property real extraSpace:     carousel.itemWidth * carousel.expandMultiplier - carousel.itemWidth
                    readonly property real heldExtraSpace: carousel.width * carousel.holdExpandRatio - carousel.itemWidth

                    readonly property real visualXOffset: {
                        if (!carousel.expandSelected && carousel.heldIndex < 0) return 0;
                        if (carousel.heldIndex === index) return 0;
                        if (distFromCenter === 0) return 0;
                        const space = (carousel.heldIndex >= 0) ? heldExtraSpace : extraSpace;
                        let signedDist = 0;
                        if (root._isInfinite) {
                            let d = index - pathView.currentIndex;
                            const h = stableModel.count / 2;
                            if (d > h) d -= stableModel.count;
                            else if (d < -h) d += stableModel.count;
                            signedDist = d;
                        } else {
                            signedDist = index - listView.currentIndex;
                        }
                        return signedDist > 0 ? (space / 2) : -(space / 2);
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: visualXOffset

                        readonly property bool isConfirmed: carousel.confirmingIndex === delegateRoot.index
                        readonly property bool isHeld: carousel.heldIndex === delegateRoot.index

                        width:  isHeld ? (carousel.width  * carousel.holdExpandRatio) : ((carousel.expandSelected && isCurrent) ? (carousel.itemWidth * carousel.expandMultiplier) : carousel.itemWidth)
                        height: isHeld ? (carousel.height * carousel.holdExpandRatio) : parent.height

                        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }
                        Behavior on width  { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }
                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }

                        readonly property bool isOtherConfirming: carousel.confirmingIndex >= 0 && !isConfirmed
                        readonly property bool isHovered: delegateMouseArea.containsMouse && carousel.confirmingIndex < 0

                        readonly property real baseScale:  0.75
                        readonly property real scaleRange: carousel.selectedScale - 0.75

                        scale:   isConfirmed ? 1.6 : isOtherConfirming ? (baseScale + scaleRange * delegateRoot.falloff) * 0.8 : isHovered ? baseScale + (scaleRange + 0.20) * delegateRoot.falloff : baseScale + scaleRange * delegateRoot.falloff
                        opacity: (isConfirmed ? 0.0 : isOtherConfirming ? 0.0 : isHovered ? 1.0 : 0.1 + 0.9 * delegateRoot.falloff) * delegateRoot._dupeFade
                        layer.enabled: opacity < 1 && opacity > 0 && !isConfirmed

                        Behavior on scale   { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        transform: Matrix4x4 {
                            property real s: carousel.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                        }

                        Item {
                            anchors.fill: parent

                            Rectangle {
                                id: cornerMask
                                width: parent.width; height: parent.height
                                radius: carousel.cornerRadius
                                visible: false
                                layer.enabled: true
                            }

                            layer.enabled: carousel.enableRounding
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: cornerMask
                                maskSpreadAtMin: 1.0
                                maskThresholdMin: 0.5
                            }

                            Image {
                                anchors.fill: parent
                                source: delegateRoot.fileUrl
                                sourceSize: (carousel.heldIndex === delegateRoot.index) ? Qt.size(width, height) : Qt.size(carousel.itemWidth, carousel.itemHeight)
                                fillMode: Image.Stretch
                                asynchronous: true
                                visible: innerImage.status === Image.Ready
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: carousel.borderWidth
                                visible: innerImage.status === Image.Ready

                                Rectangle { anchors.fill: parent; color: "black" }
                                clip: true

                                Image {
                                    id: innerImage
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: -50
                                    width: parent.width + (parent.height * Math.abs(carousel.skewFactor)) + 50
                                    height: parent.height
                                    fillMode: Image.PreserveAspectCrop
                                    source: delegateRoot.fileUrl
                                    sourceSize: (carousel.heldIndex === delegateRoot.index) ? Qt.size(width, height) : Qt.size(carousel.itemWidth, carousel.itemHeight)
                                    asynchronous: true

                                    transform: Matrix4x4 {
                                        property real s: -carousel.skewFactor
                                        matrix: Qt.matrix4x4(1, s, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── PathView — looping ────────────────────────────────────────────
            PathView {
                id: pathView
                anchors.fill: parent
                visible: root._isInfinite

                model: root._isInfinite ? stableModel : null
                delegate: carouselDelegate

                pathItemCount: Math.max(1, Math.min(stableModel.count, Math.ceil(width / carousel.itemWidth) + 4))
                cacheItemCount: 4

                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange

                highlightMoveDuration: carousel.initialFocusSet ? 150 : 0
                movementDirection: PathView.Shortest

                focus: root._isInfinite && overlay.visible

                Keys.onPressed: event => {
                    if (carousel.confirmingIndex >= 0) { event.accepted = true; return; }
                    if (event.key === Qt.Key_Escape) {
                        root.close(); event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        decrementCurrentIndex(); event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        incrementCurrentIndex(); event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentItem) currentItem.pickWallpaper();
                        event.accepted = true;
                    }
                }

                onCountChanged: carousel.tryFocus()
                onCurrentIndexChanged: {
                    carousel.heldIndex = -1;
                    holdTimer.restart();
                }

                readonly property real _pathLen: pathItemCount * carousel.itemWidth
                readonly property real _pathX0:  (width - _pathLen) / 2
                path: Path {
                    startX: pathView._pathX0
                    startY: pathView.height / 2 - carousel.itemHeight / 2
                    PathLine {
                        x: pathView._pathX0 + pathView._pathLen
                        y: pathView.height / 2 - carousel.itemHeight / 2
                    }
                }
            }

            // ── ListView — wrap / standard ────────────────────────────────────
            ListView {
                id: listView
                anchors.fill: parent
                visible: !root._isInfinite

                model: root._isInfinite ? null : stableModel
                delegate: carouselDelegate

                spacing: 0
                orientation: ListView.Horizontal
                clip: false
                cacheBuffer: 5000

                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width / 2) - (carousel.itemWidth / 2)
                preferredHighlightEnd:   (width / 2) + (carousel.itemWidth / 2)

                highlightMoveDuration: carousel.initialFocusSet ? 150 : 0

                focus: !root._isInfinite && overlay.visible

                Keys.onPressed: event => {
                    if (carousel.confirmingIndex >= 0) { event.accepted = true; return; }
                    if (event.key === Qt.Key_Escape) {
                        root.close(); event.accepted = true;
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        if (currentIndex > 0) decrementCurrentIndex();
                        else if (root._wrapsIndex) currentIndex = count - 1;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        if (currentIndex < count - 1) incrementCurrentIndex();
                        else if (root._wrapsIndex) currentIndex = 0;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        currentIndex = 0; event.accepted = true;
                    } else if (event.key === Qt.Key_End) {
                        currentIndex = count - 1; event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (currentItem) currentItem.pickWallpaper();
                        event.accepted = true;
                    }
                }

                onCountChanged: carousel.tryFocus()
                onCurrentIndexChanged: {
                    carousel.heldIndex = -1;
                    holdTimer.restart();
                }
            }
        }

        // ── Invalid override directory ─────────────────────────────────────────
        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: overlay.visible && (root.cfg.wallpaperDirectory ?? "").trim() && folderModel.status !== FolderListModel.Ready

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Directory not found"
                font.pixelSize: 24; font.bold: true; color: "white"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "The configured directory '" + (root.cfg.wallpaperDirectory ?? "") + "' does not exist.\nCheck the path in Wallpaper Carousel settings."
                font.pixelSize: 14; color: "#BBBBBB"; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press Escape to close"
                font.pixelSize: 12; color: "#888888"
            }
        }

        // ── Empty folder ──────────────────────────────────────────────────────
        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: overlay.visible && folderModel.status === FolderListModel.Ready && folderModel.count === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hasWallpaperConfigured ? "No images found in wallpaper folder" : "No wallpaper configured"
                font.pixelSize: 24; font.bold: true; color: "white"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hasWallpaperConfigured
                    ? "The folder '" + root.wallpaperFolder + "' is empty.\nAdd images or choose a different wallpaper directory."
                    : root.shellSettingsHint
                font.pixelSize: 14; color: "#BBBBBB"; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press Escape to close"
                font.pixelSize: 12; color: "#888888"
            }
        }
    }

    // ── Pre-cache window ──────────────────────────────────────────────────────
    PanelWindow {
        id: cacheWindow
        visible: true
        color: "transparent"
        width: 1; height: 1

        WlrLayershell.namespace: root.wlrNamespace + ":precache"
        WlrLayershell.layer: WlrLayershell.Background
        WlrLayershell.exclusiveZone: 0
        anchors { top: true; left: true }

        Item {
            width: 1; height: 1
            clip: true

            Repeater {
                model: stableModel
                Image {
                    width: carousel.itemWidth; height: carousel.itemHeight
                    asynchronous: true
                    source: fileUrl
                    sourceSize: Qt.size(carousel.itemWidth, carousel.itemHeight)
                    fillMode: Image.PreserveAspectCrop
                }
            }

            // Pre-scan and cache other monitor directories (provided by wrapper)
            Repeater {
                model: root.extraDirectories
                Item {
                    property string dir: modelData
                    FolderListModel {
                        id: extraFolderModel
                        folder: "file://" + dir
                        nameFilters: root._nameFilters
                        showDirs: false
                        sortField: FolderListModel.Name
                        onStatusChanged: {
                            if (status === FolderListModel.Ready)
                                root._folderCache[dir] = root._readFolderModel(extraFolderModel);
                        }
                        onCountChanged: {
                            if (status === FolderListModel.Ready)
                                root._folderCache[dir] = root._readFolderModel(extraFolderModel);
                        }
                    }
                    Repeater {
                        model: extraFolderModel
                        Image {
                            width: carousel.itemWidth; height: carousel.itemHeight
                            asynchronous: true
                            source: fileUrl
                            sourceSize: Qt.size(carousel.itemWidth, carousel.itemHeight)
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }
            }
        }
    }
}
