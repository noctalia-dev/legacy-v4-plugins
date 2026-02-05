import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "CurrencyData.js" as CurrencyData

ColumnLayout {
  id: root

  property var cfg: pluginApi?.pluginSettings || ({})

  // Currency model with translated names
  property var currencyModel: pluginApi ? buildTranslatedCurrencyModel() : CurrencyData.buildComboModel(false)
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Display mode options
  property var displayModeModel: [
    {
      "key": "icon",
      "name": pluginApi?.tr("settings.display_modes.icon") || "Icon only"
    },
    {
      "key": "compact",
      "name": pluginApi?.tr("settings.display_modes.compact") || "Compact (rate number)"
    },
    {
      "key": "full",
      "name": pluginApi?.tr("settings.display_modes.full") || "Currency pair"
    }
  ]
  property var pluginApi: null

  // Refresh interval options (in minutes)
  property var refreshIntervalModel: [
    {
      "key": "15",
      "name": pluginApi?.tr("settings.intervals.15") || "15 minutes"
    },
    {
      "key": "30",
      "name": pluginApi?.tr("settings.intervals.30") || "30 minutes"
    },
    {
      "key": "60",
      "name": pluginApi?.tr("settings.intervals.60") || "1 hour"
    },
    {
      "key": "180",
      "name": pluginApi?.tr("settings.intervals.180") || "3 hours"
    },
    {
      "key": "360",
      "name": pluginApi?.tr("settings.intervals.360") || "6 hours"
    },
    {
      "key": "720",
      "name": pluginApi?.tr("settings.intervals.720") || "12 hours"
    }
  ]
  property string valueRefreshInterval: String(cfg.refreshInterval ?? defaults.refreshInterval ?? 60)

  // Global currency settings (used by launcher, widget, and panel)
  property string valueSourceCurrency: cfg.sourceCurrency || defaults.sourceCurrency || "USD"
  property string valueTargetCurrency: cfg.targetCurrency || defaults.targetCurrency || "EUR"

  // Widget settings
  property string valueWidgetDisplayMode: cfg.widgetDisplayMode || defaults.widgetDisplayMode || "icon"

  function buildTranslatedCurrencyModel() {
    var model = [];
    for (var i = 0; i < CurrencyData.currencies.length; i++) {
      var code = CurrencyData.currencies[i];
      var translatedName = pluginApi?.tr("currencies." + code) || CurrencyData.currencyNames[code];
      model.push({
        "key": code,
        "name": translatedName + " (" + code + ")"
      });
    }
    return model;
  }
  function saveSettings() {
    if (!pluginApi)
      return;
    pluginApi.pluginSettings.sourceCurrency = valueSourceCurrency;
    pluginApi.pluginSettings.targetCurrency = valueTargetCurrency;
    pluginApi.pluginSettings.widgetDisplayMode = valueWidgetDisplayMode;
    pluginApi.pluginSettings.refreshInterval = parseInt(valueRefreshInterval);
    pluginApi.saveSettings();
  }

  spacing: Style.marginL

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      Layout.bottomMargin: Style.marginS
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.general") || "General Settings"
    }
    NComboBox {
      Layout.fillWidth: true
      currentKey: valueSourceCurrency
      description: pluginApi?.tr("settings.source_currency_description") || "Default currency to convert from"
      label: pluginApi?.tr("settings.source_currency") || "Source Currency"
      minimumWidth: 280
      model: currencyModel

      onSelected: key => {
        valueSourceCurrency = key;
      }
    }
    NComboBox {
      Layout.fillWidth: true
      currentKey: valueTargetCurrency
      description: pluginApi?.tr("settings.target_currency_description") || "Default currency to convert to"
      label: pluginApi?.tr("settings.target_currency") || "Target Currency"
      minimumWidth: 280
      model: currencyModel

      onSelected: key => {
        valueTargetCurrency = key;
      }
    }
  }
  NDivider {
    Layout.bottomMargin: Style.marginM
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      Layout.bottomMargin: Style.marginS
      // description: "Configure the bar widget appearance and behavior"
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.widget") || "Widget Settings"
    }
    NComboBox {
      Layout.fillWidth: true
      currentKey: valueWidgetDisplayMode
      description: pluginApi?.tr("settings.display_mode_description") || "How much information to show in the bar widget"
      label: pluginApi?.tr("settings.display_mode") || "Display Mode"
      minimumWidth: 240
      model: displayModeModel

      onSelected: key => {
        valueWidgetDisplayMode = key;
      }
    }
    NComboBox {
      Layout.fillWidth: true
      currentKey: valueRefreshInterval
      defaultValue: defaults.refreshInterval
      description: pluginApi?.tr("settings.refresh_interval_description") || "How often to refresh exchange rates automatically"
      label: pluginApi?.tr("settings.refresh_interval") || "Auto-refresh Interval"
      minimumWidth: 240
      model: refreshIntervalModel

      onSelected: key => valueRefreshInterval = key
    }
  }
  Item {
    Layout.fillHeight: true
  }
}
