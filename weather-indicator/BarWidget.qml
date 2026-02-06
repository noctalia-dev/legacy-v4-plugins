import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Widgets
import qs.Services.UI

// Bar Widget Component
Item {
  id: root

  property var pluginApi: null
  readonly property bool weatherReady: Settings.data.location.weatherEnabled && (LocationService.data.weather !== null)

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Get settings or use false
  readonly property bool showTempValue: pluginApi?.pluginSettings?.showTempValue ?? true
  readonly property bool showConditionIcon: pluginApi?.pluginSettings?.showConditionIcon ?? true
  readonly property bool showTempUnit: pluginApi?.pluginSettings?.showTempUnit ?? true
  readonly property string tooltipOption: pluginApi?.pluginSettings?.tooltipOption || pluginApi?.manifest?.defaultSettings?.tooltipOption || "all"

  // Bar positioning properties
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property real contentWidth: isVertical ? root.barHeight - Style.marginL : layout.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: isVertical ? layout.implicitHeight + Style.marginS * 2 : root.capsuleHeight

  visible: root.weatherReady
  opacity: root.weatherReady ? 1.0 : 0.0

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color:  Style.capsuleColor
    radius: !isVertical ? Style.radiusM : width * 0.5
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Item {
      id: layout
      anchors.centerIn: parent

      implicitWidth: grid.implicitWidth
      implicitHeight: grid.implicitHeight

      GridLayout {
        id: grid
        columns: root.isVertical ? 1 : 2
        rowSpacing: Style.marginS
        columnSpacing: Style.marginS

        NIcon {
          visible: root.showConditionIcon
          Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
          icon: weatherReady ? LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode, LocationService.data.weather.current_weather.is_day) : "weather-cloud-off"
          applyUiScale: false
          color: Color.mOnSurface
        }

        NText {
          visible: root.showTempValue
          text: {
            if (!weatherReady || !root.showTempValue) {
              return "";
            }
            var temp = LocationService.data.weather.current_weather.temperature;
            var suffix = "°C";
            if (Settings.data.location.useFahrenheit) {
              temp = LocationService.celsiusToFahrenheit(temp);
              var suffix = "°F";
            }
            temp = Math.round(temp);
            if (!root.showTempUnit || isVertical) {
              suffix = "";
            }
            return `${temp}${suffix}`;
          }
          color: Color.mOnSurface
          pointSize: root.barFontSize
          applyUiScale: false
        }
      }
    }
  }

MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: {
        if (tooltipOption !== "disable") {
            buildTooltip();
        }
    }

    onExited: {
    TooltipService.hide();
    }

    onClicked: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          PanelService.getPanel("clockPanel", screen)?.toggle(root);
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }
}

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.openPanel") || "Open Calendar",
        "action": "open",
        "icon": "calendar"
      },
      {
        "label": pluginApi?.tr("menu.settings") || "Widget Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "open") {
        PanelService.getPanel("clockPanel", screen)?.toggle(root);
      } else if (action === "settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      }
    }
  }

function buildCurrentTemp() {
    let rows = [];
    var temp = LocationService.data.weather.current_weather.temperature;
    var suffix = "°C";

    if (Settings.data.location.useFahrenheit) {
        temp = LocationService.celsiusToFahrenheit(temp)
        suffix = "°F";
    }

    rows.push([("Current"), `${Math.round(temp)}${suffix}`]);
    return rows;
}

function buildHiLowTemps() {
    let rows = [];
    var max = LocationService.data.weather.daily.temperature_2m_max[0]
    var min = LocationService.data.weather.daily.temperature_2m_min[0]
    var suffix = "°C";

    if (Settings.data.location.useFahrenheit) {
        max = LocationService.celsiusToFahrenheit(max)
        min = LocationService.celsiusToFahrenheit(min)
        suffix = "°F";
    }

    rows.push([("High"), `${Math.round(max)}${suffix}`]);
    rows.push([("Low"), `${Math.round(min)}${suffix}`]);

    return rows;
}

function buildSunriseSunset() {
    let rows = [];
    var riseDate = new Date(LocationService.data.weather.daily.sunrise[0])
    var setDate  = new Date(LocationService.data.weather.daily.sunset[0])

    var options = { hour: '2-digit', minute: '2-digit' };
    var rise = riseDate.toLocaleTimeString(undefined, options);
    var set  = setDate.toLocaleTimeString(undefined, options);

    rows.push([("Sunrise"), rise]);
    rows.push([("Sunset"), set]);
    return rows;
}

function buildTooltip() {
    let allRows = [];
    switch (tooltipOption) {
        case "highlow": {
            allRows.push(...buildHiLowTemps());
            break
        }
        case "sunrise": {
            allRows.push(...buildSunriseSunset())
            break
        }
        case "everything": {
            allRows.push(...buildCurrentTemp());
            allRows.push(...buildHiLowTemps())
            allRows.push(...buildSunriseSunset());
            break
        }
        default:
            break
    }
    if (allRows.length > 0) {
      TooltipService.show(root, allRows, BarService.getTooltipDirection())
    }
  }
}
