import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  // Bar orientation
  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property int capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  readonly property real visualContentWidth: {
    var iconWidth = Style.toOdd(capsuleHeight * 0.4);
    if (displayMode === "icon") {
      return iconWidth + Style.marginM * 2;
    }
    var textWidth = rateText.implicitWidth + Style.marginM;
    if (displayMode === "compact") {
      return iconWidth + textWidth + Style.marginM * 2;
    }
    // full mode
    return iconWidth + textWidth + Style.marginM * 2;
  }
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Settings
  readonly property string displayMode: cfg.widgetDisplayMode || defaults.widgetDisplayMode || "icon"

  // Display text based on mode
  readonly property string displayText: {
    if (loading)
      return "...";
    if (!loaded || rate === 0)
      return "--";
    // compact mode
    if (displayMode === "compact") {
      return main.formatNumber(rate);
    }
    // full mode
    return "1 " + fromCurrency + " = " + main.formatNumber(rate) + " " + toCurrency;
  }
  readonly property string fromCurrency: cfg.sourceCurrency || defaults.sourceCurrency || "USD"
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property bool loaded: main?.loaded || false

  // State from Main.qml
  readonly property bool loading: main?.loading || false

  // Access Main.qml instance for shared state/functions
  readonly property var main: pluginApi?.mainInstance

  // Required properties injected by PluginBarWidgetSlot
  property var pluginApi: null
  readonly property real rate: main ? main.getRate(fromCurrency, toCurrency) : 0
  property ShellScreen screen
  property string section: ""
  readonly property string toCurrency: cfg.targetCurrency || defaults.targetCurrency || "EUR"
  readonly property string tooltipText: {
    if (loading)
      return pluginApi?.tr("widget.loading") || "Loading exchange rates...";
    if (!loaded)
      return pluginApi?.tr("widget.error") || "Could not load rates, check your internet connection.";
    var rateStr = pluginApi?.tr("widget.rate_format", { from: fromCurrency, rate: main.formatNumber(rate), to: toCurrency }) || ("1 " + fromCurrency + " = " + main.formatNumber(rate) + " " + toCurrency);
    var clickStr = pluginApi?.tr("widget.click_to_open") || "Click to open converter";
    return rateStr + "\n" + clickStr;
  }
  property string widgetId: ""

  readonly property real contentWidth: isVertical ? capsuleHeight : visualContentWidth
  readonly property real contentHeight: capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // Fetch rates on load
  Component.onCompleted: {
    if (main) {
      main.fetchRates();
    }
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusM
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Horizontal layout
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.marginS
      anchors.rightMargin: Style.marginS
      spacing: Style.marginS
      visible: !isVertical

      // Loading spinner
      NIcon {
        Layout.alignment: Qt.AlignVCenter
        color: Color.mOnSurfaceVariant
        icon: "loader"
        visible: loading

        RotationAnimator on rotation {
          duration: 1000
          from: 0
          loops: Animation.Infinite
          to: 360
        }
      }
      NIcon {
        Layout.alignment: Qt.AlignVCenter
        applyUiScale: false
        icon: "currency-dollar"
        visible: !loading
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
      }
      NText {
        id: rateText

        Layout.alignment: Qt.AlignVCenter
        applyUiScale: false
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        font.weight: Font.Medium
        pointSize: Style.getBarFontSizeForScreen(screen?.name)
        text: displayText
        visible: displayMode !== "icon"
      }
    }

    // Vertical layout - icon only option
    ColumnLayout {
      anchors.fill: parent
      spacing: Style.marginS
      visible: isVertical

      // Loading spinner
      NIcon {
        Layout.alignment: Qt.AlignVCenter
        color: Color.mOnSurfaceVariant
        icon: "loader"
        visible: loading

        RotationAnimator on rotation {
          duration: 1000
          from: 0
          loops: Animation.Infinite
          to: 360
        }
      }
      NIcon {
        Layout.alignment: Qt.AlignHCenter
        icon: "currency-dollar"
        visible: !loading
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
      }
    }
  }

  // Mouse interaction
  MouseArea {
    id: mouseArea
    acceptedButtons: Qt.LeftButton
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: {
      if (pluginApi) {
        pluginApi.openPanel(screen, this);
      }
    }
    onEntered: {
      TooltipService.show(root, tooltipText, BarService.getTooltipDirection());
    }
    onExited: {
      TooltipService.hide();
    }
  }
}
