import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  // Settings
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Settings values
  property int settingsWidth: cfg.windowWidth ?? defaults.windowWidth ?? 1400
  property int settingsHeight: cfg.windowHeight ?? defaults.windowHeight ?? 0
  property bool autoHeight: cfg.autoHeight ?? defaults.autoHeight ?? true
  property int columnCount: cfg.columnCount ?? defaults.columnCount ?? 3

  property var rawCategories: pluginApi?.pluginSettings?.cheatsheetData || []
  property var categories: []
  

  
  Component.onCompleted: {
    categories = processCategories(rawCategories);
  }


  // Dynamic column items (up to 4 columns)
  property var columnItems: []

  // Memory leak prevention: debounce column updates
  Timer {
    id: columnUpdateDebounce
    interval: 100
    repeat: false
    onTriggered: updateColumnItemsNow()
  }

  Component.onDestruction: {
    // Stop timer to prevent firing after destruction
    columnUpdateDebounce.stop();

    // Clear column items
    columnItems = [];
  }

  onRawCategoriesChanged: {
    categories = processCategories(rawCategories);
    updateColumnItems();
  }

  onCategoriesChanged: {
    updateColumnItems();
    contentPreferredHeight = calculateDynamicHeight();
  }

  onColumnCountChanged: {
    updateColumnItems();
    contentPreferredHeight = calculateDynamicHeight();
  }

  onPanelOpenScreenChanged: {
    // Recalculate height when screen becomes available (important for bar widget opening)
    contentPreferredHeight = calculateDynamicHeight();
  }

  onMaxScreenHeightChanged: {
    contentPreferredHeight = calculateDynamicHeight();
  }

  function updateColumnItems() {
    columnUpdateDebounce.restart();
  }

  function updateColumnItemsNow() {
    columnItems = []; // Clear old items explicitly
    var assignments = distributeCategories();
    var items = [];
    for (var i = 0; i < columnCount; i++) {
      items.push(buildColumnItems(assignments[i] || []));
    }
    columnItems = items;
  }

  // Screen height limit (90% of screen)
  property var panelOpenScreen: pluginApi?.panelOpenScreen
  property real maxScreenHeight: panelOpenScreen ? panelOpenScreen.height * 0.9 : 800

  property real contentPreferredWidth: settingsWidth
  property real contentPreferredHeight: calculateDynamicHeight()
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: false
  readonly property bool panelAnchorHorizontalCenter: true
  readonly property bool panelAnchorVerticalCenter: true
  anchors.fill: parent

  // Data is loaded by Main.qml, we just display it
  property bool isLoading: rawCategories.length === 0

  function calculateDynamicHeight() {
    // If auto height is disabled, use manual height (but still respect screen limit)
    if (!autoHeight && settingsHeight > 0) {
      return Math.min(settingsHeight, maxScreenHeight);
    }

    if (categories.length === 0) return Math.min(400, maxScreenHeight);

    var assignments = distributeCategories();
    var maxColumnHeight = 0;

    for (var col = 0; col < columnCount; col++) {
      var colHeight = 0;
      var catIndices = assignments[col] || [];

      for (var i = 0; i < catIndices.length; i++) {
        var catIndex = catIndices[i];
        if (catIndex >= categories.length) continue;

        var cat = categories[catIndex];
        colHeight += 26; // Header
        colHeight += cat.binds.length * 20; // Binds
        if (i < catIndices.length - 1) {
          colHeight += 6; // Spacer
        }
      }

      if (colHeight > maxColumnHeight) {
        maxColumnHeight = colHeight;
      }
    }

    // header (45) + content + margins (16)
    var totalHeight = 45 + maxColumnHeight + 16 + 15 + 15;
    // Limit to 80% of screen height
    return Math.max(300, Math.min(totalHeight, maxScreenHeight));
  }

  // ========== UI ==========
  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.mSurface
    radius: Style.radiusL
    clip: true

    Rectangle {
      id: header
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 45
      color: Color.mSurfaceVariant
      radius: Style.radiusL

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginM
        spacing: Style.marginS

        // Title section (centered)
        Item { Layout.fillWidth: true }

        NIcon {
          icon: "keyboard"
          pointSize: Style.fontSizeM
          color: Color.mPrimary
        }
        NText {
          text: {
            if (CompositorService.isHyprland) {
              return "Hyprland Keymap";
            } else if (CompositorService.isNiri) {
              return "Niri Keymap";
            } else {
              return "Keymap";
            }
          }
          font.pointSize: Style.fontSizeM
          font.weight: Font.Bold
          color: Color.mPrimary
        }

        Item { Layout.fillWidth: true }

        // Refresh button
        NIconButton {
          icon: "refresh"
          onClicked: {
            pluginApi?.mainInstance?.refresh();
          }
        }

        // Settings button
        NIconButton {
          icon: "settings"
          onClicked: {
            var screen = pluginApi?.panelOpenScreen;
            if (screen && pluginApi?.manifest) {
              BarService.openPluginSettings(screen, pluginApi.manifest);
            }
          }
        }
      }
    }

    NText {
      id: loadingText
      anchors.centerIn: parent
      text: pluginApi?.tr("keybind-cheatsheet.panel.loading") || "Loading..."
      visible: root.isLoading
      font.pointSize: Style.fontSizeL
      color: Color.mOnSurface
    }

    NScrollView {
      id: scrollView
      visible: root.categories.length > 0 && !root.isLoading
      anchors.top: header.bottom
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      clip: true
      leftPadding: 35
      rightPadding: -10
      topPadding: 15
      bottomPadding: 15

      RowLayout {
        id: mainLayout
        width: scrollView.availableWidth - Style.marginS
        spacing: Style.marginS

        Repeater {
          model: root.columnItems.length

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            property var colItems: root.columnItems[index] || []

            Repeater {
              model: colItems
              Loader {
                Layout.fillWidth: true
                sourceComponent: modelData.type === "header" ? headerComponent :
                               (modelData.type === "spacer" ? spacerComponent : bindComponent)
                property var itemData: modelData

                // Memory leak prevention: explicit cleanup
                Component.onDestruction: {
                  active = false;
                  sourceComponent = undefined;
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: headerComponent
    ColumnLayout {
      Layout.preferredWidth: 300
      Layout.topMargin: Style.marginM
      Layout.bottomMargin: 4
      spacing: 0

      Item { Layout.fillWidth: true; height: 1 }

      NText {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        x: parent.width - implicitWidth
        text: itemData.title
        font.pointSize: 11
        font.weight: Font.Bold
        color: Color.mPrimary
      }

      Item { Layout.fillWidth: true; height: 1 }
    }
  }


  Component {
    id: spacerComponent
    Item {
      height: 10
      Layout.fillWidth: true
    }
  }

  Component {
    id: bindComponent
    RowLayout {
      spacing: Style.marginS
      height: 22
      Layout.bottomMargin: 1
      Flow {
        Layout.preferredWidth: 220
        Layout.alignment: Qt.AlignVCenter
        spacing: 3
        Repeater {
          model: itemData.keys.split(" + ")
          Rectangle {
            width: keyText.implicitWidth + 10
            height: 18
            color: getKeyColor(modelData)
            radius: 3
            NText {
              id: keyText
              anchors.centerIn: parent
              text: modelData
              font.pointSize: modelData.length > 12 ? 7 : 8
              font.weight: Font.Bold
              color: Color.mOnPrimary
            }
          }
        }
      }
      NText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: itemData.desc
        font.pointSize: 9
        color: Color.mOnSurface
        elide: Text.ElideRight
      }
    }
  }

  function getKeyColor(keyName) {
    if (keyName === "Super") return Color.mPrimary;
    if (keyName === "Ctrl") return Color.mSecondary;
    if (keyName === "Shift") return Color.mTertiary;
    if (keyName === "Alt") return "#FF6B6B";
    if (keyName.startsWith("XF86")) return "#4ECDC4";
    if (keyName === "PRINT" || keyName === "Print") return "#95E1D3";
    if (keyName.match(/^[0-9]$/)) return "#A8DADC";
    if (keyName.includes("MOUSE") || keyName.includes("Wheel")) return "#F38181";
    return Color.mPrimaryContainer || "#6C757D";
  }

  function buildColumnItems(categoryIndices) {
    var result = [];
    if (!categoryIndices) return result;

    for (var i = 0; i < categoryIndices.length; i++) {
      var catIndex = categoryIndices[i];
      if (catIndex >= categories.length) continue;

      var cat = categories[catIndex];
      result.push({ type: "header", title: cat.title });
      for (var j = 0; j < cat.binds.length; j++) {
        result.push({
          type: "bind",
          keys: cat.binds[j].keys,
          desc: cat.binds[j].desc
        });
      }
      if (i < categoryIndices.length - 1) {
        result.push({ type: "spacer" });
      }
    }
    return result;
  }

  function processCategories(cats) {
    if (!cats || cats.length === 0) return [];

    // For Hyprland: split large workspace categories
    if (CompositorService.isHyprland) {
      var result = [];
      for (var i = 0; i < cats.length; i++) {
        var cat = cats[i];

        if (cat.binds && cat.binds.length > 12 && cat.title.includes("OBSZARY ROBOCZE")) {
          var switching = [], moving = [], mouse = [];

          for (var j = 0; j < cat.binds.length; j++) {
            var bind = cat.binds[j];
            if (bind.keys.includes("MOUSE")) {
              mouse.push(bind);
            } else if (bind.desc.includes("Send") || bind.desc.includes("send") ||
                       bind.desc.includes("Move") || bind.desc.includes("move") ||
                       bind.desc.includes("Wyślij") || bind.desc.includes("wyślij")) {
              moving.push(bind);
            } else {
              switching.push(bind);
            }
          }

          if (switching.length > 0) result.push({ title: pluginApi?.tr("keybind-cheatsheet.panel.workspace-switching") || "WORKSPACES - SWITCHING", binds: switching });
          if (moving.length > 0) result.push({ title: pluginApi?.tr("keybind-cheatsheet.panel.workspace-moving") || "WORKSPACES - MOVING", binds: moving });
          if (mouse.length > 0) result.push({ title: pluginApi?.tr("keybind-cheatsheet.panel.workspace-mouse") || "WORKSPACES - MOUSE", binds: mouse });
        } else {
          result.push(cat);
        }
      }
      return result;
    }

    return cats;
  }

  function distributeCategories() {
    var numCols = root.columnCount;

    // Calculate weights for each category
    var catData = [];
    for (var i = 0; i < categories.length; i++) {
      var weight = 1 + categories[i].binds.length + 1; // header + binds + spacer
      catData.push({ index: i, weight: weight });
    }

    // Sort by weight descending (largest categories first for better distribution)
    catData.sort(function(a, b) { return b.weight - a.weight; });

    var columns = [];
    var columnWeights = [];
    for (var c = 0; c < numCols; c++) {
      columns.push([]);
      columnWeights.push(0);
    }

    // Assign each category to the column with smallest current weight
    for (var i = 0; i < catData.length; i++) {
      var minCol = 0;
      for (var c = 1; c < numCols; c++) {
        if (columnWeights[c] < columnWeights[minCol]) {
          minCol = c;
        }
      }
      columns[minCol].push(catData[i].index);
      columnWeights[minCol] += catData[i].weight;
    }

    // Sort categories within each column by original order for consistent display
    for (var c = 0; c < numCols; c++) {
      columns[c].sort(function(a, b) { return a - b; });
    }

    return columns;
  }

}
