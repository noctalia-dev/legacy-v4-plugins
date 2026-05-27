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

  // Bug 4 fix: re-evaluate rawCategories whenever Main.qml increments cheatsheetDataVersion
  property int _dataVersion: pluginApi?.mainInstance?.cheatsheetDataVersion ?? 0
  property var rawCategories: {
    var _v = _dataVersion; // force QML dependency on version counter
    return pluginApi?.pluginSettings?.cheatsheetData || [];
  }
  property var categories: []

  // Bug 5 fix: timeout if parsing never completes
  property bool loadingTimedOut: false

  Timer {
    id: loadingTimeoutTimer
    interval: 4000
    repeat: false
    running: false
    onTriggered: {
      if (root.isLoading) {
        root.loadingTimedOut = true;
      }
    }
  }

  Component.onCompleted: {
    categories = processCategories(rawCategories);
    // Start timeout timer if we have no data yet
    if (root.isLoading) {
      loadingTimeoutTimer.start();
    }
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
    loadingTimeoutTimer.stop();

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
    root.searchText = "";
    if (searchInput) searchInput.inputItem.forceActiveFocus();
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

  property string searchText: ""

  property real contentPreferredWidth: settingsWidth
  property real contentPreferredHeight: calculateDynamicHeight()
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: false
  readonly property bool panelAnchorHorizontalCenter: true
  readonly property bool panelAnchorVerticalCenter: true
  anchors.fill: parent

  // Key badge colors — read from settings with manifest defaults as fallback
  readonly property color keyColorAlt:     cfg.keyColorAlt     || defaults.keyColorAlt     || "#FF6B6B"
  readonly property color keyColorXF86:    cfg.keyColorXF86    || defaults.keyColorXF86    || "#4ECDC4"
  readonly property color keyColorPrint:   cfg.keyColorPrint   || defaults.keyColorPrint   || "#95E1D3"
  readonly property color keyColorNumeric: cfg.keyColorNumeric || defaults.keyColorNumeric || "#A8DADC"
  readonly property color keyColorMouse:   cfg.keyColorMouse   || defaults.keyColorMouse   || "#F38181"
  // Empty string = use theme color (mPrimary/mSecondary/mTertiary)
  readonly property string keyColorSuperOverride: cfg.keyColorSuper ?? defaults.keyColorSuper ?? ""
  readonly property string keyColorCtrlOverride:  cfg.keyColorCtrl  ?? defaults.keyColorCtrl  ?? ""
  readonly property string keyColorShiftOverride: cfg.keyColorShift ?? defaults.keyColorShift ?? ""
  readonly property color keyColorDefault: cfg.keyColorDefault || defaults.keyColorDefault || "#6C757D"
  readonly property color keyLabelColor:   cfg.keyLabelColor   || defaults.keyLabelColor   || "#FFFFFF"
  // Empty string = theme-aware fallback (Color.mOnSurface). Any non-empty
  // value is treated as an explicit user override.
  readonly property string descriptionColorOverride: cfg.descriptionTextColor || defaults.descriptionTextColor || ""
  readonly property color descriptionTextColor: descriptionColorOverride !== "" ? descriptionColorOverride : Color.mOnSurface

  // Per-category text color overrides (empty = fall back to keyLabelColor)
  readonly property string keyTextSuperOverride:   cfg.keyTextSuper   ?? defaults.keyTextSuper   ?? ""
  readonly property string keyTextCtrlOverride:    cfg.keyTextCtrl    ?? defaults.keyTextCtrl    ?? ""
  readonly property string keyTextShiftOverride:   cfg.keyTextShift   ?? defaults.keyTextShift   ?? ""
  readonly property string keyTextAltOverride:     cfg.keyTextAlt     ?? defaults.keyTextAlt     ?? ""
  readonly property string keyTextXF86Override:    cfg.keyTextXF86    ?? defaults.keyTextXF86    ?? ""
  readonly property string keyTextPrintOverride:   cfg.keyTextPrint   ?? defaults.keyTextPrint   ?? ""
  readonly property string keyTextNumericOverride: cfg.keyTextNumeric ?? defaults.keyTextNumeric ?? ""
  readonly property string keyTextMouseOverride:   cfg.keyTextMouse   ?? defaults.keyTextMouse   ?? ""
  readonly property string keyTextDefaultOverride: cfg.keyTextDefault ?? defaults.keyTextDefault ?? ""

  // Workspace category split tuning
  readonly property bool splitWorkspaces: cfg.splitLargeWorkspaceCategory ?? defaults.splitLargeWorkspaceCategory ?? true
  readonly property int workspaceSplitThreshold: cfg.workspaceSplitThreshold ?? defaults.workspaceSplitThreshold ?? 12

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
    color: "transparent"
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
          text: CompositorService.isHyprland ? pluginApi?.tr("panel.title-hyprland") :
                CompositorService.isNiri     ? pluginApi?.tr("panel.title-niri") :
                CompositorService.isMango    ? pluginApi?.tr("panel.title-mango") :
                                               pluginApi?.tr("panel.title")
          font.pointSize: Style.fontSizeM
          font.weight: Font.Bold
          color: Color.mPrimary
        }

        NTextInput {
          id: searchInput
          placeholderText: pluginApi?.tr("panel.search-placeholder")
          text: root.searchText

          onTextChanged: {
            root.searchText = text;
            root.updateColumnItems();
          }
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
              pluginApi.closePanel(screen);
              BarService.openPluginSettings(screen, pluginApi.manifest);
            }
          }
        }
      }
    }

    NText {
      id: loadingText
      anchors.centerIn: parent
      text: root.loadingTimedOut ? pluginApi?.tr("panel.loading-timeout") : pluginApi?.tr("panel.loading")
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
        font.pointSize: Style.fontSizeM
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
      id: bindRow
      spacing: Style.marginS
      height: 22
      Layout.bottomMargin: 1

      property bool editing: false

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
              color: getKeyTextColor(modelData)
            }
          }
        }
      }

      // Described bind: plain text (unchanged behaviour)
      NText {
        visible: !itemData.undescribed
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: itemData.desc
        font.pointSize: Style.fontSizeXS
        color: root.descriptionTextColor
        elide: Text.ElideRight
      }

      // Undescribed bind: placeholder + add-description / hide actions
      NText {
        visible: itemData.undescribed && !bindRow.editing
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: pluginApi?.tr("panel.no-description")
        font.pointSize: Style.fontSizeXS
        font.italic: true
        color: Color.mOnSurfaceVariant
        elide: Text.ElideRight

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { bindRow.editing = true; descInput.text = ""; descInput.inputItem.forceActiveFocus(); }
        }
      }

      NTextInput {
        id: descInput
        visible: itemData.undescribed && bindRow.editing
        Layout.fillWidth: true
        Layout.preferredHeight: Style.baseWidgetSize
        placeholderText: pluginApi?.tr("panel.add-description-placeholder")
      }

      NIconButton {
        visible: itemData.undescribed && bindRow.editing
        Layout.preferredHeight: 18
        icon: "check"
        tooltipText: pluginApi?.tr("panel.save-description")
        onClicked: {
          root.saveBindDescription(itemData.bindId, descInput.text);
          bindRow.editing = false;
        }
      }

      NIconButton {
        visible: itemData.undescribed && bindRow.editing
        Layout.preferredHeight: 18
        icon: "close"
        tooltipText: pluginApi?.tr("panel.cancel")
        onClicked: { bindRow.editing = false; }
      }

      NIconButton {
        visible: itemData.undescribed && !bindRow.editing
        Layout.preferredHeight: 18
        icon: "edit"
        tooltipText: pluginApi?.tr("panel.add-description")
        onClicked: { bindRow.editing = true; descInput.text = ""; descInput.inputItem.forceActiveFocus(); }
      }

      NIconButton {
        visible: itemData.undescribed && !bindRow.editing
        Layout.preferredHeight: 18
        icon: "eye-off"
        tooltipText: pluginApi?.tr("panel.hide-bind")
        onClicked: { root.hideBind(itemData.bindId); }
      }
    }
  }

  function getKeyColor(keyName) {
    if (keyName === "Super") return root.keyColorSuperOverride || Color.mPrimary;
    if (keyName === "Ctrl")  return root.keyColorCtrlOverride  || Color.mSecondary;
    if (keyName === "Shift") return root.keyColorShiftOverride || Color.mTertiary;
    if (keyName === "Alt") return root.keyColorAlt;
    if (keyName.startsWith("XF86")) return root.keyColorXF86;
    if (keyName === "PRINT" || keyName === "Print") return root.keyColorPrint;
    if (keyName.match(/^[0-9]$/)) return root.keyColorNumeric;
    if (keyName.includes("MOUSE") || keyName.includes("Wheel")) return root.keyColorMouse;
    return root.keyColorDefault;
  }

  function getKeyTextColor(keyName) {
    if (keyName === "Super") return root.keyTextSuperOverride || root.keyLabelColor;
    if (keyName === "Ctrl")  return root.keyTextCtrlOverride  || root.keyLabelColor;
    if (keyName === "Shift") return root.keyTextShiftOverride || root.keyLabelColor;
    if (keyName === "Alt") return root.keyTextAltOverride || root.keyLabelColor;
    if (keyName.startsWith("XF86")) return root.keyTextXF86Override || root.keyLabelColor;
    if (keyName === "PRINT" || keyName === "Print") return root.keyTextPrintOverride || root.keyLabelColor;
    if (keyName.match(/^[0-9]$/)) return root.keyTextNumericOverride || root.keyLabelColor;
    if (keyName.includes("MOUSE") || keyName.includes("Wheel")) return root.keyTextMouseOverride || root.keyLabelColor;
    return root.keyTextDefaultOverride || root.keyLabelColor;
  }

  // ===== Bind override helpers (shared keyed map in plugin settings) =====
  function _cloneOverrides() {
    if (!pluginApi || !pluginApi.pluginSettings) return ({});
    var src = pluginApi.pluginSettings.bindOverrides || ({});
    try { return JSON.parse(JSON.stringify(src)); } catch (e) { return ({}); }
  }

  function saveBindDescription(bindId, desc) {
    if (!pluginApi || !bindId) return;
    var o = _cloneOverrides();
    if (!o[bindId]) o[bindId] = ({});
    var trimmed = (desc || "").trim();
    if (trimmed.length === 0) {
      delete o[bindId].desc;
      if (Object.keys(o[bindId]).length === 0) delete o[bindId];
    } else {
      o[bindId].desc = trimmed;
    }
    pluginApi.pluginSettings.bindOverrides = o;
    pluginApi.saveSettings();
    pluginApi.mainInstance?.refresh();
  }

  function hideBind(bindId) {
    if (!pluginApi || !bindId) return;
    var o = _cloneOverrides();
    if (!o[bindId]) o[bindId] = ({});
    o[bindId].hidden = true;
    pluginApi.pluginSettings.bindOverrides = o;
    pluginApi.saveSettings();
    pluginApi.mainInstance?.refresh();
  }

  function buildColumnItems(categoryIndices) {
    var result = [];
    if (!categoryIndices) return result;

    for (var i = 0; i < categoryIndices.length; i++) {
      var catIndex = categoryIndices[i];
      if (catIndex >= categories.length) continue;

      var cat = categories[catIndex];
      result.push({ type: "header", title: cat.title });
      var term = root.searchText.toLowerCase();
      for (var j = 0; j < cat.binds.length; j++) {
        var bnd = cat.binds[j];
        var isUndesc = bnd.undescribed === true;
        if (!term || (bnd.desc && bnd.desc.toLowerCase().indexOf(term) !== -1) || (isUndesc && bnd.keys.toLowerCase().indexOf(term) !== -1)) {
          result.push({
            type: "bind",
            keys: bnd.keys,
            desc: bnd.desc,
            bindId: bnd.bindId || "",
            undescribed: isUndesc
          });
        }
      }
      if (i < categoryIndices.length - 1) {
        result.push({ type: "spacer" });
      }
    }
    return result;
  }

  function processCategories(cats) {
    if (!cats || cats.length === 0) return [];
    if (!root.splitWorkspaces) return cats;

    var result = [];
    for (var i = 0; i < cats.length; i++) {
      var cat = cats[i];
      if (!cat.binds || cat.binds.length <= root.workspaceSplitThreshold) {
        result.push(cat);
        continue;
      }

      // Detect a category dominated by workspace verbs.
      // Hyprland verbs: workspace, movetoworkspace, movetoworkspacesilent, movecurrentworkspacetomonitor
      // Niri verbs:     focus-workspace, move-window-to-workspace, move-column-to-workspace
      var workspaceCount = 0;
      for (var k = 0; k < cat.binds.length; k++) {
        var v = cat.binds[k]._verb || "";
        if (v.indexOf("workspace") !== -1) workspaceCount++;
      }
      var workspaceDominated = workspaceCount >= Math.ceil(cat.binds.length * 0.6);
      if (!workspaceDominated) {
        result.push(cat);
        continue;
      }

      var switching = [], moving = [], mouse = [];
      for (var j = 0; j < cat.binds.length; j++) {
        var bind = cat.binds[j];
        var verb = bind._verb || "";
        var isMouse = (bind._mainKey || "").indexOf("MOUSE") !== -1 ||
                      (bind.keys || "").indexOf("MOUSE") !== -1 ||
                      (bind.keys || "").indexOf("Wheel") !== -1;

        if (isMouse) {
          mouse.push(bind);
        } else if (verb.indexOf("move") !== -1 || verb.indexOf("send") !== -1) {
          // Hyprland: movetoworkspace*, Niri: move-window-to-workspace, move-column-to-workspace
          moving.push(bind);
        } else {
          // Hyprland: workspace, Niri: focus-workspace
          switching.push(bind);
        }
      }

      if (switching.length > 0) result.push({ title: pluginApi?.tr("panel.workspace-switching"), binds: switching });
      if (moving.length > 0)    result.push({ title: pluginApi?.tr("panel.workspace-moving"), binds: moving });
      if (mouse.length > 0)     result.push({ title: pluginApi?.tr("panel.workspace-mouse"), binds: mouse });
    }
    return result;
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
