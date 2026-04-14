import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  // ── Shared state ──
  property var items: []
  property bool loading: false
  property var firstSeenById: ({})

  // Image cache with LRU eviction
  property var imageCache: ({})
  property var imageCacheOrder: []
  property int imageCacheRevision: 0
  readonly property int maxImageCacheSize: 30

  // Auto-paste support
  property bool wtypeAvailable: false

  // ── Settings shortcuts ──
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property int maxHistory: cfg.maxHistory ?? defaults.maxHistory ?? 50
  readonly property int previewWidth: cfg.previewWidth ?? defaults.previewWidth ?? 80
  readonly property bool enableImages: cfg.enableImages ?? defaults.enableImages ?? true
  readonly property bool enableAutoPaste: cfg.enableAutoPaste ?? defaults.enableAutoPaste ?? false
  readonly property int autoPasteDelay: cfg.autoPasteDelay ?? defaults.autoPasteDelay ?? 300
  readonly property bool enableFloatingPopup: cfg.enableFloatingPopup ?? defaults.enableFloatingPopup ?? true

  // ── Floating popup state ──
  property bool popupVisible: false
  // Target screen name (detected before showing popup)
  property string popupTargetScreen: ""
  // Cursor position for Hyprland (local to target screen)
  property real popupCursorX: -1
  property real popupCursorY: -1

  // Popup geometry
  readonly property real popupWidth: 360 * Style.uiScaleRatio
  readonly property real popupMaxHeight: 440 * Style.uiScaleRatio

  // Compositor detection
  readonly property bool isHyprland: CompositorService.isHyprland

  // ── Process: list cliphist items ──
  Process {
    id: listProc
    stdout: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0) {
        root.items = [];
        root.loading = false;
        return;
      }

      const out = String(stdout.text);
      const lines = out.split('\n').filter(l => l.length > 0);
      const limit = root.maxHistory;

      const parsed = [];
      for (let i = 0; i < lines.length && i < limit; i++) {
        const l = lines[i];
        let id = "";
        let preview = "";
        const tab = l.indexOf('\t');
        if (tab > -1) {
          id = l.slice(0, tab);
          preview = l.slice(tab + 1);
        } else {
          const m = l.match(/^(\d+)\s+(.+)$/);
          if (m) {
            id = m[1];
            preview = m[2];
          } else {
            continue;
          }
        }

        const lower = preview.toLowerCase();
        const isImage = lower.startsWith("[image]") || lower.includes("binary data");

        let mime = "text/plain";
        if (isImage) {
          if (lower.includes("png"))
            mime = "image/png";
          else if (lower.includes("jpg") || lower.includes("jpeg"))
            mime = "image/jpeg";
          else if (lower.includes("webp"))
            mime = "image/webp";
          else if (lower.includes("gif"))
            mime = "image/gif";
          else
            mime = "image/*";
        }

        if (!root.firstSeenById[id]) {
          root.firstSeenById[id] = Date.now();
        }

        parsed.push({
          "id": id,
          "preview": preview,
          "isImage": isImage,
          "mime": mime
        });
      }

      root.items = parsed;
      root.loading = false;
    }
  }

  // ── Process: copy to clipboard ──
  Process {
    id: copyToClipboardProc
    property string clipboardId: ""
    stdout: StdioCollector {}

    onExited: exitCode => {
      if (exitCode === 0) {
        ToastService.showNotice(pluginApi?.tr("toast.copied"));
        if (root.enableAutoPaste && root.wtypeAvailable) {
          autoPasteTimer.restart();
        }
      } else {
        ToastService.showError(pluginApi?.tr("toast.failed-to-copy"));
      }
    }
  }

  // ── Process: delete item ──
  Process {
    id: deleteItemProc
    stdout: StdioCollector {}

    onExited: exitCode => {
      root.list();
      ToastService.showNotice(pluginApi?.tr("toast.deleted"));
    }
  }

  // ── Process: wipe all ──
  Process {
    id: wipeProc
    command: ["cliphist", "wipe"]

    onExited: exitCode => {
      root.clearCaches();
      root.list();
      ToastService.showNotice(pluginApi?.tr("toast.cleared"));
    }
  }

  // ── Process: decode image to base64 for cache ──
  Process {
    id: imageDecodeProc
    property string cliphistId: ""
    property string mimeType: "image/png"
    property var callback: null
    stdout: StdioCollector {}

    onExited: exitCode => {
      if (exitCode !== 0) return;

      const base64 = String(stdout.text).trim();
      if (!base64 || base64.length === 0) return;

      // Skip very large images (>10MB estimated)
      const estimatedSize = (base64.length * 3) / 4;
      if (estimatedSize > 10 * 1024 * 1024) return;

      const dataUrl = "data:" + mimeType + ";base64," + base64;
      root.addToImageCache(cliphistId, dataUrl);

      if (callback) callback(dataUrl);
    }
  }

  // ── Process: check wtype availability ──
  Process {
    id: wtypeCheckProc
    command: ["which", "wtype"]
    running: true
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      root.wtypeAvailable = (exitCode === 0);
    }
  }

  // ── Auto-paste timer and process ──
  Timer {
    id: autoPasteTimer
    interval: root.autoPasteDelay
    repeat: false
    onTriggered: {
      if (root.wtypeAvailable) {
        autoPasteProc.running = true;
      } else {
        Logger.w("MiniClipper", "Auto-paste requires wtype");
      }
    }
  }

  Process {
    id: autoPasteProc
    command: ["wtype", "-M", "ctrl", "-M", "shift", "v"]
    running: false
    onExited: exitCode => {
      if (exitCode !== 0) {
        Logger.w("MiniClipper", "wtype auto-paste exited with code: " + exitCode);
      }
    }
  }

  // ── Public functions ──

  function list() {
    if (listProc.running) return;
    root.loading = true;
    listProc.command = ["cliphist", "list", "-preview-width", String(root.previewWidth)];
    listProc.running = true;
  }

  function copyToClipboard(id) {
    if (!id || !/^\d+$/.test(String(id))) return;

    copyToClipboardProc.clipboardId = id;
    copyToClipboardProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"];
    copyToClipboardProc.running = true;
  }

  function deleteById(id) {
    if (!id || !/^\d+$/.test(String(id))) return;

    deleteItemProc.command = ["sh", "-c", "cliphist list | grep '^" + id + "\t' | cliphist delete"];
    deleteItemProc.running = true;
  }

  function wipeAll() {
    wipeProc.running = true;
  }

  function triggerAutoPaste() {
    if (root.enableAutoPaste && root.wtypeAvailable) {
      autoPasteTimer.restart();
    }
  }

  // ── Image cache functions ──

  function addToImageCache(cliphistId, dataUrl) {
    const existingIndex = root.imageCacheOrder.indexOf(cliphistId);
    if (existingIndex !== -1) {
      root.imageCacheOrder = root.imageCacheOrder.filter((_, i) => i !== existingIndex);
    }

    while (root.imageCacheOrder.length >= maxImageCacheSize) {
      const oldestKey = root.imageCacheOrder[0];
      root.imageCacheOrder = root.imageCacheOrder.slice(1);
      const newCache = Object.assign({}, root.imageCache);
      delete newCache[oldestKey];
      root.imageCache = newCache;
    }

    root.imageCache = Object.assign({}, root.imageCache, { [cliphistId]: dataUrl });
    root.imageCacheOrder = [...root.imageCacheOrder, cliphistId];
    root.imageCacheRevision++;
  }

  function getImageData(cliphistId) {
    return root.imageCache[cliphistId] || "";
  }

  function decodeToDataUrl(cliphistId, mimeType, callback) {
    if (!cliphistId || !/^\d+$/.test(String(cliphistId))) return;

    if (root.imageCache[cliphistId]) {
      if (callback) callback(root.imageCache[cliphistId]);
      return;
    }

    imageDecodeProc.cliphistId = cliphistId;
    imageDecodeProc.mimeType = mimeType || "image/png";
    imageDecodeProc.callback = callback;
    imageDecodeProc.command = ["sh", "-c", "cliphist decode " + cliphistId + " | base64 -w 0"];
    imageDecodeProc.running = true;
  }

  function clearCaches() {
    root.imageCache = {};
    root.imageCacheOrder = [];
    root.imageCacheRevision++;
    root.firstSeenById = {};
  }

  // ── Floating popup management ──

  function openFloatingPopup() {
    if (!root.enableFloatingPopup) return;
    if (root.popupVisible) {
      closeFloatingPopup();
      return;
    }

    // Step 1: detect which screen has the cursor, then show popup there
    root.popupCursorX = -1;
    root.popupCursorY = -1;
    root.popupTargetScreen = "";

    if (root.isHyprland) {
      detectScreenHyprProc.running = true;
    } else {
      // Niri / Sway: ask compositor for focused output
      detectScreenNiriProc.running = true;
    }
  }

  // Called after screen detection completes
  function showPopupOnScreen(screenName, cursorLocalX, cursorLocalY) {
    root.popupTargetScreen = screenName;
    root.popupCursorX = cursorLocalX;
    root.popupCursorY = cursorLocalY;
    root.popupVisible = true;
  }

  function closeFloatingPopup() {
    root.popupVisible = false;
    root.popupTargetScreen = "";
    root.popupCursorX = -1;
    root.popupCursorY = -1;
  }

  // ── Screen detection processes ──

  // Niri: get focused output name
  Process {
    id: detectScreenNiriProc
    command: ["niri", "msg", "-j", "focused-output"]
    running: false
    stdout: StdioCollector { id: niriOutputStdout }

    onExited: exitCode => {
      if (exitCode === 0) {
        try {
          const data = JSON.parse(niriOutputStdout.text);
          const screenName = data.name || "";
          if (screenName) {
            root.showPopupOnScreen(screenName, -1, -1);
            return;
          }
        } catch (e) {
          Logger.w("MiniClipper", "Failed to parse niri focused-output");
        }
      }
      // Fallback: use first screen
      const fallback = Quickshell.screens[0]?.name || "";
      Logger.w("MiniClipper", "Niri detection failed, using fallback: " + fallback);
      root.showPopupOnScreen(fallback, -1, -1);
    }
  }

  // Hyprland: get cursor position and derive screen
  Process {
    id: detectScreenHyprProc
    command: ["hyprctl", "cursorpos", "-j"]
    running: false
    stdout: StdioCollector { id: hyprCursorStdout }

    onExited: exitCode => {
      if (exitCode === 0) {
        try {
          const data = JSON.parse(hyprCursorStdout.text);
          const cx = data.x || 0;
          const cy = data.y || 0;

          // Find which screen contains the cursor
          for (let i = 0; i < Quickshell.screens.length; i++) {
            const s = Quickshell.screens[i];
            const sx = s.x || 0;
            const sy = s.y || 0;
            const sw = s.width || 1920;
            const sh = s.height || 1080;
            if (cx >= sx && cx < sx + sw && cy >= sy && cy < sy + sh) {
              root.showPopupOnScreen(s.name, cx - sx, cy - sy);
              return;
            }
          }
        } catch (e) {
          Logger.w("MiniClipper", "Failed to parse hyprctl cursorpos");
        }
      }
      // Fallback
      const fallback = Quickshell.screens[0]?.name || "";
      root.showPopupOnScreen(fallback, -1, -1);
    }
  }

  // Refresh list for panel/popup consumption
  function refreshOnPanelOpen() {
    root.list();
  }

  // ── IPC handler ──
  IpcHandler {
    target: "plugin:mini-clipper"

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen);
        });
      }
    }

    function openPanel() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.openPanel(screen);
        });
      }
    }

    function togglePopup() {
      if (root.popupVisible) {
        root.closeFloatingPopup();
      } else {
        root.list();
        root.openFloatingPopup();
      }
    }

    function clear() {
      root.wipeAll();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  Floating popup overlay — single PanelWindow on the
  //  detected screen (avoids multi-screen Exclusive focus
  //  conflicts on Niri)
  // ══════════════════════════════════════════════════════════
  Variants {
    model: {
      if (!root.popupVisible || !root.popupTargetScreen) return [];
      // Filter Quickshell.screens to only the target
      const screens = Quickshell.screens;
      const result = [];
      for (let i = 0; i < screens.length; i++) {
        if (screens[i].name === root.popupTargetScreen) {
          result.push(screens[i]);
          break;
        }
      }
      return result;
    }

    delegate: PanelWindow {
      id: popupWindow
      required property var modelData

      screen: modelData
      anchors.top: true
      anchors.left: true
      anchors.right: true
      anchors.bottom: true
      visible: true
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "noctalia-mini-clipper-popup"
      WlrLayershell.exclusionMode: ExclusionMode.Ignore

      Component.onCompleted: {
        positionAndShow();
      }

      function positionAndShow() {
        const sw = popupWindow.screen.width || 1920;
        const sh = popupWindow.screen.height || 1080;

        let px, py;
        if (root.popupCursorX >= 0 && root.popupCursorY >= 0) {
          // Position near cursor (Hyprland)
          px = root.popupCursorX;
          py = root.popupCursorY;
          if (px + root.popupWidth > sw) px = sw - root.popupWidth - Style.marginL;
          if (py + root.popupMaxHeight > sh) py = sh - root.popupMaxHeight - Style.marginL;
          if (px < Style.marginL) px = Style.marginL;
          if (py < Style.marginL) py = Style.marginL;
        } else {
          // Center on screen (Niri)
          px = (sw - root.popupWidth) / 2;
          py = (sh - root.popupMaxHeight) / 2;
        }

        popupCard.x = px;
        popupCard.y = py;
        popupCard.visible = true;
        popupCard.focusPopupSearch();
      }

      // Background click dismisses popup
      MouseArea {
        id: overlayMouse
        anchors.fill: parent
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        Keys.onEscapePressed: {
          root.closeFloatingPopup();
        }

        onClicked: {
          root.closeFloatingPopup();
        }
      }

      // ── The popup card ──
      Rectangle {
        id: popupCard
        visible: false
        width: root.popupWidth
        height: root.popupMaxHeight
        radius: Style.radiusL
        color: Qt.alpha(Color.mSurface, 0.95)
        border.color: Color.mOutline
        border.width: Style.borderS

        // Prevent clicks on card from dismissing the overlay
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.AllButtons
          onClicked: mouse => mouse.accepted = true
        }

        // Inline popup state
        property string popupSearchQuery: ""
        property int popupSelectedIndex: -1

        readonly property var popupFilteredItems: {
          if (!popupCard.popupSearchQuery || popupCard.popupSearchQuery.length === 0)
            return root.items;
          const q = popupCard.popupSearchQuery.toLowerCase();
          return root.items.filter(item => {
            const preview = (item.preview || "").toLowerCase();
            return preview.includes(q);
          });
        }

        onPopupSearchQueryChanged: {
          popupSelectedIndex = popupFilteredItems.length > 0 ? 0 : -1;
        }

        function focusPopupSearch() {
          popupSearchQuery = "";
          popupSelectedIndex = -1;
          popupSearchInput.text = "";
          Qt.callLater(function() {
            if (popupSearchInput && popupSearchInput.inputItem) {
              popupSearchInput.inputItem.forceActiveFocus();
            } else {
              popupSearchInput.forceActiveFocus();
            }
          });
        }

        function activatePopupSelected() {
          if (popupSelectedIndex >= 0 && popupSelectedIndex < popupFilteredItems.length) {
            const item = popupFilteredItems[popupSelectedIndex];
            if (item) {
              root.copyToClipboard(item.id);
              root.closeFloatingPopup();
            }
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          // ── HEADER ──
          NBox {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(popupHeaderRow.implicitHeight + Style.marginM * 2 + 1)

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginM

              RowLayout {
                id: popupHeaderRow

                NIcon {
                  icon: "clipboard"
                  pointSize: Style.fontSizeXL
                  color: Color.mPrimary
                }

                NLabel {
                  label: root.pluginApi?.tr("popup.title")
                }

                Item {
                  Layout.fillWidth: true
                }

                NIconButton {
                  icon: "x"
                  tooltipText: root.pluginApi?.tr("panel.close")
                  baseSize: Style.baseWidgetSize * 0.8
                  onClicked: root.closeFloatingPopup()
                }
              }
            }
          }

          // ── CONTENT ──
          NBox {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginM

              // Search
              NTextInput {
                id: popupSearchInput
                Layout.fillWidth: true
                placeholderText: root.pluginApi?.tr("panel.search-placeholder")
                text: popupCard.popupSearchQuery
                onTextChanged: popupCard.popupSearchQuery = text

                Keys.onDownPressed: {
                  if (popupCard.popupFilteredItems.length > 0) {
                    popupCard.popupSelectedIndex = Math.min(
                      popupCard.popupSelectedIndex + 1,
                      popupCard.popupFilteredItems.length - 1
                    );
                    popupListView.positionViewAtIndex(popupCard.popupSelectedIndex, ListView.Contain);
                  }
                }
                Keys.onUpPressed: {
                  if (popupCard.popupSelectedIndex > 0) {
                    popupCard.popupSelectedIndex = popupCard.popupSelectedIndex - 1;
                    popupListView.positionViewAtIndex(popupCard.popupSelectedIndex, ListView.Contain);
                  }
                }
                Keys.onReturnPressed: popupCard.activatePopupSelected()
                Keys.onEscapePressed: {
                  if (popupCard.popupSearchQuery !== "") {
                    popupCard.popupSearchQuery = "";
                    popupSearchInput.text = "";
                    popupCard.popupSelectedIndex = -1;
                  } else {
                    root.closeFloatingPopup();
                  }
                }
              }

              // List
              ListView {
                id: popupListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Style.marginXL * 2
                clip: true
                currentIndex: popupCard.popupSelectedIndex
                spacing: 0

                model: popupCard.popupFilteredItems

                delegate: ClipboardItem {
                  required property var modelData
                  required property int index
                  width: popupListView.width
                  pluginApi: root.pluginApi
                  mainInstance: root
                  itemData: modelData
                  selected: index === popupCard.popupSelectedIndex

                  onCopyRequested: itemId => {
                    root.copyToClipboard(itemId);
                    root.closeFloatingPopup();
                  }

                  onDeleteRequested: itemId => {
                    root.deleteById(itemId);
                  }
                }

                // Empty / no results
                header: Item {
                  width: popupListView.width
                  height: popupEmptyText.visible || popupNoResultsText.visible ? Style.marginXL * 3 : 0
                  visible: popupEmptyText.visible || popupNoResultsText.visible

                  ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginM

                    NIcon {
                      visible: root.items.length === 0
                      icon: "clipboard"
                      pointSize: Style.fontSizeXXL * 2
                      color: Color.mOnSurfaceVariant
                      Layout.alignment: Qt.AlignHCenter
                    }

                    NText {
                      id: popupEmptyText
                      visible: root.items.length === 0
                      text: root.pluginApi?.tr("panel.empty")
                      font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                      color: Color.mOnSurfaceVariant
                      Layout.alignment: Qt.AlignHCenter
                    }

                    NText {
                      id: popupNoResultsText
                      visible: root.items.length > 0 && popupCard.popupFilteredItems.length === 0
                      text: root.pluginApi?.tr("panel.no-results")
                      font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                      color: Color.mOnSurfaceVariant
                      Layout.alignment: Qt.AlignHCenter
                    }
                  }
                }
              }
            }
          }
        }
      }

    }
  }

  // ── Lifecycle ──

  Component.onCompleted: {
    Logger.i("MiniClipper", "Initialized");
    root.list();
  }

  Component.onDestruction: {
    if (listProc.running) listProc.terminate();
    if (copyToClipboardProc.running) copyToClipboardProc.terminate();
    if (deleteItemProc.running) deleteItemProc.terminate();
    if (wipeProc.running) wipeProc.terminate();
    if (imageDecodeProc.running) imageDecodeProc.terminate();
    if (wtypeCheckProc.running) wtypeCheckProc.terminate();
    if (autoPasteProc.running) autoPasteProc.terminate();
    if (detectScreenNiriProc.running) detectScreenNiriProc.terminate();
    if (detectScreenHyprProc.running) detectScreenHyprProc.terminate();
    autoPasteTimer.stop();

    root.closeFloatingPopup();
    root.clearCaches();
    root.items = [];
  }
}
