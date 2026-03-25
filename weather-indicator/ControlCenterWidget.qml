import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Widgets
import qs.Services.UI

NIconButtonHot {

    property ShellScreen screen
    property var pluginApi: null
    readonly property bool weatherReady: Settings.data.location.weatherEnabled && (LocationService.data.weather !== null)

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    readonly property string tooltipOption: cfg.tooltipOption ?? defaults.tooltipOption ?? "everything"
    readonly property string iconText: weatherReady ? LocationService.weatherSymbolFromCode(LocationService.data.weather.current_weather.weathercode, LocationService.data.weather.current_weather.is_day) : "weather-cloud-off"
    icon: iconText

    property real baseSize: Style.baseWidgetSize
    implicitWidth: Math.round(baseSize * Style.uiScaleRatio)
    implicitHeight: Math.round(baseSize * Style.uiScaleRatio)

    tooltipText: {
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
                Logger.e("WeatherIndicator", `tooltipOption option: ${root.tooltipOption} not recongnized.`);
        }
        return allRows
            }
    onClicked: {
        if (pluginApi) {
        pluginApi.togglePanel(screen, this);
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

        const timeFormat = Settings.data.location.use12hourFormat ? "hh:mm AP" : "HH:mm";
        const rise = I18n.locale.toString(riseDate, timeFormat);
        const set = I18n.locale.toString(setDate, timeFormat);

        rows.push([("Sunrise"), rise]);
        rows.push([("Sunset"), set]);
        return rows;
    }

    function buildWeatherTooltip() {
        let allRows = [];
        switch (root.tooltipOption) {
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
        TooltipService.show(root, allRows, BarService.getTooltipDirection(root.screen?.name))
        }
    }
}
