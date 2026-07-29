import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.UI
import qs.Services.Keyboard
import qs.Widgets

Item {
  id: root
  property var pluginApi: null
  property var currentScreen: screen

  property var items: []
  property var imageCache: ({})
  property bool loading: false
  property var masked: true  // true=full dots, "partial"=first 3 chars, false=revealed
  property bool searchMode: false
  property string searchQuery: ""

  readonly property var geometryPlaceholder: mainContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: Math.min(screen?.width ?? 800, 700)
  property var contentPreferredHeight: Math.min(screen?.height ?? 600, 520)

  Process {
    id: listProc
    stdout: StdioCollector {}
    onExited: exitCode => {
      root.loading = false
      if (exitCode !== 0) { root.items = []; return }
      const out = String(stdout.text)
      const lines = out.split('\n').filter(l => l.length > 0)
      const parsed = lines.map(function(l) {
        let id = "", preview = ""
        const tab = l.indexOf('\t')
        if (tab > -1) { id = l.slice(0, tab).trim(); preview = l.slice(tab + 1) }
        else { id = l; preview = l }
        const lower = preview.toLowerCase()
        const isImage = lower.indexOf("[image]") === 0 || lower.indexOf("binary data") !== -1
        return { id: id, preview: preview, isImage: isImage }
      })
      root.items = parsed
    }
  }

  function refreshItems() {
    root.loading = true
    listProc.command = ["/usr/sbin/cliphist", "list"]
    listProc.running = true
  }

  Process {
    id: imageDecodeProc
    property string decodeId: ""
    stdout: StdioCollector {}
    onExited: exitCode => {
      if (exitCode === 0 && imageDecodeProc.decodeId) {
        const b64 = String(stdout.text).trim()
        const c = Object.assign({}, root.imageCache)
        c[imageDecodeProc.decodeId] = "data:image/png;base64," + b64
        root.imageCache = c
      }
      imageDecodeProc.decodeId = ""
    }
  }

  function getImage(id) {
    if (root.imageCache[id]) return root.imageCache[id]
    if (!id || !/^\d+$/.test(String(id))) return null
    imageDecodeProc.decodeId = String(id)
    imageDecodeProc.command = ["sh", "-c", "/usr/sbin/cliphist decode " + id + " | /usr/bin/base64 -w 0"]
    imageDecodeProc.running = true
    return null
  }

  function copyEntry(id) {
    Quickshell.execDetached(["sh", "-c", "/usr/sbin/cliphist decode " + id + " | /usr/bin/wl-copy"])
  }

  function deleteEntry(id) {
    if (id && /^\d+$/.test(String(id))) {
      Quickshell.execDetached(["/usr/sbin/cliphist", "delete", String(id)])
      root.refreshItems()
    }
  }

  Timer {
    id: refreshTimer
    interval: 3000; repeat: true
    onTriggered: root.refreshItems()
  }

  onVisibleChanged: {
    if (visible) {
      root.masked = true
      root.refreshItems()
      refreshTimer.start()
      itemList.forceActiveFocus()
    } else {
      refreshTimer.stop()
    }
  }

  // ── Navigation helpers (skip hidden items during search) ─────
  function navDown() {
    var start = itemList.currentIndex + 1
    for (var i = start; i < root.items.length; i++) {
      if (root.matchesQuery(root.items[i])) {
        itemList.currentIndex = i
        itemList.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  function navUp() {
    var start = itemList.currentIndex - 1
    for (var i = start; i >= 0; i--) {
      if (root.matchesQuery(root.items[i])) {
        itemList.currentIndex = i
        itemList.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  Keys.onPressed: event => {
    // ── Global keys (work in ALL modes) ────────────────────────
    // Ctrl+J: navigate down
    if (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier)) {
      root.navDown()
      event.accepted = true; return
    }
    // Ctrl+K: navigate up
    if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
      root.navUp()
      event.accepted = true; return
    }
    // Ctrl+A: cycle mask state: true → "partial" → false → true
    if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
      if (root.masked === true) {
        root.masked = "partial"
      } else if (root.masked === "partial") {
        root.masked = false
      } else {
        root.masked = true
      }
      event.accepted = true; return
    }
    // Arrow keys: navigate (global)
    if (event.key === Qt.Key_Down) {
      root.navDown()
      event.accepted = true; return
    }
    if (event.key === Qt.Key_Up) {
      root.navUp()
      event.accepted = true; return
    }
    // Enter: copy + close (global)
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      var eIdx = itemList.currentIndex
      if (eIdx >= 0 && eIdx < items.length && items[eIdx].id) root.copyEntry(items[eIdx].id)
      pluginApi?.closePanel(screen)
      event.accepted = true; return
    }

    // ── Search mode keys ───────────────────────────────────────
    if (root.searchMode) {
      // Escape / Ctrl+E: exit search
      if (event.key === Qt.Key_Escape || (event.key === Qt.Key_E && (event.modifiers & Qt.ControlModifier))) {
        root.searchMode = false
        root.searchQuery = ""
        event.accepted = true; return
      }
      // Backspace / Delete: delete last char, stay in search mode
      if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
        root.searchQuery = root.searchQuery.slice(0, -1)
        // Keep search mode active even when query is empty
        root.searchMode = true
        event.accepted = true; return
      }
      // Any printable character: append to query
      if (event.text && event.text.length > 0) {
        root.searchQuery += event.text
        event.accepted = true; return
      }
      return
    }

    // ── Normal mode keys ───────────────────────────────────────
    // Slash: enter search
    if (event.key === Qt.Key_Slash) {
      root.searchMode = true
      root.searchQuery = ""
      event.accepted = true; return
    }
    // j: navigate down
    if (event.key === Qt.Key_J) {
      root.navDown()
      event.accepted = true; return
    }
    // k: navigate up
    if (event.key === Qt.Key_K) {
      root.navUp()
      event.accepted = true; return
    }
    // Escape: close panel
    if (event.key === Qt.Key_Escape) {
      pluginApi?.closePanel(screen)
      event.accepted = true; return
    }
    // d: delete entry
    if (event.key === Qt.Key_D) {
      var dIdx = itemList.currentIndex
      if (dIdx >= 0 && dIdx < items.length) {
        root.deleteEntry(items[dIdx].id)
        if (dIdx < itemList.count - 1) itemList.currentIndex = dIdx
        else if (itemList.count > 1) itemList.currentIndex = dIdx - 1
      }
      event.accepted = true; return
    }
  }

  // ── Search helpers ────────────────────────────────────────────
  function matchesQuery(item) {
    if (!root.searchQuery) return true
    return item.preview.toLowerCase().indexOf(root.searchQuery.toLowerCase()) !== -1
  }

  function visibleCount() {
    if (!root.searchQuery) return root.items.length
    var q = root.searchQuery.toLowerCase()
    var c = 0
    for (var i = 0; i < root.items.length; i++) {
      if (root.items[i].preview.toLowerCase().indexOf(q) !== -1) c++
    }
    return c
  }

  // ── Helpers ───────────────────────────────────────────────────
  function maskText(text) {
    if (!text) return ""
    if (root.masked === "partial") {
      // Show first 3 chars, mask the rest
      var showLen = Math.min(3, text.length)
      var maskedLen = Math.min(text.length - showLen, 27)
      var r = text.slice(0, showLen)
      for (var i = 0; i < maskedLen; i++) r += "•"
      if (text.length > 30) r += "…"
      return r
    }
    // Fully masked
    var len = Math.min(text.length, 30)
    var r = ""
    for (var i = 0; i < len; i++) r += "•"
    if (text.length > 30) r += "…"
    return r
  }

  function formatPreview(text) {
    if (!text) return ""
    return text.length > 200 ? text.slice(0, 200) + "…" : text
  }

  Item {
    id: mainContainer
    anchors.fill: parent

    Rectangle {
      anchors.centerIn: parent
      width: Math.min(screen?.width ?? 800, 700)
      height: Math.min(screen?.height ?? 600, 520)
      radius: Style.radiusL
      color: Color.mSurface

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true; spacing: Style.marginS
          NText {
            text: pluginApi?.tr("panel.title")
            font.weight: Font.Bold
            font.pointSize: Style.fontSizeL
            color: Color.mOnSurface; Layout.alignment: Qt.AlignVCenter
          }
          NText {
            text: pluginApi?.tr("panel.count-filtered", { visible: visibleCount(), total: items.length })
            font.pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant; Layout.alignment: Qt.AlignVCenter
          }
          Item { Layout.fillWidth: true }
          Rectangle {
            color: root.masked === false ? Color.mPrimary : (root.masked === "partial" ? Color.mTertiary : Color.mSurfaceVariant)
            radius: Style.radiusS || 4; height: Style.baseWidgetSize * 0.65; Layout.alignment: Qt.AlignVCenter; opacity: 0.9
            RowLayout {
              anchors.left: parent.left; anchors.leftMargin: Style.marginS
              anchors.right: parent.right; anchors.rightMargin: Style.marginS
              anchors.verticalCenter: parent.verticalCenter; spacing: Style.marginXS
              NIcon {
                icon: root.masked === false ? "eye" : "eye-off"
                pointSize: Style.fontSizeXS
                color: root.masked === false ? Color.mOnPrimary : Color.mOnSurface
              }
              NText {
                text: root.masked === false ? pluginApi?.tr("panel.revealed") : (root.masked === "partial" ? pluginApi?.tr("panel.partial") : pluginApi?.tr("panel.masked"))
                font.pointSize: Style.fontSizeXS
                color: root.masked === false ? Color.mOnPrimary : Color.mOnSurface
              }
            }
          }
          NIconButton {
            icon: "x"; tooltipText: pluginApi?.tr("panel.close")
            colorBg: "transparent"; colorFg: Color.mOnSurface; colorBgHover: Color.mHover
            onClicked: pluginApi?.closePanel(screen)
          }
        }

        // Search bar
        Rectangle {
          Layout.fillWidth: true
          height: root.searchMode ? 32 : 0
          radius: Style.radiusM
          color: Color.mSurface
          NText {
            anchors.left: parent.left; anchors.leftMargin: Style.marginM
            anchors.verticalCenter: parent.verticalCenter
            visible: root.searchMode
            text: root.searchQuery.length > 0 ? "/" + root.searchQuery : pluginApi?.tr("panel.search-hint")
            color: root.searchQuery.length > 0 ? Color.mOnSurface : Color.mOnSurfaceVariant
            font.pointSize: Style.fontSizeS
            opacity: root.searchQuery.length > 0 ? 1 : 0.5
          }
        }

        NText {
          text: root.searchMode
            ? pluginApi?.tr("panel.hint-search")
            : pluginApi?.tr("panel.hint-normal")
          font.pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant; opacity: 0.7
        }

        Rectangle {
          Layout.fillWidth: true; Layout.fillHeight: true
          radius: Style.radiusM
          color: Color.mSurfaceVariant; clip: true

          ListView {
            id: itemList
            anchors.fill: parent; anchors.margins: Style.marginXS
            model: root.items; focus: true; spacing: 0
            keyNavigationWraps: false; highlight: null

            Keys.onDeletePressed: {
              var idx = itemList.currentIndex
              if (idx >= 0 && idx < items.length) {
                root.deleteEntry(items[idx].id)
                if (idx < itemList.count - 1) itemList.currentIndex = idx
                else if (itemList.count > 1) itemList.currentIndex = idx - 1
              }
            }

            delegate: Item {
              width: itemList.width; height: root.matchesQuery(modelData) ? 50 : 0
              visible: root.matchesQuery(modelData)
              property bool isSelected: ListView.isCurrentItem
              property bool isImg: modelData.isImage

              onIsImgChanged: { if (isImg) root.getImage(modelData.id) }
              Component.onCompleted: { if (isImg) root.getImage(modelData.id) }

              Rectangle {
                anchors.fill: parent; radius: Style.radiusM
                color: isSelected ? Color.mPrimary : (mouseArea.containsMouse ? Color.mHover : Color.mSurface)
                opacity: isSelected ? 0.15 : (mouseArea.containsMouse ? 0.08 : 0.35)
              }

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginM; anchors.rightMargin: Style.marginS; spacing: Style.marginM

                Item {
                  Layout.preferredWidth: isImg ? 40 : 24
                  Layout.preferredHeight: 40
                  Layout.alignment: Qt.AlignVCenter

                  NImageRounded {
                    visible: isImg && root.imageCache[modelData.id]
                    anchors.fill: parent; radius: Style.radiusM
                    imagePath: root.imageCache[modelData.id] || ""
                    imageFillMode: Image.PreserveAspectCrop
                  }
                  NIcon {
                    anchors.centerIn: parent
                    visible: !isImg || !root.imageCache[modelData.id]
                    icon: isImg ? "photo" : "align-left"
                    pointSize: Style.fontSizeM; color: Color.mOnSurface
                  }


                }

                ColumnLayout {
                  Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: Style.marginXS
                  NText {
                    Layout.fillWidth: true
                    text: {
                      if (isImg) return pluginApi?.tr("item.image")
                      if (root.masked) return root.maskText(modelData.preview)
                      return root.formatPreview(modelData.preview) || ""
                    }
                    elide: Text.ElideRight; maximumLineCount: 2
                    color: isImg ? Color.mOnSurfaceVariant : Color.mOnSurface
                    font.weight: isSelected ? Font.Bold : Font.Normal
                    font.pointSize: Style.fontSizeS
                  }
                  NText {
                    visible: !root.masked && !isImg && modelData.preview && modelData.preview.length > 80
                    Layout.fillWidth: true
                    text: root.formatPreview(modelData.preview.slice(80))
                    elide: Text.ElideRight; maximumLineCount: 1
                    color: Color.mOnSurfaceVariant; font.pointSize: Style.fontSizeXS; opacity: Style.opacityHeavy
                  }
                }

                Rectangle {
                  visible: isImg
                  color: Color.mTertiary; radius: Style.radiusS || 4; height: Style.baseWidgetSize * 0.5
                  Layout.alignment: Qt.AlignVCenter
                  RowLayout {
                    anchors.left: parent.left; anchors.leftMargin: Style.marginS
                    anchors.right: parent.right; anchors.rightMargin: Style.marginS
                    anchors.verticalCenter: parent.verticalCenter; spacing: Style.marginXS
                    NIcon { icon: "photo"; pointSize: Style.fontSizeXS; color: Color.mOnTertiary }
                    NText { text: pluginApi?.tr("item.img-badge"); font.pointSize: Style.fontSizeXS; font.bold: true; color: Color.mOnTertiary }
                  }
                }
              }

              Rectangle {
                anchors.left: parent.left; anchors.leftMargin: Style.marginM
                anchors.right: parent.right; anchors.rightMargin: Style.marginM
                anchors.bottom: parent.bottom; height: 1
                color: Color.mOnSurface; opacity: 0.08
              }

              MouseArea {
                id: mouseArea; anchors.fill: parent; hoverEnabled: true
                onClicked: { itemList.currentIndex = index; itemList.forceActiveFocus() }
                onDoubleClicked: {
                  if (modelData.id) root.copyEntry(modelData.id)
                  pluginApi?.closePanel(screen)
                }
              }
            }

            NText {
              anchors.centerIn: parent
              visible: root.loading && items.length === 0
              text: pluginApi?.tr("panel.loading"); color: Color.mOnSurfaceVariant
            }
            NText {
              anchors.centerIn: parent
              visible: !root.loading && items.length === 0
              text: pluginApi?.tr("panel.empty"); color: Color.mOnSurfaceVariant
            }
            NText {
              anchors.centerIn: parent
              visible: !root.loading && items.length > 0 && visibleCount() === 0
              text: pluginApi?.tr("panel.no-matches"); color: Color.mOnSurfaceVariant
            }
          }
        }

        NText {
          text: {
            if (root.loading) return pluginApi?.tr("panel.refreshing")
            if (visibleCount() > 0) {
              var c = visibleCount()
              var key = c === 1 ? "panel.count-singular" : "panel.count-plural"
              return pluginApi?.tr(key, { count: c })
            }
            if (visibleCount() === 0 && items.length > 0) return pluginApi?.tr("panel.count-no-matches")
            return ""
          }
          font.pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant; opacity: 0.6
        }
      }
    }

  }
}
