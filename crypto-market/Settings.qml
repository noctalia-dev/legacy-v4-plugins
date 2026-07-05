import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property var editWatchList: cfg.watchList ?? defaults.watchList ?? ["btc", "eth", "bnb", "sol", "xrp"]
  property string editBarCoin: cfg.barCoin ?? defaults.barCoin ?? "btc"
  property string editDisplayMode: cfg.displayMode ?? defaults.displayMode ?? "text"
  property bool editRedRises: cfg.redRises ?? defaults.redRises ?? false
  property int editRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 5
  property string editDataSource: cfg.dataSource ?? defaults.dataSource ?? "huobi"
  property string editMarketType: cfg.marketType ?? defaults.marketType ?? "spot"
  property string editProxyUrl: cfg.proxyUrl ?? defaults.proxyUrl ?? ""
  property string editLanguage: cfg.language ?? defaults.language ?? "en"

  property string configMessage: ""
  property bool configMessageIsError: false
  property string searchText: ""
  readonly property int localeTick: mainInstance?.refreshNonce ?? 0

  readonly property var mainInstance: pluginApi?.mainInstance

  spacing: Style.marginM

  function tr(key) {
    const tick = root.localeTick;
    return mainInstance ? mainInstance.tr(key) : key;
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.language")
    description: tr("settings.languageDesc")
    minimumWidth: 240
    model: [
      { "key": "en", "name": "English" },
      { "key": "zh-CN", "name": "中文" }
    ]
    currentKey: root.editLanguage
    defaultValue: defaults.language ?? "en"
    onSelected: key => {
      root.editLanguage = key;
      if (mainInstance) {
        mainInstance.language = key;
        mainInstance.refreshNonce++;
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.dataSource")
    description: tr("settings.dataSourceDesc")
    minimumWidth: 240
    model: [
      { "key": "huobi", "name": tr("dataSource.huobi") },
      { "key": "binance", "name": tr("dataSource.binance") },
      { "key": "okx", "name": tr("dataSource.okx") },
      { "key": "coingecko", "name": tr("dataSource.coingecko") }
    ]
    currentKey: root.editDataSource
    defaultValue: defaults.dataSource ?? "huobi"
    onSelected: key => {
      root.editDataSource = key;
      if (key === "coingecko") {
        root.editMarketType = "spot";
      }
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.marketType")
    description: tr("settings.marketTypeDesc")
    minimumWidth: 240
    visible: root.editDataSource !== "coingecko"
    model: [
      { "key": "spot", "name": tr("marketType.spot") },
      { "key": "perpetual", "name": tr("marketType.perpetual") }
    ]
    currentKey: root.editMarketType
    defaultValue: defaults.marketType ?? "spot"
    onSelected: key => root.editMarketType = key
  }

  NTextInput {
    Layout.fillWidth: true
    label: tr("settings.proxy")
    placeholderText: tr("settings.proxyPlaceholder")
    text: root.editProxyUrl
    onTextChanged: root.editProxyUrl = text
  }

  NText {
    text: tr("settings.proxyTip")
    pointSize: Style.fontSizeXS
    color: Color.mOnSurfaceVariant
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.barCoin")
    description: tr("settings.barCoinDesc")
    minimumWidth: 240
    model: buildBarCoinModel()
    currentKey: root.editBarCoin
    defaultValue: defaults.barCoin ?? "btc"
    onSelected: key => root.editBarCoin = key
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.displayMode")
    description: tr("settings.displayModeDesc")
    minimumWidth: 240
    model: [
      { "key": "text", "name": tr("settings.displayModeFull") },
      { "key": "compact", "name": tr("settings.displayModeCompact") }
    ]
    currentKey: root.editDisplayMode
    defaultValue: defaults.displayMode ?? "text"
    onSelected: key => root.editDisplayMode = key
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: tr("settings.watchList")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    text: tr("settings.watchListTip")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
  }

  NText {
    text: tr("settings.search")
    pointSize: Style.fontSizeS
    font.weight: Style.fontWeightBold
    color: Color.mOnSurfaceVariant
  }

  NTextInput {
    Layout.fillWidth: true
    placeholderText: tr("settings.searchPlaceholder")
    text: root.searchText
    onTextChanged: root.searchText = text.toLowerCase()
  }

  NText {
    text: tr("settings.searchResults")
    pointSize: Style.fontSizeXS
    color: Color.mOnSurfaceVariant
    visible: root.searchText !== ""
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    visible: root.searchText !== ""

    Repeater {
      model: getSearchResults()
      delegate: NButton {
        text: modelData.toUpperCase()
        visible: !root.editWatchList.includes(modelData)
        onClicked: {
          addCoin(modelData);
          root.searchText = "";
        }
      }
    }
  }

  Repeater {
    model: root.editWatchList
    delegate: RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NToggle {
        label: getCoinName(modelData)
        checked: true
        onToggled: checked => toggleCoin(modelData, checked)
        Layout.fillWidth: true
      }

      NIconButton {
        icon: "arrow-up"
        enabled: index > 0
        baseSize: Style.baseWidgetSize * 0.7
        onClicked: moveCoinUp(modelData)
      }

      NIconButton {
        icon: "arrow-down"
        enabled: index < root.editWatchList.length - 1
        baseSize: Style.baseWidgetSize * 0.7
        onClicked: moveCoinDown(modelData)
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: tr("settings.colorScheme")
    description: tr("settings.colorSchemeDesc")
    minimumWidth: 240
    model: [
      { "key": "red-rises", "name": tr("settings.redRises") },
      { "key": "green-rises", "name": tr("settings.greenRises") }
    ]
    currentKey: root.editRedRises ? "red-rises" : "green-rises"
    defaultValue: "green-rises"
    onSelected: key => root.editRedRises = (key === "red-rises")
  }

  NLabel {
    label: tr("settings.refreshInterval") + ": " + Math.round(root.editRefreshInterval) + " " + tr("settings.seconds")
    description: tr("settings.refreshIntervalDesc")
  }

  NSlider {
    Layout.fillWidth: true
    from: 1
    to: 60
    stepSize: 1
    value: root.editRefreshInterval
    onValueChanged: root.editRefreshInterval = Math.round(value)
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: tr("settings.configMgmt")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    text: tr("settings.configPath")
    pointSize: Style.fontSizeXS
    color: Color.mOnSurfaceVariant
  }

  RowLayout {
    spacing: Style.marginM

    NButton {
      text: tr("settings.export")
      onClicked: exportConfig()
    }

    NButton {
      text: tr("settings.import")
      onClicked: importConfig()
    }
  }

  NText {
    visible: root.configMessage !== ""
    text: root.configMessage
    pointSize: Style.fontSizeS
    color: root.configMessageIsError ? Color.mError : Color.mPrimary
  }

  Connections {
    target: mainInstance

    function onImportNonceChanged() {
      root.configMessage = mainInstance.importMessage;
      root.configMessageIsError = !mainInstance.importOk;
      if (mainInstance.importOk) {
        root.syncFromMainInstance();
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) return;

    const normalizedWatchList = normalizeEditWatchList();
    const normalizedBarCoin = normalizedWatchList.includes(normalizeAsset(root.editBarCoin)) ? normalizeAsset(root.editBarCoin) : normalizedWatchList[0];

    pluginApi.pluginSettings.watchList = normalizedWatchList;
    pluginApi.pluginSettings.barCoin = normalizedBarCoin;
    pluginApi.pluginSettings.displayMode = root.editDisplayMode;
    pluginApi.pluginSettings.redRises = root.editRedRises;
    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval;
    pluginApi.pluginSettings.dataSource = root.editDataSource;
    pluginApi.pluginSettings.marketType = effectiveMarketType();
    pluginApi.pluginSettings.proxyUrl = root.editProxyUrl;
    pluginApi.pluginSettings.language = root.editLanguage;
    pluginApi.saveSettings();

    if (mainInstance) {
      mainInstance.applyConfig({
        watchList: normalizedWatchList,
        barCoin: normalizedBarCoin,
        displayMode: root.editDisplayMode,
        redRises: root.editRedRises,
        refreshInterval: root.editRefreshInterval,
        dataSource: root.editDataSource,
        marketType: effectiveMarketType(),
        proxyUrl: root.editProxyUrl,
        language: root.editLanguage
      }, false);
    }
  }

  function exportConfig() {
    if (mainInstance) {
      mainInstance.exportConfig();
      root.configMessage = tr("settings.configExported");
      root.configMessageIsError = false;
    }
  }

  function importConfig() {
    if (mainInstance) {
      mainInstance.importConfig();
    }
  }

  function syncFromMainInstance() {
    root.editWatchList = mainInstance.watchList;
    root.editBarCoin = mainInstance.barCoin;
    root.editDisplayMode = mainInstance.displayMode;
    root.editRedRises = mainInstance.redRises;
    root.editRefreshInterval = mainInstance.refreshInterval;
    root.editDataSource = mainInstance.dataSource;
    root.editMarketType = mainInstance.marketType;
    root.editProxyUrl = mainInstance.proxyUrl;
    root.editLanguage = mainInstance.language;
  }

  function toggleCoin(coin, checked) {
    const key = normalizeAsset(coin);
    let list = [...root.editWatchList];
    if (checked) {
      if (!list.includes(key)) {
        list.push(key);
      }
    } else {
      const index = list.indexOf(key);
      if (index > -1) {
        list.splice(index, 1);
      }
    }
    root.editWatchList = list;
  }

  function moveCoinUp(coin) {
    let list = [...root.editWatchList];
    const index = list.indexOf(coin);
    if (index > 0) {
      [list[index - 1], list[index]] = [list[index], list[index - 1]];
      root.editWatchList = list;
    }
  }

  function moveCoinDown(coin) {
    let list = [...root.editWatchList];
    const index = list.indexOf(coin);
    if (index < list.length - 1) {
      [list[index], list[index + 1]] = [list[index + 1], list[index]];
      root.editWatchList = list;
    }
  }

  function getCoinName(coin) {
    if (mainInstance) return mainInstance.getCoinName(coin);
    return String(coin || "").toUpperCase();
  }

  function normalizeAsset(symbol) {
    return mainInstance ? mainInstance.normalizeAssetKey(symbol) : String(symbol || "").trim().toLowerCase();
  }

  function normalizeEditWatchList() {
    const result = [];
    const seen = {};
    for (let i = 0; i < root.editWatchList.length; i++) {
      const key = normalizeAsset(root.editWatchList[i]);
      if (key !== "" && !seen[key]) {
        seen[key] = true;
        result.push(key);
      }
    }
    return result.length > 0 ? result : ["btc"];
  }

  function effectiveMarketType() {
    return root.editDataSource === "coingecko" ? "spot" : root.editMarketType;
  }

  function buildBarCoinModel() {
    const model = [];
    const seen = {};
    const append = function(symbol) {
      const key = mainInstance ? mainInstance.normalizeAssetKey(symbol) : String(symbol || "").toLowerCase();
      if (key !== "" && !seen[key]) {
        seen[key] = true;
        model.push({ "key": key, "name": getCoinName(key) });
      }
    };

    root.editWatchList.forEach(append);
    ["btc", "eth", "bnb", "sol", "xrp"].forEach(append);
    return model;
  }

  function getSearchResults() {
    if (!root.searchText || root.searchText === "") {
      return [];
    }
    if (mainInstance) {
      return mainInstance.searchCoinSymbols(root.searchText);
    }
    return [];
  }

  function addCoin(coin) {
    const key = normalizeAsset(coin);
    let list = [...root.editWatchList];
    if (key !== "" && !list.includes(key)) {
      list.push(key);
      root.editWatchList = list;
    }
  }
}
