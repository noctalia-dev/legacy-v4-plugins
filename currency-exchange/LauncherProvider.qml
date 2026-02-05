import QtQuick
import Quickshell
import qs.Commons
import "CurrencyData.js" as CurrencyData

Item {
  id: root

  // Delegate to Main.qml
  readonly property var cachedRates: main?.cachedRates || ({})

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property bool handleSearch: false

  // Icon mode (tabler vs native)
  property string iconMode: Settings.data.appLauncher.iconMode
  property var launcher: null
  readonly property bool loaded: main?.loaded || false
  readonly property bool loading: main?.loading || false

  // Access Main.qml instance for shared state/functions
  readonly property var main: pluginApi?.mainInstance

  // Provider metadata
  property string name: "FX"
  property var pluginApi: null
  property string sourceCurrency: cfg.sourceCurrency || defaults.sourceCurrency || "USD"
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: false
  property string targetCurrency: cfg.targetCurrency || defaults.targetCurrency || "EUR"

  function commands() {
    return [
      {
        "name": ">fx",
        "description": pluginApi?.tr("launcher.command_description") || "Quick currency conversion (e.g., >fx 100 USD EUR)",
        "icon": icon("cash", "accessories-calculator"),
        "isTablerIcon": iconMode === "tabler",
        "isImage": false,
        "onActivate": function () {
          launcher.setSearchText(">fx ");
        }
      }
    ];
  }
  function doConversion(amount, from, to) {
    if (!main)
      return [];

    var result = main.convert(amount, from, to);
    var rate = main.getRate(from, to);

    // Handle invalid currency codes
    if (result === null || rate === null) {
      var invalidCurrency = !main.isValidCurrency(from) ? from : to;
      return [
        {
          "name": pluginApi?.tr("launcher.unknown_currency", {
            currency: invalidCurrency
          }) || ("Unknown currency: " + invalidCurrency),
          "description": pluginApi?.tr("launcher.currency_not_found") || "Currency code not found in exchange rates",
          "icon": icon("alert-circle", "dialog-warning"),
          "isTablerIcon": iconMode === "tabler",
          "isImage": false,
          "onActivate": function () {}
        }
      ];
    }

    var resultStr = main.formatNumber(result);
    var rateStr = main.formatNumber(rate);

    var results = [];

    // Main result
    results.push({
      "name": amount + " " + from + " = " + resultStr + " " + to,
      "description": pluginApi?.tr("launcher.rate_click_copy", {
        from: from,
        rate: rateStr,
        to: to
      }) || ("Rate: 1 " + from + " = " + rateStr + " " + to + " | Click to copy"),
      "icon": icon("cash", "accessories-calculator"),
      "isTablerIcon": iconMode === "tabler",
      "isImage": false,
      "onActivate": function () {
        main.copyToClipboard(resultStr);
        launcher.close();
      }
    });

    // Reverse conversion
    var reverseRate = main.getRate(to, from);
    results.push({
      "name": pluginApi?.tr("widget.rate_format", {
        from: to,
        rate: main.formatNumber(reverseRate),
        to: from
      }) || ("1 " + to + " = " + main.formatNumber(reverseRate) + " " + from),
      "description": pluginApi?.tr("launcher.reverse_rate") || "Reverse rate | Click to copy",
      "icon": icon("arrows-exchange", "view-refresh"),
      "isTablerIcon": iconMode === "tabler",
      "isImage": false,
      "onActivate": function () {
        main.copyToClipboard(main.formatNumber(reverseRate));
        launcher.close();
      }
    });

    return results;
  }
  function getResults(searchText) {
    if (!searchText.startsWith(">fx")) {
      return [];
    }

    // Ensure rates are loaded
    if (main) {
      main.fetchRates();
    }

    if (loading) {
      return [
        {
          "name": pluginApi?.tr("launcher.loading") || "Loading exchange rates...",
          "description": pluginApi?.tr("launcher.fetching") || "Fetching from frankfurter.app",
          "icon": icon("refresh", "view-refresh"),
          "isTablerIcon": iconMode === "tabler",
          "isImage": false,
          "onActivate": function () {}
        }
      ];
    }

    if (!loading && !loaded) {
      return [
        {
          "name": pluginApi?.tr("panel.error") || "Could not load rates",
          "description": pluginApi?.tr("launcher.error_retry") || "Check your internet connection. Click to retry.",
          "icon": icon("alert-circle", "dialog-warning"),
          "isTablerIcon": iconMode === "tabler",
          "isImage": false,
          "onActivate": function () {
            if (main)
              main.fetchRates(true);
          }
        }
      ];
    }

    var query = searchText.slice(3).trim().toUpperCase();

    if (query === "") {
      return getUsageHelp();
    }

    var parsed = parseQuery(query);
    if (!parsed) {
      return getUsageHelp();
    }

    // Handle invalid/unknown currency
    if (parsed.error) {
      return [
        {
          "name": parsed.error,
          "description": pluginApi?.tr("launcher.try_valid_code") || "Try a valid currency code (e.g., USD, EUR, PLN)",
          "icon": icon("alert-circle", "dialog-warning"),
          "isTablerIcon": iconMode === "tabler",
          "isImage": false,
          "onActivate": function () {}
        }
      ];
    }

    return doConversion(parsed.amount, parsed.from, parsed.to);
  }
  function getUsageHelp() {
    return [
      {
        "name": ">fx 100 USD EUR",
        "description": pluginApi?.tr("launcher.convert_example", {
          amount: "100",
          from: "USD",
          to: "EUR"
        }) || "Convert 100 USD to EUR",
        "icon": icon("cash", "accessories-calculator"),
        "isTablerIcon": iconMode === "tabler",
        "isImage": false,
        "onActivate": function () {
          launcher.setSearchText(">fx 100 USD EUR");
        }
      },
      {
        "name": ">fx 50 BRL",
        "description": pluginApi?.tr("launcher.convert_to_default", {
          amount: "50",
          from: "BRL",
          to: targetCurrency
        }) || ("Convert 50 BRL to " + targetCurrency + " (default)"),
        "icon": icon("cash", "accessories-calculator"),
        "isTablerIcon": iconMode === "tabler",
        "isImage": false,
        "onActivate": function () {
          launcher.setSearchText(">fx 50 BRL");
        }
      },
      {
        "name": ">fx EUR GBP",
        "description": pluginApi?.tr("launcher.show_rate", {
          from: "EUR",
          to: "GBP"
        }) || "Show rate for 1 EUR to GBP",
        "icon": icon("percentage", "accessories-calculator"),
        "isTablerIcon": iconMode === "tabler",
        "isImage": false,
        "onActivate": function () {
          launcher.setSearchText(">fx EUR GBP");
        }
      }
    ];
  }
  function handleCommand(searchText) {
    return searchText.startsWith(">fx");
  }
  function icon(tablerName, nativeName) {
    return iconMode === "tabler" ? tablerName : nativeName;
  }
  function init() {
    if (main && !loading && !loaded) {
      main.fetchRates();
    }
  }
  function parseQuery(query) {
    // Normalize: split "100PLN" into "100 PLN"
    query = query.replace(/(\d)([A-Z])/g, "$1 $2");

    // Split and filter out empty parts and "TO" keyword
    var parts = query.split(/\s+/).filter(p => p.length > 0 && p !== "TO");

    if (parts.length === 0) {
      return null;
    }

    var amount = 1;
    var from = null;
    var to = targetCurrency;

    // Try to parse amount from first part
    var firstNum = parseFloat(parts[0]);
    var startIdx = 0;

    if (!isNaN(firstNum) && firstNum > 0) {
      amount = firstNum;
      startIdx = 1;
    }

    var currencies = parts.slice(startIdx);

    if (currencies.length === 0) {
      // No currency specified - use defaults
      from = sourceCurrency;
      to = targetCurrency;
    } else if (currencies.length === 1) {
      from = currencies[0];
      // If source equals default target, flip to source currency
      if (from === targetCurrency) {
        to = sourceCurrency;
      }
    } else {
      from = currencies[0];
      to = currencies[1];
    }

    // Wait for complete currency codes (3 chars) before validating
    if (from.length < 3) {
      return null;
    }

    // Validate currencies
    if (!cachedRates[from]) {
      return {
        error: pluginApi?.tr("launcher.unknown_currency", {
          currency: from
        }) || ("Unknown currency: " + from)
      };
    }
    if (to.length >= 3 && !cachedRates[to]) {
      return {
        error: pluginApi?.tr("launcher.unknown_currency", {
          currency: to
        }) || ("Unknown currency: " + to)
      };
    }
    if (to.length < 3) {
      return null;
    }

    return {
      amount: amount,
      from: from,
      to: to
    };
  }

  // Update results when rates change
  Connections {
    function onRatesUpdated() {
      if (launcher) {
        launcher.updateResults();
      }
    }

    target: main
  }
}
