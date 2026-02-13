import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property string baseCurrency: "USD"
  property int cacheMinutes: 5
  property var cachedRates: ({})
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property real lastFetch: 0
  property real lastFetchAttempt: 0
  property bool loaded: false
  property bool loading: false
  property var pluginApi: null
  property int refreshInterval: parseInt(cfg.refreshInterval ?? defaults.refreshInterval ?? 5)
  property int retryDelaySeconds: 10

  // Signal emitted when rates are updated
  signal ratesUpdated

  function convert(amount, from, to) {
    if (!cachedRates || Object.keys(cachedRates).length === 0) {
      return null;
    }
    if (!cachedRates.hasOwnProperty(from) || !cachedRates.hasOwnProperty(to)) {
      return null;
    }
    var fromRate = cachedRates[from];
    var toRate = cachedRates[to];
    // Convert: amount in FROM -> USD -> TO
    var inUsd = amount / fromRate;
    return inUsd * toRate;
  }
  function copyToClipboard(text) {
    var escaped = text.replace(/'/g, "'\\''");
    Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
  }
  function fetchRates(forceRetry) {
    var now = Date.now();
    var cacheMs = cacheMinutes * 60 * 1000;
    var retryMs = retryDelaySeconds * 1000;

    if (loading)
      return;
    Logger.i("CurrencyEx", "Loading rates");
    if (loaded && (now - lastFetch) < cacheMs)
      return;
    // Don't auto-retry too soon after a failed attempt (unless forced)
    if (!forceRetry && !loaded && lastFetchAttempt > 0 && (now - lastFetchAttempt) < retryMs)
      return;

    loading = true;
    lastFetchAttempt = now;
    apiProcess.running = true;
  }
  function formatNumber(num) {
    if (num >= 1000) {
      return num.toLocaleString('en-US', {
        maximumFractionDigits: 2
      });
    } else if (num >= 1) {
      return num.toFixed(2);
    } else if (num > 0) {
      return num.toFixed(4);
    }
    return "0";
  }
  function getRate(from, to) {
    if (!cachedRates || Object.keys(cachedRates).length === 0) {
      return null;
    }
    if (!cachedRates.hasOwnProperty(from) || !cachedRates.hasOwnProperty(to)) {
      return null;
    }
    var fromRate = cachedRates[from];
    var toRate = cachedRates[to];
    return toRate / fromRate;
  }
  function isValidCurrency(code) {
    return cachedRates.hasOwnProperty(code);
  }

  // Initialize rates on component load
  Component.onCompleted: {
    fetchRates();
  }

  Process {
    id: apiProcess

    command: ["curl", "-sf", "--connect-timeout", "5", "--max-time", "10", "https://api.frankfurter.app/latest?from=USD"]
    running: false

    stdout: StdioCollector {
    }

    onExited: exitCode => {
      loading = false;
      if (exitCode === 0) {
        try {
          var response = JSON.parse(stdout.text);
          if (response.rates) {
            // Add USD to rates (it's the base)
            response.rates["USD"] = 1.0;
            cachedRates = response.rates;
            loaded = true;
            lastFetch = Date.now();
            Logger.i("CurrencyEx", "Rates loaded:", Object.keys(cachedRates).length, "currencies");
            ratesUpdated();
          }
        } catch (e) {
          Logger.e("CurrencyEx", "Failed to parse rates:", e);
        }
      } else {
        Logger.e("CurrencyEx", "Failed to fetch rates, exit code:", exitCode);
      }
    }
  }

  // Auto-refresh Timer
  Timer {
    id: refreshTimer

    interval: refreshInterval * 60 * 1000
    repeat: true
    running: refreshInterval > 0

    onTriggered: fetchRates()
  }

  // =============================================================================
  // IPC Handler (for keyboard shortcut toggle)
  // =============================================================================
  IpcHandler {
    target: "plugin:currency-exchange"

    function togglePanel() {
      pluginApi.withCurrentScreen(screen => {
        pluginApi.togglePanel(screen);
      });
    }

    function toggle() {
      pluginApi.withCurrentScreen(screen => {
        pluginApi.toggleLauncher(screen);
      });
    }
  }
}
