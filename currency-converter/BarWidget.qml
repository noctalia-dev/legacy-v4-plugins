import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  
  readonly property bool isVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Widget settings
  readonly property string fromCurrency: cfg.fromCurrency || defaults.fromCurrency || "USD"
  readonly property string toCurrency: cfg.toCurrency || defaults.toCurrency || "BRL"
  readonly property int updateInterval: cfg.updateInterval ?? defaults.updateInterval ?? 30
  readonly property string displayMode: cfg.displayMode || defaults.displayMode || "both"

  // State
  property real exchangeRate: 0.0
  property bool loading: false
  property bool error: false
  property string errorMessage: ""
  property real customAmount: 1.0
  property var allRates: ({})  // Store all exchange rates

  implicitWidth: Math.max(60, isVertical ? (Style.capsuleHeight || 32) : contentWidth)
  implicitHeight: Math.max(32, isVertical ? contentHeight : (Style.capsuleHeight || 32))
  radius: Style.radiusM || 8
  color: Style.capsuleColor || "#1E1E1E"
  border.color: Style.capsuleBorderColor || "#2E2E2E"
  border.width: Style.capsuleBorderWidth || 1

  readonly property real contentWidth: {
    if (isVertical) return Style.capsuleHeight || 32;
    var iconWidth = Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.6) : 20;
    var textWidth = rateText ? (rateText.implicitWidth + (Style.marginS || 4)) : 80;
    if (displayMode === "icon") return iconWidth + (Style.marginM || 8) * 2;
    if (displayMode === "text") return textWidth + (Style.marginM || 8) * 2 + 24;
    return iconWidth + textWidth + (Style.marginM || 8) * 2 + 24;
  }

  readonly property real contentHeight: {
    if (!isVertical) return Style.capsuleHeight || 32;
    var iconHeight = Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.6) : 20;
    var textHeight = rateText ? rateText.implicitHeight : 16;
    return Math.max(iconHeight, textHeight) + (Style.marginS || 4) * 2;
  }

  // API call process
  Process {
    id: apiProcess
    running: false

    command: [
      "curl",
      "-s",
      `https://api.exchangerate-api.com/v4/latest/${fromCurrency}`
    ]

    stdout: StdioCollector {}

    onExited: exitCode => {
      loading = false;
      if (exitCode === 0) {
        try {
          var response = JSON.parse(stdout.text);
          if (response.rates) {
            allRates = response.rates;
            if (response.rates[toCurrency]) {
              exchangeRate = response.rates[toCurrency];
              error = false;
              errorMessage = "";
            } else {
              error = true;
              errorMessage = I18n.tr("currency-converter.error.invalid-currency") || "Invalid currency";
            }
          } else {
            error = true;
            errorMessage = I18n.tr("currency-converter.error.invalid-currency") || "Invalid currency";
          }
        } catch (e) {
          error = true;
          errorMessage = I18n.tr("currency-converter.error.parse") || "Parse error";
        }
      } else {
        error = true;
        errorMessage = I18n.tr("currency-converter.error.network") || "Network error";
      }
    }
  }

  // Update timer
  Timer {
    id: updateTimer
    interval: updateInterval * 60000 // Convert minutes to milliseconds
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: fetchExchangeRate()
  }

  Component.onCompleted: {
    Logger.d("Currency Converter Widget loaded");
    Logger.d("From:", fromCurrency, "To:", toCurrency);
    Logger.d("Display mode:", displayMode);
    Logger.d("Width:", width, "Height:", height);
  }

  function fetchExchangeRate() {
    if (loading) return;
    loading = true;
    error = false;
    apiProcess.running = true;
  }

  readonly property string displayText: {
    if (loading) return "Carregando...";
    if (error) return "Erro";
    if (exchangeRate === 0.0) return "--";
    return `1 ${fromCurrency} = ${exchangeRate.toFixed(2)} ${toCurrency}`;
  }

  readonly property string tooltipText: {
    if (error) return errorMessage;
    if (exchangeRate === 0.0) return "Aguardando dados...";
    return `${displayText}\nClique para abrir o conversor`;
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: isVertical ? 0 : (Style.marginM || 8)
    anchors.rightMargin: isVertical ? 0 : 32
    anchors.topMargin: isVertical ? (Style.marginS || 4) : 0
    anchors.bottomMargin: isVertical ? (Style.marginS || 4) : 0
    spacing: Style.marginS || 4
    visible: !isVertical

    NIcon {
      icon: error ? "alert-circle" : (loading ? "loader" : "currency-dollar")
      color: error ? (Color.mError || "#F44336") : (Color.mPrimary || "#2196F3")
      pointSize: Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.5) : 16
      Layout.alignment: Qt.AlignVCenter
      visible: displayMode !== "text"
      
      RotationAnimator on rotation {
        running: loading && !error
        from: 0
        to: 360
        duration: 1000
        loops: Animation.Infinite
      }
    }

    NText {
      id: rateText
      text: displayText
      color: error ? (Color.mError || "#F44336") : (Color.mOnSurface || "#FFFFFF")
      pointSize: Style.barFontSize || 11
      applyUiScale: false
      Layout.alignment: Qt.AlignVCenter
      visible: displayMode !== "icon"
    }
  }

  // Vertical layout
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginS || 4
    spacing: Style.marginXS || 2
    visible: isVertical

    NIcon {
      icon: error ? "alert-circle" : (loading ? "loader" : "currency-dollar")
      color: error ? (Color.mError || "#F44336") : (Color.mPrimary || "#2196F3")
      pointSize: Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.45) : 14
      Layout.alignment: Qt.AlignHCenter
      
      RotationAnimator on rotation {
        running: loading && !error
        from: 0
        to: 360
        duration: 1000
        loops: Animation.Infinite
      }
    }

    NText {
      text: `${exchangeRate.toFixed(2)}`
      color: error ? (Color.mError || "#F44336") : (Color.mOnSurface || "#FFFFFF")
      pointSize: (Style.barFontSize || 11) * 0.8
      applyUiScale: false
      Layout.alignment: Qt.AlignHCenter
      visible: !loading && !error && exchangeRate > 0
    }
  }

  // Mouse interaction
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: {
      if (!pluginApi) return;

      // Prefer opening the panel anchored to this widget instance so it opens near the button
      try {
        var screenRef = pluginApi?.panelOpenScreen || screen;
        if (screenRef) {
          pluginApi.openPanel(screenRef, root);
          return;
        }

        if (pluginApi && pluginApi.withCurrentScreen) {
          pluginApi.withCurrentScreen(function(s) {
            pluginApi.openPanel(s, root);
          });
          return;
        }

        // Fallbacks for older API signatures
        try {
          pluginApi.openPanel(root.screen, root);
        } catch (e) {
          try {
            pluginApi.openPanel(root.screen);
          } catch (err) {
            Logger.w("Currency", "openPanel failed:", err);
          }
        }
      } catch (e) {
        Logger.w("Currency", "openPanel unexpected error:", e);
      }
    }

    onEntered: {
      if (tooltipText) {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection());
      }
    }
    
    onExited: {
      TooltipService.hide();
    }
  }
}
