import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI
import qs.Widgets

import "components/panel"
import "components/wallpaper"
import "helpers/panel/BadgeHelpers.js" as BadgeHelpers
import "helpers/panel/WallpaperFilterHelpers.js" as WallpaperFilterHelpers
import "helpers/panel/WallpaperMetaHelpers.js" as WallpaperMetaHelpers
import "helpers/panel/WallpaperUiHelpers.js" as WallpaperUiHelpers
import "helpers/shared/ColorCacheHelpers.js" as ColorCacheHelpers
import "helpers/panel/PropertyHelpers.js" as PropertyHelpers

Item {
  id: root

  // Core plugin and settings access.
  property var pluginApi: null

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 1480 * Style.uiScaleRatio
  property real contentPreferredHeight: 860 * Style.uiScaleRatio

  readonly property bool allowAttach: true

  // Panel state and current selection.
  readonly property string wallpapersFolder: cfg.wallpapersFolder ?? defaults.wallpapersFolder ?? ""
  readonly property string resolvedWallpapersFolder: Settings.preprocessPath(wallpapersFolder)
  property string selectedScreenName: pluginApi?.panelOpenScreen?.name ?? ""
  property string selectedPath: ""
  property string pendingPath: ""
  property string lastPersistedPath: ""
  property string selectedScaling: "fill"
  property string selectedClamp: "clamp"
  property int selectedVolume: 100
  property bool selectedMuted: true
  property bool selectedAudioReactiveEffects: true
  property bool selectedDisableMouse: false
  property bool selectedDisableParallax: false
  property bool applyWallpaperColorsOnApply: cfg.applyWallpaperColorsOnApply ?? defaults.applyWallpaperColorsOnApply ?? false
  readonly property bool applyingWallpaperColors: mainInstance?.applyingWallpaperColors ?? false
  readonly property bool scanningWallpapers: mainInstance?.scanningWallpapers ?? false
  property bool loadingWallpaperProperties: false
  property bool scanningCompatibility: false
  readonly property bool folderAccessible: mainInstance?.wallpapersFolderAccessible ?? true

  property string searchText: ""
  property string selectedType: "all"
  property string selectedResolution: "all"
  property string sortMode: "name"
  property bool sortAscending: true
  property int currentPage: 0
  readonly property int pageSize: Math.max(1, Number(cfg.panelPageSize ?? defaults.panelPageSize ?? 24) || 24)
  readonly property bool singleScreenMode: Quickshell.screens.length <= 1
  property bool applyAllDisplays: !singleScreenMode && root._applyAllDisplays
  property bool _applyAllDisplays: true
  property bool sidebarVisible: true
  readonly property var defaultBadgeOrder: BadgeHelpers.normalizedDefaultOrder(defaults.badgeOrder)
  readonly property var defaultBadgeEnabled: BadgeHelpers.normalizedDefaultEnabled(defaults.badgeEnabled)
  readonly property var badgeOrder: BadgeHelpers.normalizeBadgeOrder(cfg.badgeOrder, defaultBadgeOrder)
  readonly property var badgeEnabled: BadgeHelpers.normalizeBadgeEnabled(cfg.badgeEnabled, defaultBadgeEnabled)
  readonly property var visibleBadgeOrder: BadgeHelpers.filterVisibleBadgeOrder(badgeOrder, badgeEnabled, defaultBadgeEnabled)
  readonly property bool showSidebarDescription: cfg.showSidebarDescription ?? defaults.showSidebarDescription ?? false
  property bool applyTargetExpanded: false
  property bool filterDropdownOpen: false
  property bool sortDropdownOpen: false
  property bool errorDetailsExpanded: false
  property real filterDropdownX: 0
  property real filterDropdownY: 0
  property real filterDropdownWidth: 220 * Style.uiScaleRatio
  property real sortDropdownX: 0
  property real sortDropdownY: 0
  property real sortDropdownWidth: 220 * Style.uiScaleRatio
  property bool panelInitialized: false

  // Data models and derived UI state.
  property var screenModel: []
  readonly property var wallpaperItems: mainInstance?.cachedWallpaperItems || []
  property var visibleWallpapers: []
  property var pagedWallpapers: []
  property var wallpaperPropertyLoadFailedByPath: ({})
  property var wallpaperPropertyDefinitions: []
  property var wallpaperPropertyValues: ({})
  property string wallpaperPropertyError: ""
  property string wallpaperPropertyRequestPath: ""
  readonly property var propertyTranslationApi: ({
    translatePropertyLabelKey: key => pluginApi?.tr(key),
    createColor: (r, g, b, a) => Qt.rgba(r, g, b, a)
  })
  readonly property var propertyEditorApi: ({
    propertyValueFor: definition => root.propertyValueFor(definition),
    numberOr: (value, fallback) => PropertyHelpers.numberOr(value, fallback),
    formatSliderValue: (value, step) => PropertyHelpers.formatSliderValue(value, step),
    comboChoicesFor: definition => PropertyHelpers.comboChoicesFor(definition),
    ensureColorValue: value => PropertyHelpers.ensureColorValue(
      value,
      (rawValue, type) => PropertyHelpers.parsePropertyValue(rawValue, type, root.propertyTranslationApi.createColor),
      root.propertyTranslationApi.createColor
    ),
    resolvePropertyImageSource: rawValue => PropertyHelpers.resolvePropertyImageSource(rawValue, pendingPath),
    serializePropertyValue: (value, type) => PropertyHelpers.serializePropertyValue(value, type),
    setPropertyValue: (key, value) => root.setPropertyValue(key, value)
  })
  readonly property bool extraPropertiesEditorEnabled: cfg.enableExtraPropertiesEditor ?? defaults.enableExtraPropertiesEditor ?? true
  readonly property int pageCount: Math.max(1, Math.ceil(visibleWallpapers.length / Math.max(pageSize, 1)))
  readonly property bool paginationVisible: visibleWallpapers.length > pageSize
  readonly property int currentPageDisplay: visibleWallpapers.length === 0 ? 0 : currentPage + 1
  readonly property int currentPageStartIndex: visibleWallpapers.length === 0 ? 0 : currentPage * pageSize + 1
  readonly property int currentPageEndIndex: Math.min((currentPage + 1) * pageSize, visibleWallpapers.length)

  // Named timer intervals.
  readonly property int searchDebounceDelay: 250
  readonly property int propertyLoadDelay: 500

  // O(1) lookup map rebuilt when wallpaper items change.
  property var wallpaperByPath: ({})

  function rebuildWallpaperByPath() {
    const map = Object.create(null);
    for (const item of wallpaperItems) {
      map[String(item.path || "")] = item;
    }
    wallpaperByPath = map;
  }

  function getSelectedWallpaperData() {
    const target = String(pendingPath || "");
    if (target.length === 0) {
      return null;
    }
    return wallpaperByPath[target] || null;
  }

  // Basic file and metadata helpers.
  function isVideoMotion(path) {
    return WallpaperMetaHelpers.isVideoMotion(path);
  }

  function typeLabel(value) {
    return WallpaperUiHelpers.typeLabel(value, key => pluginApi?.tr(key));
  }

  function typeBadgeIcon(value) {
    return WallpaperUiHelpers.typeBadgeIcon(value);
  }

  function dynamicBadgeIcon(isDynamic) {
    return WallpaperUiHelpers.dynamicBadgeIcon(isDynamic);
  }

  function formatBytes(bytesValue) {
    return ColorCacheHelpers.formatBytes(bytesValue);
  }

  function sortLabel(value) {
    return WallpaperUiHelpers.sortLabel(value, key => pluginApi?.tr(key));
  }

  // Resolution helpers for badges and filtering.
  function resolutionBadgeIcon(value) {
    return WallpaperMetaHelpers.resolutionBadgeIcon(value);
  }

  function resolutionBadgeLabel(value) {
    return WallpaperMetaHelpers.resolutionBadgeLabel(value);
  }

  function resolutionFilterKey(value) {
    return WallpaperMetaHelpers.resolutionFilterKey(value);
  }

  function resolutionFilterLabel(value) {
    return WallpaperUiHelpers.resolutionFilterLabel(value, key => pluginApi?.tr(key));
  }

  // Extra property value accessors.
  function propertyValueFor(definition) {
    const key = String(definition?.key || "");
    if (key.length === 0) {
      return "";
    }
    const raw = wallpaperPropertyValues || ({});
    if (raw[key] !== undefined) {
      return raw[key];
    }
    return definition.defaultValue;
  }

  function setPropertyValue(key, value) {
    const current = wallpaperPropertyValues || ({});
    const next = Object.assign({}, current);
    next[String(key)] = value;
    wallpaperPropertyValues = next;
  }

  // Property loading and compatibility scan actions.
  function parseWallpaperPropertiesOutput(rawText) {
    return PropertyHelpers.parseWallpaperPropertiesOutput(rawText, root.propertyTranslationApi);
  }

  function loadWallpaperProperties(path) {
    const wallpaperPath = String(path || "").trim();
    wallpaperPropertyDefinitions = [];
    wallpaperPropertyValues = ({});
    wallpaperPropertyError = "";
    wallpaperPropertyRequestPath = wallpaperPath;

    if (!extraPropertiesEditorEnabled || wallpaperPath.length === 0) {
      loadingWallpaperProperties = false;
      return;
    }

    if (!(mainInstance?.engineAvailable ?? false)) {
      const savedProperties = mainInstance?.getWallpaperProperties(wallpaperPath) || ({});
      const savedKeys = Object.keys(savedProperties).filter(k => String(k || "").trim().length > 0);
      if (savedKeys.length > 0) {
        const fallbackDefinitions = savedKeys.map(key => ({
          key: key,
          type: "textinput",
          label: key,
          defaultValue: "",
          choices: []
        }));
        wallpaperPropertyDefinitions = fallbackDefinitions;
        const nextValues = {};
        for (const key of savedKeys) {
          nextValues[key] = String(savedProperties[key] ?? "");
        }
        wallpaperPropertyValues = nextValues;
        wallpaperPropertyError = "";
        setWallpaperPropertyLoadFailed(wallpaperPath, false);
      }
      loadingWallpaperProperties = false;
      return;
    }

    loadingWallpaperProperties = true;
    wallpaperPropertyProcess.command = ["linux-wallpaperengine", wallpaperPath, "--list-properties"];
    wallpaperPropertyProcess.running = true;
  }

  function setWallpaperPropertyLoadFailed(path, failed) {
    const currentState = propertyCompatibilityStateForPath(path);
    if (failed) {
      setWallpaperPropertyCompatibilityState(path, "failed");
      return;
    }
    if (currentState === "failed" || currentState.length === 0) {
      setWallpaperPropertyCompatibilityState(path, "");
    }
  }

  function setWallpaperPropertyCompatibilityState(path, state) {
    const wallpaperPath = String(path || "").trim();
    if (wallpaperPath.length === 0) {
      return;
    }

    const normalizedState = String(state || "").trim();
    const nextState = Object.assign({}, wallpaperPropertyLoadFailedByPath);
    if (normalizedState.length > 0) {
      nextState[wallpaperPath] = normalizedState;
    } else {
      delete nextState[wallpaperPath];
    }
    wallpaperPropertyLoadFailedByPath = nextState;
  }

  function propertyCompatibilityStateForPath(path) {
    const key = String(path || "").trim();
    const raw = wallpaperPropertyLoadFailedByPath || ({});
    const value = raw[key];
    if (value === true) {
      return "failed";
    }
    return String(value || "").trim();
  }

  function propertyCompatibilityBadgeIconForPath(path) {
    const state = propertyCompatibilityStateForPath(path);
    if (state === "limited") {
      return "alert-circle";
    }
    if (state === "failed") {
      return "alert-triangle";
    }
    return "";
  }

  function propertyCompatibilityBadgeTextForPath(path) {
    const state = propertyCompatibilityStateForPath(path);
    if (state === "limited") {
      return pluginApi?.tr("panel.propertiesLimitedBadge");
    }
    if (state === "failed") {
      return pluginApi?.tr("panel.propertiesFailedBadge");
    }
    return "";
  }

  function propertyCompatibilityBadgeColorForPath(path) {
    const state = propertyCompatibilityStateForPath(path);
    if (state === "limited") {
      return Color.mSecondary;
    }
    if (state === "failed") {
      return Color.mError;
    }
    return Color.mOnSurfaceVariant;
  }

  function propertyCompatibilityBadgeBackgroundForPath(path) {
    return Qt.alpha(propertyCompatibilityBadgeColorForPath(path), 0.16);
  }

  function startCompatibilityScan() {
    const folderPath = String(resolvedWallpapersFolder || "").trim();
    if (folderPath.length === 0 || !(mainInstance?.engineAvailable ?? false)) {
      return;
    }

    const pluginDir = pluginApi?.pluginDir || "";
    const scriptPath = pluginDir + "/scripts/scan-properties-compatibility.sh";

    scanningCompatibility = true;
    compatibilityScanProcess.command = ["bash", scriptPath, folderPath];
    compatibilityScanProcess.running = true;
  }

  function applyCompatibilityScanOutput(rawText) {
    const nextState = {};
    const lines = String(rawText || "").split(/\r?\n/);
    let totalCount = 0;

    for (const rawLine of lines) {
      const line = String(rawLine || "").trim();
      if (line.length === 0) {
        continue;
      }

      const parts = line.split("\t");
      const path = String(parts[0] || "").trim();
      const statusCode = String(parts[1] || "0").trim();
      if (path.length === 0) {
        continue;
      }

      totalCount += 1;

      if (statusCode === "1") {
        nextState[path] = "failed";
      } else if (statusCode === "2") {
        nextState[path] = "limited";
      }
    }

    wallpaperPropertyLoadFailedByPath = nextState;
    let limitedCount = 0;
    let failedCount = 0;
    for (const value of Object.values(nextState)) {
      if (value === "limited") {
        limitedCount += 1;
      } else if (value === "failed") {
        failedCount += 1;
      }
    }
    return {
      totalCount: totalCount,
      failedCount: failedCount,
      limitedCount: limitedCount
    };
  }

  // Dropdown state helpers.
  function closeDropdowns() {
    filterDropdownOpen = false;
    sortDropdownOpen = false;
  }

  function openFilterDropdown(x, y, width) {
    filterDropdownX = x;
    filterDropdownY = y;
    filterDropdownWidth = width;
    sortDropdownOpen = false;
    filterDropdownOpen = true;
  }

  function openSortDropdown(x, y, width) {
    sortDropdownX = x;
    sortDropdownY = y;
    sortDropdownWidth = width;
    filterDropdownOpen = false;
    sortDropdownOpen = true;
  }

  function applyFilterAction(action) {
    if (String(action).indexOf("type:") === 0) {
      selectedType = String(action).substring(5);
    } else if (String(action).indexOf("res:") === 0) {
      selectedResolution = String(action).substring(4);
    }
    closeDropdowns();
  }

  function applySortAction(action) {
    if (action === "sort:toggleAscending") {
      sortAscending = !sortAscending;
    } else if (String(action).indexOf("sort:") === 0) {
      sortMode = String(action).substring(5);
    }
    closeDropdowns();
  }

  // Panel memory and selection synchronization.
  function loadPanelMemory() {
    if (!pluginApi) {
      return;
    }

    const remembered = String(pluginApi?.pluginSettings?.panelLastSelectedPath || "").trim();
    root.lastPersistedPath = remembered;
    if (remembered.length > 0) {
      pendingPath = remembered;
    }
  }

  function persistPanelMemory(flushToDisk = false) {
    const next = String(pendingPath || "");
    if (root.lastPersistedPath === next) {
      return;
    }
    root.lastPersistedPath = next;
    if (pluginApi) {
      pluginApi.pluginSettings.panelLastSelectedPath = next;
      if (flushToDisk) {
        pluginApi.saveSettings();
      }
    }
  }

  function resetPendingToGlobalDefaults() {
    selectedScaling = String(defaults.defaultScaling || "fill");
    syncGlobalRuntimeOptions();
  }

  function syncGlobalRuntimeOptions() {
    selectedClamp = String(cfg.defaultClamp ?? defaults.defaultClamp ?? "clamp");
    selectedVolume = Math.max(0, Math.min(100, Number(cfg.defaultVolume ?? defaults.defaultVolume ?? 100)));
    selectedMuted = !!(cfg.defaultMuted ?? defaults.defaultMuted ?? true);
    selectedAudioReactiveEffects = !!(cfg.defaultAudioReactiveEffects ?? defaults.defaultAudioReactiveEffects ?? true);
    selectedDisableMouse = !!(cfg.defaultDisableMouse ?? defaults.defaultDisableMouse ?? false);
    selectedDisableParallax = !!(cfg.defaultDisableParallax ?? defaults.defaultDisableParallax ?? false);
  }

  function syncSelectionOptionsFromScreen() {
    const fallbackScreenName = root.singleScreenMode ? (Quickshell.screens[0]?.name || selectedScreenName) : selectedScreenName;
    if (root.singleScreenMode && selectedScreenName.length === 0 && fallbackScreenName.length > 0) {
      selectedScreenName = fallbackScreenName;
    }

    const screenCfg = mainInstance?.getScreenConfig(fallbackScreenName);
    if (!screenCfg) {
      selectedScaling = String(defaults.defaultScaling || "fill");
      return;
    }

    selectedScaling = String(screenCfg.scaling || defaults.defaultScaling || "fill");
  }

  function resetSelectionOptionsFromCurrentConfig() {
    syncGlobalRuntimeOptions();
    syncSelectionOptionsFromScreen();
  }

  // Wallpaper application and list state refresh.
  function applyPendingSelection() {
    const path = String(pendingPath || "").trim();
    if (path.length === 0) {
      return;
    }

    const configuredColorScreen = String(Settings.data.colorSchemes.monitorForColors || "").trim();
    const colorApplyScreen = applyAllDisplays
      ? (configuredColorScreen || Quickshell.screens[0]?.name || "")
      : (root.singleScreenMode ? (Quickshell.screens[0]?.name || "") : (selectedScreenName || Quickshell.screens[0]?.name || ""));
    const colorApplyOptions = {
      "screenName": colorApplyScreen,
      "scaling": selectedScaling,
      "notify": true
    };

    const options = { "scaling": selectedScaling, "clamp": selectedClamp };
    options.volume = selectedVolume;
    options.muted = selectedMuted;
    options.audioReactiveEffects = selectedAudioReactiveEffects;
    options.noAutomute = !!(cfg.defaultNoAutomute ?? defaults.defaultNoAutomute ?? false);
    options.disableMouse = selectedDisableMouse;
    options.disableParallax = selectedDisableParallax;
    const customProperties = {};
    for (const definition of wallpaperPropertyDefinitions) {
      const propertyKey = String(definition?.key || "");
      if (propertyKey.length === 0 || !PropertyHelpers.isWritablePropertyType(definition?.type)) {
        continue;
      }
      customProperties[propertyKey] = propertyEditorApi.serializePropertyValue(propertyEditorApi.propertyValueFor(definition), definition.type);
    }
    options.customProperties = customProperties;
    selectedPath = path;

    if (applyAllDisplays) {
      Logger.i("LWEController", "Confirm apply to all displays", path, JSON.stringify(options));
      mainInstance?.setAllScreensWallpaperWithOptions(path, options);
      if (applyWallpaperColorsOnApply) {
        mainInstance?.scheduleWallpaperColorsFromPath(path, colorApplyOptions);
      }
      pendingPath = "";
      return;
    }

    if (!root.singleScreenMode && selectedScreenName.length === 0) {
      Logger.w("LWEController", "Confirm apply skipped due to empty selected screen", path);
      return;
    }

    const targetScreen = root.singleScreenMode ? (Quickshell.screens[0]?.name || "") : selectedScreenName;
    Logger.i("LWEController", "Confirm apply to screen", targetScreen, path, JSON.stringify(options));
    mainInstance?.setScreenWallpaperWithOptions(targetScreen, path, options);
    if (applyWallpaperColorsOnApply) {
      mainInstance?.scheduleWallpaperColorsFromPath(path, colorApplyOptions);
    }
    pendingPath = "";
  }

  function refreshVisibleWallpapers() {
    const query = String(searchText || "").trim().toLowerCase();
    visibleWallpapers = WallpaperFilterHelpers.filteredAndSortedWallpapers(wallpaperItems, {
      query: query,
      selectedType: selectedType,
      selectedResolution: selectedResolution,
      sortMode: sortMode,
      sortAscending: sortAscending,
      resolutionFilterKey: resolutionFilterKey
    });
    Logger.d("LWEController", "Visible wallpapers refreshed", "count=", visibleWallpapers.length, "type=", selectedType, "resolution=", selectedResolution, "sort=", sortMode, "ascending=", sortAscending, "query=", query);
  }

  function refreshPagedWallpapers() {
    const pageState = WallpaperFilterHelpers.pagedWallpapers(visibleWallpapers, currentPage, pageSize);

    if (pageState.page !== currentPage) {
      currentPage = pageState.page;
      return;
    }

    pagedWallpapers = pageState.items;
  }

  function resetPagination() {
    if (currentPage !== 0) {
      currentPage = 0;
      return;
    }

    refreshPagedWallpapers();
  }

  function goToPreviousPage() {
    if (currentPage > 0) {
      currentPage -= 1;
    }
  }

  function goToNextPage() {
    if (currentPage < pageCount - 1) {
      currentPage += 1;
    }
  }

  function reconcilePendingSelection() {
    const current = String(pendingPath || "");
    if (current.length === 0) {
      return;
    }

    let exists = false;
    for (const item of wallpaperItems) {
      if (String(item.path || "") === current) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      pendingPath = "";
    }
  }

  function refreshWallpaperList(force = false) {
    mainInstance?.refreshWallpaperCache(force, true);
  }

  function rebuildScreenModel() {
    const model = [];
    for (const screen of Quickshell.screens) {
      model.push({ key: screen.name, name: screen.name });
    }

    screenModel = model;

    if (!root.singleScreenMode && selectedScreenName.length === 0 && model.length > 0) {
      selectedScreenName = model[0].key;
    }
  }

  function applyPath(path) {
    if (!path || path.length === 0) {
      Logger.w("LWEController", "Apply skipped due to invalid path", path);
      return;
    }
    pendingPath = path;
    sidebarVisible = true;
  }

  // Reactive state updates.
  onWallpaperItemsChanged: {
    rebuildWallpaperByPath();
    refreshVisibleWallpapers();
    reconcilePendingSelection();
  }
  onVisibleWallpapersChanged: refreshPagedWallpapers()
  onCurrentPageChanged: refreshPagedWallpapers()
  onPageSizeChanged: refreshPagedWallpapers()
  onSearchTextChanged: {
    searchDebounceTimer.restart();
  }
  onSelectedTypeChanged: {
    refreshVisibleWallpapers();
    resetPagination();
  }
  onSelectedResolutionChanged: {
    refreshVisibleWallpapers();
    resetPagination();
  }
  onSortModeChanged: {
    refreshVisibleWallpapers();
    resetPagination();
  }
  onSortAscendingChanged: {
    refreshVisibleWallpapers();
    resetPagination();
  }
  onPendingPathChanged: {
    persistPanelMemory();
    propertiesLoadTimer.restart();
  }
  onWallpapersFolderChanged: {
    if (!root.pluginApi || !root.panelInitialized) {
      return;
    }
    mainInstance?.refreshWallpaperCache(true, false);
  }

  Component.onCompleted: {
    Logger.i("LWEController", "Panel opened", "screen=", selectedScreenName);
    rebuildScreenModel();
    loadPanelMemory();
    resetSelectionOptionsFromCurrentConfig();
    mainInstance?.refreshWallpaperCache(false, false);
    panelInitialized = true;
    propertiesLoadTimer.restart();
  }

  Component.onDestruction: {
    persistPanelMemory(true);
    if (pluginApi) {
      pluginApi.pluginSettings.applyWallpaperColorsOnApply = root.applyWallpaperColorsOnApply;
      pluginApi.saveSettings();
    }
  }

  // Keep dropdowns aligned with panel width changes.
  onWidthChanged: {
    if (filterDropdownOpen) openFilterDropdown(filterDropdownX, filterDropdownY, filterDropdownWidth);
    if (sortDropdownOpen) openSortDropdown(sortDropdownX, sortDropdownY, sortDropdownWidth);
  }

  // Main instance state hooks.
  Connections {
    target: mainInstance

    function onLastErrorChanged() {
      root.errorDetailsExpanded = false;
    }
  }

  // Root layout and component composition.
  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      PanelHeader {
        pluginApi: root.pluginApi
        mainInstance: root.mainInstance
        positionTarget: root
        scanningCompatibility: root.scanningCompatibility
        searchText: root.searchText
        selectedType: root.selectedType
        selectedResolution: root.selectedResolution
        sortMode: root.sortMode
        sortAscending: root.sortAscending
        typeLabel: root.typeLabel
        resolutionFilterLabel: root.resolutionFilterLabel
        sortLabel: root.sortLabel
        filterButtonWidth: 180 * Style.uiScaleRatio
        sortButtonWidth: 172 * Style.uiScaleRatio
        onCompatibilityQuickCheckRequested: root.startCompatibilityScan()
        onReloadRequested: {
          root.refreshWallpaperList(true);
        }
        onToggleRunRequested: {
          if (mainInstance?.engineRunning) {
            mainInstance?.stopAll(true);
          } else {
            mainInstance?.reload(true);
          }
        }
        onSettingsRequested: {
          const screen = pluginApi?.panelOpenScreen;
          BarService.openPluginSettings(screen, pluginApi?.manifest);
          if (pluginApi) {
            pluginApi.togglePanel(screen);
          }
        }
        onSearchTextUpdateRequested: text => root.searchText = text
        onClearSearchRequested: root.searchText = ""
        onFilterDropdownToggleRequested: (x, y, width) => {
          if (filterDropdownOpen) {
            root.closeDropdowns();
          } else {
            root.openFilterDropdown(x, y, width);
          }
        }
        onSortDropdownToggleRequested: (x, y, width) => {
          if (sortDropdownOpen) {
            root.closeDropdowns();
          } else {
            root.openSortDropdown(x, y, width);
          }
        }
      }

      RuntimeErrorBanner {
        pluginApi: root.pluginApi
        mainInstance: root.mainInstance
        errorDetailsExpanded: root.errorDetailsExpanded
        onErrorDetailsExpandedRequested: value => root.errorDetailsExpanded = value
        onDismissRequested: {
          if (mainInstance) {
            mainInstance.lastError = "";
            mainInstance.lastErrorDetails = "";
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.radiusL
        color: Qt.alpha(Color.mSurfaceVariant, 0.35)
        border.width: Style.borderS
        border.color: Qt.alpha(Color.mOutline, 0.35)

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.marginM

            GridSection {
              pluginApi: root.pluginApi
              mainInstance: root.mainInstance
              wallpapers: root.pagedWallpapers
              pendingPath: root.pendingPath
              selectedPath: root.selectedPath
              scanningWallpapers: root.scanningWallpapers
              wallpaperItemsCount: root.wallpaperItems.length
              visibleWallpaperCount: root.visibleWallpapers.length
              propertyCompatibilityBadgeIconForPath: root.propertyCompatibilityBadgeIconForPath
              propertyCompatibilityBadgeTextForPath: root.propertyCompatibilityBadgeTextForPath
              propertyCompatibilityBadgeColorForPath: root.propertyCompatibilityBadgeColorForPath
              propertyCompatibilityBadgeBackgroundForPath: root.propertyCompatibilityBadgeBackgroundForPath
              currentPage: root.currentPage
              pageCount: root.pageCount
              currentPageDisplay: root.currentPageDisplay
              currentPageStartIndex: root.currentPageStartIndex
              currentPageEndIndex: root.currentPageEndIndex
              paginationVisible: root.paginationVisible
              resolutionBadgeIcon: root.resolutionBadgeIcon
              resolutionBadgeLabel: root.resolutionBadgeLabel
              typeLabel: root.typeLabel
              typeBadgeIcon: root.typeBadgeIcon
              dynamicBadgeIcon: root.dynamicBadgeIcon
              badgeOrder: root.visibleBadgeOrder
              isVideoMotion: root.isVideoMotion
              onWallpaperActivated: path => root.applyPath(path)
              onPreviousPageRequested: root.goToPreviousPage()
              onNextPageRequested: root.goToNextPage()
            }

            Sidebar {
              pluginApi: root.pluginApi
              mainInstance: root.mainInstance
              selectedWallpaperData: root.getSelectedWallpaperData()
              propertyCompatibilityBadgeIconForPath: root.propertyCompatibilityBadgeIconForPath
              propertyCompatibilityBadgeTextForPath: root.propertyCompatibilityBadgeTextForPath
              propertyCompatibilityBadgeColorForPath: root.propertyCompatibilityBadgeColorForPath
              propertyCompatibilityBadgeBackgroundForPath: root.propertyCompatibilityBadgeBackgroundForPath
              singleScreenMode: root.singleScreenMode
              applyAllDisplays: root.applyAllDisplays
              applyTargetExpanded: root.applyTargetExpanded
              screenModel: root.screenModel
              selectedScreenName: root.selectedScreenName
              selectedScaling: root.selectedScaling
              selectedClamp: root.selectedClamp
              selectedVolume: root.selectedVolume
              selectedMuted: root.selectedMuted
              selectedAudioReactiveEffects: root.selectedAudioReactiveEffects
              selectedDisableMouse: root.selectedDisableMouse
              selectedDisableParallax: root.selectedDisableParallax
              applyWallpaperColorsOnApply: root.applyWallpaperColorsOnApply
              applyingWallpaperColors: root.applyingWallpaperColors
              extraPropertiesEditorEnabled: root.extraPropertiesEditorEnabled
              loadingWallpaperProperties: root.loadingWallpaperProperties
              wallpaperPropertyError: root.wallpaperPropertyError
              wallpaperPropertyDefinitions: root.wallpaperPropertyDefinitions
              resolutionBadgeIcon: root.resolutionBadgeIcon
              resolutionBadgeLabel: root.resolutionBadgeLabel
              typeLabel: root.typeLabel
              typeBadgeIcon: root.typeBadgeIcon
              dynamicBadgeIcon: root.dynamicBadgeIcon
              badgeOrder: root.visibleBadgeOrder
              showDescription: root.showSidebarDescription
              isVideoMotion: root.isVideoMotion
              formatBytes: root.formatBytes
              propertyEditorApi: root.propertyEditorApi
              onApplyRequested: root.applyPendingSelection()
              onApplyAllDisplaysRequested: value => root._applyAllDisplays = value
              onApplyTargetExpandedRequested: value => root.applyTargetExpanded = value
              onSelectedScreenNameRequested: value => root.selectedScreenName = value
              onSelectedScalingRequested: value => root.selectedScaling = value
              onSelectedClampRequested: value => root.selectedClamp = value
              onSelectedVolumeRequested: value => root.selectedVolume = value
              onSelectedMutedRequested: value => root.selectedMuted = value
              onSelectedAudioReactiveEffectsRequested: value => root.selectedAudioReactiveEffects = value
              onSelectedDisableMouseRequested: value => root.selectedDisableMouse = value
              onSelectedDisableParallaxRequested: value => root.selectedDisableParallax = value
              onApplyWallpaperColorsOnApplyRequested: value => {
                root.applyWallpaperColorsOnApply = value;
              }
              sidebarVisible: root.sidebarVisible
              onSidebarVisibleRequested: value => root.sidebarVisible = value
            }
          }

          NText {
            visible: !(mainInstance?.engineAvailable ?? false)
            text: pluginApi?.tr("panel.installHint")
            color: Color.mOnSurfaceVariant
            wrapMode: Text.Wrap
          }

          NText {
            visible: !root.folderAccessible
            text: pluginApi?.tr("panel.folderInvalid")
            color: Color.mError
            wrapMode: Text.WrapAnywhere
          }

          NText {
            visible: root.scanningWallpapers
            text: pluginApi?.tr("panel.scanning")
            color: Color.mOnSurfaceVariant
          }
        }
      }
    }
  }

  PanelDropdowns {
    pluginApi: root.pluginApi
    filterDropdownOpen: root.filterDropdownOpen
    sortDropdownOpen: root.sortDropdownOpen
    selectedResolution: root.selectedResolution
    selectedType: root.selectedType
    sortMode: root.sortMode
    sortAscending: root.sortAscending
    filterDropdownX: root.filterDropdownX
    filterDropdownY: root.filterDropdownY
    filterDropdownWidth: root.filterDropdownWidth
    sortDropdownX: root.sortDropdownX
    sortDropdownY: root.sortDropdownY
    sortDropdownWidth: root.sortDropdownWidth
    onCloseRequested: root.closeDropdowns()
    onFilterActionTriggered: action => root.applyFilterAction(action)
    onSortActionTriggered: action => root.applySortAction(action)
  }

  // Processes.
  Process {
    id: wallpaperPropertyProcess

    stdout: StdioCollector {
      id: wallpaperPropertyStdout
    }

    stderr: StdioCollector {
      id: wallpaperPropertyStderr
    }

    onExited: function(exitCode) {
      const requestPath = root.wallpaperPropertyRequestPath;
      root.loadingWallpaperProperties = false;

      const outputText = [String(wallpaperPropertyStdout.text || ""), String(wallpaperPropertyStderr.text || "")]
        .filter(part => part.trim().length > 0)
        .join("\n");

      if (requestPath.length === 0 || requestPath !== String(root.pendingPath || "")) {
        Logger.d("LWEController", "Ignoring stale wallpaper property result", "requestPath=", requestPath, "pendingPath=", root.pendingPath, "exitCode=", exitCode);
        return;
      }

      if (exitCode !== 0) {
        const savedProperties = mainInstance?.getWallpaperProperties(requestPath) || ({});
        const savedKeys = Object.keys(savedProperties).filter(k => String(k || "").trim().length > 0);
        if (savedKeys.length > 0) {
          const fallbackDefinitions = savedKeys.map(key => ({
            key: key,
            type: "textinput",
            label: key,
            defaultValue: "",
            choices: []
          }));
          root.wallpaperPropertyDefinitions = fallbackDefinitions;
          const nextValues = {};
          for (const key of savedKeys) {
            nextValues[key] = String(savedProperties[key] ?? "");
          }
          root.wallpaperPropertyValues = nextValues;
          root.setWallpaperPropertyLoadFailed(requestPath, false);
          root.wallpaperPropertyError = "";
          Logger.w("LWEController", "Wallpaper properties load failed, restored saved properties as fallback", "path=", requestPath, "exitCode=", exitCode, "count=", savedKeys.length);
        } else {
          root.wallpaperPropertyDefinitions = [];
          root.wallpaperPropertyValues = ({});
          root.setWallpaperPropertyLoadFailed(requestPath, true);
          root.wallpaperPropertyError = pluginApi?.tr("panel.propertiesLoadFailed");
          Logger.w("LWEController", "Wallpaper properties load failed", "path=", requestPath, "exitCode=", exitCode);
        }
        return;
      }

      const definitions = root.parseWallpaperPropertiesOutput(outputText);
      root.setWallpaperPropertyLoadFailed(requestPath, false);
      root.wallpaperPropertyDefinitions = definitions;
      for (const definition of definitions) {
        if (definition.type === "combo") {
          Logger.d("LWEController", "Combo property parsed", "key=", definition.key, "choices=", JSON.stringify(root.propertyEditorApi.comboChoicesFor(definition)));
        }
      }

      const savedProperties = mainInstance?.getWallpaperProperties(requestPath) || ({});
      const nextValues = {};
      for (const definition of definitions) {
        const propertyKey = String(definition.key || "");
        if (savedProperties[propertyKey] !== undefined) {
          nextValues[propertyKey] = PropertyHelpers.parsePropertyValue(savedProperties[propertyKey], definition.type, root.propertyTranslationApi.createColor);
        } else {
          nextValues[propertyKey] = definition.defaultValue;
        }
      }
      root.wallpaperPropertyValues = nextValues;
      root.wallpaperPropertyError = "";
      Logger.i("LWEController", "Wallpaper properties loaded", "path=", requestPath, "count=", definitions.length);
    }
  }

  Process {
    id: compatibilityScanProcess

    stdout: StdioCollector {
      id: compatibilityScanStdout
    }

    stderr: StdioCollector {
      id: compatibilityScanStderr
    }

    onExited: function(exitCode) {
      root.scanningCompatibility = false;

      const stdoutText = String(compatibilityScanStdout.text || "");
      const stderrText = String(compatibilityScanStderr.text || "").trim();

      if (exitCode !== 0) {
        const msg = stderrText.length > 0
          ? "Compatibility scan failed" + ", stderr=" + stderrText
          : "Compatibility scan failed";
        Logger.w("LWEController", msg, "exitCode=", exitCode);
        return;
      }

      const result = root.applyCompatibilityScanOutput(stdoutText);
      Logger.i("LWEController", "Compatibility scan completed", "totalCount=", result.totalCount, "failedCount=", result.failedCount);
      ToastService.showNotice(
        pluginApi?.tr("panel.title"),
        pluginApi?.tr("panel.compatibilityQuickCheckFinished", {
          total: result.totalCount,
          failed: result.failedCount,
          limited: result.limitedCount
        }),
        result.failedCount > 0 ? "alert-triangle" : (result.limitedCount > 0 ? "alert-circle" : "check")
      );
    }
  }

  Timer {
    id: searchDebounceTimer
    interval: root.searchDebounceDelay
    onTriggered: {
      refreshVisibleWallpapers();
      resetPagination();
    }
  }

  Timer {
    id: propertiesLoadTimer
    interval: root.propertyLoadDelay
    onTriggered: {
      loadWallpaperProperties(pendingPath);
    }
  }

}
