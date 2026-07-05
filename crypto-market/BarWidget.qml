import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property string barCoin: mainInstance?.barCoin ?? "btc"
  readonly property bool isLoading: mainInstance?.isLoading ?? true
  readonly property string errorMsg: mainInstance?.errorMessage ?? ""
  readonly property int tick: mainInstance?.refreshNonce ?? 0
  readonly property string displayMode: mainInstance?.displayMode ?? "text"

  // 强制重新计算 coinData，依赖 tick
  readonly property var coinData: {
    const t = tick;
    const key = mainInstance?.normalizeAssetKey(barCoin) ?? barCoin;
    return mainInstance?.marketData[key];
  }

  function tr(key) {
    const t = tick;
    return mainInstance ? mainInstance.tr(key) : key;
  }

  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: ""
    text: {
      const t = tick;
      const coin = barCoin;
      const mode = displayMode;
      const loading = isLoading;
      const err = errorMsg;

      if (err) return "⚠";
      if (loading) return "...";

      const data = coinData;
      if (!data) return "--";

      const price = mainInstance?.formatPrice(data.close) ?? "--";
      return mode === "text" ? `${coin.toUpperCase()} ${price}` : price;
    }
    suffix: {
      const t = tick;
      const loading = isLoading;
      const err = errorMsg;
      const data = coinData;

      if (err || loading || !data) return "";
      return data.isRising ? "↑" : "↓";
    }
    autoHide: false
    forceOpen: true
    tooltipText: {
      if (root.errorMsg) return `${root.tr("panel.error")}: ${root.errorMsg}`;
      if (root.isLoading) return root.tr("panel.loading");
      const data = coinData;
      if (!data) return root.tr("panel.noData");
      const priceLabel = root.tr("panel.price");
      const changeLabel = root.tr("panel.change");
      return `${barCoin.toUpperCase()}\n${priceLabel}: ${mainInstance?.formatPrice(data.close)}\n${changeLabel}: ${mainInstance?.formatChange(data.change)}`;
    }
    customBackgroundColor: root.errorMsg ? "#3a3a3a" : "transparent"
    customTextIconColor: root.errorMsg ? "#888888" : "transparent"

    onClicked: togglePanel()
    onRightClicked: PanelService.showContextMenu(contextMenu, pill, screen)
  }

  // 右键菜单
  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "📊 " + root.tr("barWidget.openPanel"),
        "action": "open-panel"
      },
      {
        "label": "🔤 " + (root.displayMode === "text" ? root.tr("barWidget.switchCompact") : root.tr("barWidget.switchFull")),
        "action": "toggle-mode"
      },
      {
        "label": "⚙️ " + root.tr("panel.settings"),
        "action": "settings"
      },
      {
        "label": "🔄 " + root.tr("panel.refreshNow"),
        "action": "refresh"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "open-panel") {
        togglePanel();
      } else if (action === "toggle-mode" && pluginApi) {
        const newMode = root.displayMode === "text" ? "compact" : "text";
        pluginApi.pluginSettings.displayMode = newMode;
        if (mainInstance) mainInstance.displayMode = newMode;
        pluginApi.saveSettings();
      } else if (action === "settings" && pluginApi) {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      } else if (action === "refresh") {
        mainInstance?.watchList.forEach(function(coin) {
          mainInstance?.fetchMarketData(coin);
        });
      }
    }
  }

  function togglePanel() {
    if (pluginApi) {
      pluginApi.togglePanel(screen);
    }
  }
}
